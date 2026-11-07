-- ============================================================================
-- RedCellNet Complete Production Hardening, RBAC, Storage, Audit & Atomic RPCs
-- ============================================================================

-- 1. Private Helper Schema (not exposed via PostgREST)
CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO anon, authenticated, service_role;

-- 2. Extend Tables Safely (Idempotent)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS verification_doc_url text,
  ADD COLUMN IF NOT EXISTS extracted_blood_type text,
  ADD COLUMN IF NOT EXISTS is_phone_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS phone_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS availability_status text NOT NULL DEFAULT 'unavailable',
  ADD COLUMN IF NOT EXISTS available_from timestamptz,
  ADD COLUMN IF NOT EXISTS available_until timestamptz,
  ADD COLUMN IF NOT EXISTS notifications_paused_until timestamptz,
  ADD COLUMN IF NOT EXISTS notification_preferences jsonb NOT NULL DEFAULT '{"emergency_alerts": true, "offer_updates": true, "eligibility_reminders": true, "system_broadcasts": true, "verification_updates": true}'::jsonb,
  ADD COLUMN IF NOT EXISTS privacy_settings jsonb NOT NULL DEFAULT '{"coarse_location_only": true, "show_phone_after_acceptance_only": true, "public_donor_badge": true}'::jsonb,
  ADD COLUMN IF NOT EXISTS bookmarked_request_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS bookmarked_content_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS cooldown_days integer NOT NULL DEFAULT 90;

ALTER TABLE public.donation_centers
  ADD COLUMN IF NOT EXISTS facility_type text NOT NULL DEFAULT 'Blood Bank',
  ADD COLUMN IF NOT EXISTS operational_status text NOT NULL DEFAULT 'Active',
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now());

ALTER TABLE public.educational_content
  ADD COLUMN IF NOT EXISTS source_attribution text DEFAULT 'WHO & National Safe Blood Transfusion Programme Guidelines',
  ADD COLUMN IF NOT EXISTS medical_disclaimer text DEFAULT 'Educational guidance only. Final donor eligibility and transfusion compatibility are always determined by qualified medical staff at the hospital or blood bank.',
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now());

ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolution_notes text;

ALTER TABLE public.blood_requests
  ADD COLUMN IF NOT EXISTS patient_identifier text DEFAULT '',
  ADD COLUMN IF NOT EXISTS notified_donor_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fulfilled_at timestamptz;

CREATE TABLE IF NOT EXISTS public.admin_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_email text,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;

-- Normalize existing data consistency
UPDATE public.profiles
SET verification_status = 'verified',
    verified_at = COALESCE(verified_at, timezone('utc'::text, now()))
WHERE is_verified_donor = true
  AND (verification_status IS NULL OR verification_status = 'unverified');

UPDATE public.profiles
SET availability_status = CASE WHEN COALESCE(is_available_to_donate, false) THEN 'available' ELSE 'unavailable' END
WHERE availability_status IS NULL OR (availability_status = 'unavailable' AND COALESCE(is_available_to_donate, false) = true);

UPDATE public.profiles
SET name = 'RedCellNet Admin'
WHERE role = 'admin' AND (name IS NULL OR btrim(name) = '');

UPDATE public.donation_centers
SET facility_type = CASE
  WHEN name ILIKE '%Red Crescent%' OR name ILIKE '%Society%' THEN 'Donation Center'
  WHEN name ILIKE '%Blood Bank%' THEN 'Blood Bank'
  WHEN name ILIKE '%Hospital%' OR name ILIKE '%Medical College%' THEN 'Hospital'
  ELSE 'Blood Bank'
END
WHERE facility_type = 'Blood Bank';

UPDATE public.reports
SET status = 'dismissed'
WHERE status = 'dismiss';

-- 3. Covering Foreign Key & Query Performance Indexes
CREATE INDEX IF NOT EXISTS idx_blood_requests_requester_user_id ON public.blood_requests(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_blood_requests_status_created_at ON public.blood_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_blood_requests_blood_type_status ON public.blood_requests(required_blood_type, status);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status_created_at ON public.reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_resolved_by ON public.reports(resolved_by);
CREATE INDEX IF NOT EXISTS idx_system_broadcasts_created_by ON public.system_broadcasts(created_by);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON public.admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON public.admin_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_availability_blood ON public.profiles(is_available_to_donate, blood_type);

-- 4. Private Helper Functions (Security Definer in non-exposed private schema)
CREATE OR REPLACE FUNCTION private.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role IN ('admin', 'moderator')
      AND COALESCE(is_banned, false) = false
  );
$$;

CREATE OR REPLACE FUNCTION private.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'admin'
      AND COALESCE(is_banned, false) = false
  );
$$;

CREATE OR REPLACE FUNCTION private.is_blood_compatible(
  p_donor_blood text,
  p_recipient_blood text,
  p_component_type text DEFAULT 'Whole Blood'
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_donor text := UPPER(BTRIM(COALESCE(p_donor_blood, '')));
  v_recip text := UPPER(BTRIM(COALESCE(p_recipient_blood, '')));
  v_comp  text := LOWER(BTRIM(COALESCE(p_component_type, 'whole blood')));
  v_donor_abo text;
  v_recip_abo text;
  v_donor_rh  text;
  v_recip_rh  text;
BEGIN
  IF v_donor NOT IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
     OR v_recip NOT IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-') THEN
    RETURN false;
  END IF;

  v_donor_abo := LEFT(v_donor, LENGTH(v_donor) - 1);
  v_recip_abo := LEFT(v_recip, LENGTH(v_recip) - 1);
  v_donor_rh  := RIGHT(v_donor, 1);
  v_recip_rh  := RIGHT(v_recip, 1);

  -- Plasma compatibility (inverted ABO; AB is universal plasma donor)
  IF v_comp LIKE '%plasma%' THEN
    RETURN CASE v_recip_abo
      WHEN 'O'  THEN v_donor_abo IN ('O', 'A', 'B', 'AB')
      WHEN 'A'  THEN v_donor_abo IN ('A', 'AB')
      WHEN 'B'  THEN v_donor_abo IN ('B', 'AB')
      WHEN 'AB' THEN v_donor_abo = 'AB'
      ELSE false
    END;
  END IF;

  -- Platelets compatibility (Rh- recipient requires Rh- donor; ABO identical or RBC/plasma compatible)
  IF v_comp LIKE '%platelet%' THEN
    IF v_recip_rh = '-' AND v_donor_rh <> '-' THEN
      RETURN false;
    END IF;
    RETURN v_donor_abo = v_recip_abo OR v_donor_abo = 'O' OR v_donor_abo = 'AB';
  END IF;

  -- Default: Whole Blood & Packed Red Cells compatibility
  RETURN CASE v_recip
    WHEN 'O-'  THEN v_donor IN ('O-')
    WHEN 'O+'  THEN v_donor IN ('O-', 'O+')
    WHEN 'A-'  THEN v_donor IN ('O-', 'A-')
    WHEN 'A+'  THEN v_donor IN ('O-', 'O+', 'A-', 'A+')
    WHEN 'B-'  THEN v_donor IN ('O-', 'B-')
    WHEN 'B+'  THEN v_donor IN ('O-', 'O+', 'B-', 'B+')
    WHEN 'AB-' THEN v_donor IN ('O-', 'A-', 'B-', 'AB-')
    WHEN 'AB+' THEN v_donor IN ('O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+')
    ELSE false
  END;
END;
$$;

CREATE OR REPLACE FUNCTION private.haversine_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN NULL
    ELSE 6371.0 * 2.0 * asin(
      sqrt(
         least(1.0, greatest(0.0,
          power(sin(radians(lat2 - lat1) / 2.0), 2) +
          cos(radians(lat1)) * cos(radians(lat2)) *
          power(sin(radians(lon2 - lon1) / 2.0), 2)
        ))
      )
    )
  END;
$$;

CREATE OR REPLACE FUNCTION private.log_admin_action(
  p_action text,
  p_target_type text,
  p_target_id text DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_email text;
BEGIN
  SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;
  INSERT INTO public.admin_logs (admin_id, admin_email, action, target_type, target_id, details, created_at)
  VALUES (v_uid, v_email, p_action, p_target_type, p_target_id, COALESCE(p_details, '{}'::jsonb), timezone('utc'::text, now()));
END;
$$;

REVOKE ALL ON FUNCTION private.is_staff() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_staff() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.is_super_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_super_admin() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.is_blood_compatible(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_blood_compatible(text, text, text) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.haversine_km(double precision, double precision, double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.haversine_km(double precision, double precision, double precision, double precision) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.log_admin_action(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.log_admin_action(text, text, text, jsonb) TO service_role;

-- 5. Convert public.is_admin to SECURITY INVOKER so it is safe & clean
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = user_id
      AND role IN ('admin', 'moderator')
      AND COALESCE(is_banned, false) = false
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated, service_role;

-- Client-callable audit helper for admin CRUD operations (SECURITY INVOKER)
CREATE OR REPLACE FUNCTION public.record_admin_log(
  p_action text,
  p_target_type text,
  p_target_id text DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_email text;
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;
  SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;
  INSERT INTO public.admin_logs (admin_id, admin_email, action, target_type, target_id, details, created_at)
  VALUES (v_uid, v_email, p_action, p_target_type, p_target_id, COALESCE(p_details, '{}'::jsonb), timezone('utc'::text, now()));
END;
$$;

REVOKE ALL ON FUNCTION public.record_admin_log(text, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_admin_log(text, text, text, jsonb) TO authenticated, service_role;

-- 6. Fix Trigger Functions & Add Auth Signup + Profile Privilege Guard Triggers
CREATE OR REPLACE FUNCTION public.sync_center_contact()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.contact_info IS NOT NULL AND NEW.contact_number IS NULL THEN
    NEW.contact_number := NEW.contact_info;
  ELSIF NEW.contact_number IS NOT NULL AND NEW.contact_info IS NULL THEN
    NEW.contact_info := NEW.contact_number;
  END IF;
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_content_points()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.points_value IS NOT NULL AND NEW.points IS NULL THEN
    NEW.points := NEW.points_value;
  ELSIF NEW.points IS NOT NULL AND NEW.points_value IS NULL THEN
    NEW.points_value := NEW.points;
  END IF;
  NEW.updated_at := timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    name,
    phone_number,
    blood_type,
    location_city,
    role,
    verification_status,
    is_verified_donor,
    is_available_to_donate,
    availability_status,
    points,
    badges,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', split_part(COALESCE(NEW.email, ''), '@', 1)),
    NEW.raw_user_meta_data->>'phone_number',
    NEW.raw_user_meta_data->>'blood_type',
    NEW.raw_user_meta_data->>'location_city',
    'user',
    'unverified',
    false,
    false,
    'unavailable',
    0,
    '[]'::jsonb,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  ON CONFLICT (id) DO UPDATE
    SET email = COALESCE(EXCLUDED.email, public.profiles.email),
        name = CASE
          WHEN public.profiles.name IS NULL OR btrim(public.profiles.name) = '' THEN EXCLUDED.name
          ELSE public.profiles.name
        END;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Protect privileged columns on public.profiles from self-escalation
CREATE OR REPLACE FUNCTION public.protect_profile_privileged_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Allow superuser / service_role / SECURITY DEFINER RPCs (where current_user = postgres) or verified staff
  IF current_user IN ('postgres', 'supabase_admin', 'service_role') OR (SELECT private.is_staff()) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.role := 'user';
    NEW.is_verified_donor := false;
    NEW.verified_at := NULL;
    NEW.is_banned := false;
    NEW.ban_reason := NULL;
    IF NEW.verification_status = 'verified' THEN
      NEW.verification_status := 'unverified';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.role := OLD.role;
    NEW.is_banned := OLD.is_banned;
    NEW.ban_reason := OLD.ban_reason;
    NEW.staff_notes := OLD.staff_notes;
    -- If user changes their verified blood group, automatically reset verification to unverified
    IF COALESCE(OLD.is_verified_donor, false) = true AND NEW.blood_type IS DISTINCT FROM OLD.blood_type THEN
      NEW.is_verified_donor := false;
      NEW.verified_at := NULL;
      IF NEW.verification_status = 'verified' THEN
        NEW.verification_status := 'unverified';
      END IF;
    ELSE
      NEW.is_verified_donor := OLD.is_verified_donor;
      NEW.verified_at := OLD.verified_at;
      IF NEW.verification_status = 'verified' AND COALESCE(OLD.verification_status, 'unverified') <> 'verified' THEN
        RAISE EXCEPTION 'Unauthorized: donor verification status can only be approved by moderation staff';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.protect_profile_privileged_fields() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_protect_profile_privileged_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_privileged_fields
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_privileged_fields();

-- 7. Clean, Performant, Non-Duplicate Row Level Security Policies
-- 7a. profiles
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_or_staff" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_own_or_staff" ON public.profiles;

CREATE POLICY "profiles_select_authenticated" ON public.profiles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id OR (SELECT private.is_staff()));

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "profiles_update_own_or_staff" ON public.profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id OR (SELECT private.is_staff()))
  WITH CHECK ((SELECT auth.uid()) = id OR (SELECT private.is_staff()));

CREATE POLICY "profiles_delete_own_or_staff" ON public.profiles
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = id OR (SELECT private.is_staff()));

-- 7b. blood_requests
DROP POLICY IF EXISTS "Admins or owners can delete requests" ON public.blood_requests;
DROP POLICY IF EXISTS "Blood requests are viewable by everyone" ON public.blood_requests;
DROP POLICY IF EXISTS "Users can insert blood requests" ON public.blood_requests;
DROP POLICY IF EXISTS "Users can update blood requests" ON public.blood_requests;
DROP POLICY IF EXISTS "blood_requests_select_all" ON public.blood_requests;
DROP POLICY IF EXISTS "blood_requests_insert_own_or_staff" ON public.blood_requests;
DROP POLICY IF EXISTS "blood_requests_update_owner_or_staff" ON public.blood_requests;
DROP POLICY IF EXISTS "blood_requests_delete_owner_or_staff" ON public.blood_requests;

CREATE POLICY "blood_requests_select_all" ON public.blood_requests
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "blood_requests_insert_own_or_staff" ON public.blood_requests
  FOR INSERT TO authenticated
  WITH CHECK (requester_user_id = (SELECT auth.uid()) OR (SELECT private.is_staff()));

CREATE POLICY "blood_requests_update_owner_or_staff" ON public.blood_requests
  FOR UPDATE TO authenticated
  USING (requester_user_id = (SELECT auth.uid()) OR (SELECT private.is_staff()))
  WITH CHECK (requester_user_id = (SELECT auth.uid()) OR (SELECT private.is_staff()));

CREATE POLICY "blood_requests_delete_owner_or_staff" ON public.blood_requests
  FOR DELETE TO authenticated
  USING (requester_user_id = (SELECT auth.uid()) OR (SELECT private.is_staff()));

-- 7c. donation_centers (no overlapping FOR ALL + FOR SELECT)
DROP POLICY IF EXISTS "Authenticated users can manage donation centers" ON public.donation_centers;
DROP POLICY IF EXISTS "Donation centers are viewable by everyone" ON public.donation_centers;
DROP POLICY IF EXISTS "donation_centers_select_all" ON public.donation_centers;
DROP POLICY IF EXISTS "donation_centers_insert_staff" ON public.donation_centers;
DROP POLICY IF EXISTS "donation_centers_update_staff" ON public.donation_centers;
DROP POLICY IF EXISTS "donation_centers_delete_staff" ON public.donation_centers;

CREATE POLICY "donation_centers_select_all" ON public.donation_centers
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "donation_centers_insert_staff" ON public.donation_centers
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "donation_centers_update_staff" ON public.donation_centers
  FOR UPDATE TO authenticated
  USING ((SELECT private.is_staff()))
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "donation_centers_delete_staff" ON public.donation_centers
  FOR DELETE TO authenticated
  USING ((SELECT private.is_staff()));

-- 7d. educational_content
DROP POLICY IF EXISTS "Authenticated users can manage educational content" ON public.educational_content;
DROP POLICY IF EXISTS "Educational content is viewable by everyone" ON public.educational_content;
DROP POLICY IF EXISTS "educational_content_select_all" ON public.educational_content;
DROP POLICY IF EXISTS "educational_content_insert_staff" ON public.educational_content;
DROP POLICY IF EXISTS "educational_content_update_staff" ON public.educational_content;
DROP POLICY IF EXISTS "educational_content_delete_staff" ON public.educational_content;

CREATE POLICY "educational_content_select_all" ON public.educational_content
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "educational_content_insert_staff" ON public.educational_content
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "educational_content_update_staff" ON public.educational_content
  FOR UPDATE TO authenticated
  USING ((SELECT private.is_staff()))
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "educational_content_delete_staff" ON public.educational_content
  FOR DELETE TO authenticated
  USING ((SELECT private.is_staff()));

-- 7e. notifications
DROP POLICY IF EXISTS "Notifications can be inserted for users" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_own_or_staff" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete_own_or_staff" ON public.notifications;

CREATE POLICY "notifications_select_own" ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "notifications_insert_own_or_staff" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()) OR (SELECT private.is_staff()));

CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "notifications_delete_own_or_staff" ON public.notifications
  FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT private.is_staff()));

-- 7f. reports
DROP POLICY IF EXISTS "Admins can delete reports" ON public.reports;
DROP POLICY IF EXISTS "Reports insertable by authenticated users" ON public.reports;
DROP POLICY IF EXISTS "Reports updateable by authenticated users" ON public.reports;
DROP POLICY IF EXISTS "Reports viewable by authenticated users" ON public.reports;
DROP POLICY IF EXISTS "reports_select_reporter_or_staff" ON public.reports;
DROP POLICY IF EXISTS "reports_insert_authenticated" ON public.reports;
DROP POLICY IF EXISTS "reports_update_staff" ON public.reports;
DROP POLICY IF EXISTS "reports_delete_staff" ON public.reports;

CREATE POLICY "reports_select_reporter_or_staff" ON public.reports
  FOR SELECT TO authenticated
  USING (reporter_user_id = (SELECT auth.uid())::text OR (SELECT private.is_staff()));

CREATE POLICY "reports_insert_authenticated" ON public.reports
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND (reporter_user_id = (SELECT auth.uid())::text OR reporter_user_id = 'anonymous'));

CREATE POLICY "reports_update_staff" ON public.reports
  FOR UPDATE TO authenticated
  USING ((SELECT private.is_staff()))
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "reports_delete_staff" ON public.reports
  FOR DELETE TO authenticated
  USING ((SELECT private.is_staff()));

-- 7g. system_broadcasts
DROP POLICY IF EXISTS "Allow authenticated insert broadcasts" ON public.system_broadcasts;
DROP POLICY IF EXISTS "Allow public read active broadcasts" ON public.system_broadcasts;
DROP POLICY IF EXISTS "system_broadcasts_select_all" ON public.system_broadcasts;
DROP POLICY IF EXISTS "system_broadcasts_insert_staff" ON public.system_broadcasts;
DROP POLICY IF EXISTS "system_broadcasts_update_staff" ON public.system_broadcasts;
DROP POLICY IF EXISTS "system_broadcasts_delete_staff" ON public.system_broadcasts;

CREATE POLICY "system_broadcasts_select_all" ON public.system_broadcasts
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "system_broadcasts_insert_staff" ON public.system_broadcasts
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "system_broadcasts_update_staff" ON public.system_broadcasts
  FOR UPDATE TO authenticated
  USING ((SELECT private.is_staff()))
  WITH CHECK ((SELECT private.is_staff()));

CREATE POLICY "system_broadcasts_delete_staff" ON public.system_broadcasts
  FOR DELETE TO authenticated
  USING ((SELECT private.is_staff()));

-- 7h. admin_logs
DROP POLICY IF EXISTS "admin_logs_select_staff" ON public.admin_logs;
DROP POLICY IF EXISTS "admin_logs_insert_staff" ON public.admin_logs;

CREATE POLICY "admin_logs_select_staff" ON public.admin_logs
  FOR SELECT TO authenticated
  USING ((SELECT private.is_staff()));

CREATE POLICY "admin_logs_insert_staff" ON public.admin_logs
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT private.is_staff()));

-- 8. Storage Buckets & RLS Policies
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('verification-docs', 'verification-docs', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "storage_avatars_select" ON storage.objects;
DROP POLICY IF EXISTS "storage_verification_docs_select" ON storage.objects;
DROP POLICY IF EXISTS "storage_user_uploads_insert" ON storage.objects;
DROP POLICY IF EXISTS "storage_user_uploads_update" ON storage.objects;
DROP POLICY IF EXISTS "storage_user_uploads_delete" ON storage.objects;

CREATE POLICY "storage_avatars_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'avatars');

CREATE POLICY "storage_verification_docs_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'verification-docs'
    AND ((storage.foldername(name))[1] = (SELECT auth.uid())::text OR (SELECT private.is_staff()))
  );

CREATE POLICY "storage_user_uploads_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id IN ('avatars', 'verification-docs')
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

CREATE POLICY "storage_user_uploads_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id IN ('avatars', 'verification-docs')
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  )
  WITH CHECK (
    bucket_id IN ('avatars', 'verification-docs')
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

CREATE POLICY "storage_user_uploads_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id IN ('avatars', 'verification-docs')
    AND ((storage.foldername(name))[1] = (SELECT auth.uid())::text OR (SELECT private.is_staff()))
  );

-- 9. Hardened Administrative RPCs with Audit Logging
CREATE OR REPLACE FUNCTION public.verify_donor(
  target_user_id uuid,
  should_approve boolean,
  admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  IF should_approve THEN
    UPDATE public.profiles
    SET verification_status = 'verified',
        is_verified_donor = true,
        verified_at = timezone('utc'::text, now()),
        rejection_reason = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_user_id;

    INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
    VALUES (
      target_user_id,
      'Donor Verification Approved',
      'Your blood group evidence has been verified by RedCellNet moderation staff.',
      'verification',
      '/profile',
      target_user_id::text,
      false,
      timezone('utc'::text, now())
    );

    PERFORM private.log_admin_action(
      'verify_donor',
      'profile',
      target_user_id::text,
      jsonb_build_object('approved', true, 'notes', admin_notes)
    );
  ELSE
    UPDATE public.profiles
    SET verification_status = 'rejected',
        is_verified_donor = false,
        rejection_reason = COALESCE(NULLIF(btrim(admin_notes), ''), 'Submitted document could not be verified. Please upload a clear lab report.'),
        updated_at = timezone('utc'::text, now())
    WHERE id = target_user_id;

    INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
    VALUES (
      target_user_id,
      'Verification Requires Resubmission',
      'Your verification submission could not be approved: ' || COALESCE(NULLIF(btrim(admin_notes), ''), 'Please upload a clearer laboratory blood group report.'),
      'verification',
      '/profile',
      target_user_id::text,
      false,
      timezone('utc'::text, now())
    );

    PERFORM private.log_admin_action(
      'reject_donor',
      'profile',
      target_user_id::text,
      jsonb_build_object('approved', false, 'reason', admin_notes)
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'status', CASE WHEN should_approve THEN 'verified' ELSE 'rejected' END);
END;
$$;

CREATE OR REPLACE FUNCTION public.manage_user_role(
  target_user_id uuid,
  new_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := LOWER(BTRIM(COALESCE(new_role, '')));
BEGIN
  IF NOT (SELECT private.is_super_admin()) THEN
    RAISE EXCEPTION 'Unauthorized: administrator privileges required to change roles';
  END IF;

  IF v_role NOT IN ('user', 'moderator', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %. Must be user, moderator, or admin.', new_role;
  END IF;

  UPDATE public.profiles
  SET role = v_role,
      updated_at = timezone('utc'::text, now())
  WHERE id = target_user_id;

  INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
  VALUES (
    target_user_id,
    CASE
      WHEN v_role = 'moderator' THEN 'Granted Moderator Role'
      WHEN v_role = 'admin' THEN 'Granted Administrator Role'
      ELSE 'Account Role Updated'
    END,
    CASE
      WHEN v_role = 'moderator' THEN 'You have been granted Community Moderator privileges on RedCellNet.'
      WHEN v_role = 'admin' THEN 'You have been granted System Administrator privileges on RedCellNet.'
      ELSE 'Your account role has been updated to standard member.'
    END,
    'role_update',
    '/profile',
    target_user_id::text,
    false,
    timezone('utc'::text, now())
  );

  PERFORM private.log_admin_action(
    'change_role',
    'profile',
    target_user_id::text,
    jsonb_build_object('new_role', v_role)
  );

  RETURN jsonb_build_object('success', true, 'user_id', target_user_id, 'role', v_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.set_user_ban_status(
  target_user_id uuid,
  should_ban boolean,
  reason text DEFAULT 'Violation of community safety guidelines'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  IF target_user_id = (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'Cannot suspend your own account';
  END IF;

  IF (SELECT COALESCE(role, 'user') FROM public.profiles WHERE id = target_user_id) = 'admin'
     AND NOT (SELECT private.is_super_admin()) THEN
    RAISE EXCEPTION 'Unauthorized: only a system administrator can modify an administrator account';
  END IF;

  UPDATE public.profiles
  SET is_banned = should_ban,
      ban_reason = CASE WHEN should_ban THEN reason ELSE NULL END,
      is_available_to_donate = CASE WHEN should_ban THEN false ELSE is_available_to_donate END,
      availability_status = CASE WHEN should_ban THEN 'unavailable' ELSE availability_status END,
      updated_at = timezone('utc'::text, now())
  WHERE id = target_user_id;

  INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
  VALUES (
    target_user_id,
    CASE WHEN should_ban THEN 'Account Suspended' ELSE 'Account Restored' END,
    CASE WHEN should_ban THEN 'Your account has been suspended: ' || COALESCE(reason, 'Policy violation') ELSE 'Your account access has been restored.' END,
    'account_status',
    '/profile',
    target_user_id::text,
    false,
    timezone('utc'::text, now())
  );

  PERFORM private.log_admin_action(
    CASE WHEN should_ban THEN 'suspend_user' ELSE 'restore_user' END,
    'profile',
    target_user_id::text,
    jsonb_build_object('is_banned', should_ban, 'reason', reason)
  );

  RETURN jsonb_build_object('success', true, 'is_banned', should_ban);
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_hospital_case(
  request_id uuid,
  is_verified boolean,
  staff_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_notes jsonb;
  v_timeline jsonb;
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  SELECT COALESCE(staff_notes, '[]'::jsonb), COALESCE(timeline, '[]'::jsonb)
  INTO v_notes, v_timeline
  FROM public.blood_requests
  WHERE id = request_id
  FOR UPDATE;

  IF btrim(COALESCE(staff_note, '')) <> '' THEN
    v_notes := v_notes || jsonb_build_array(jsonb_build_object(
      'author_id', (SELECT auth.uid()),
      'note', staff_note,
      'timestamp', timezone('utc'::text, now())
    ));
  END IF;

  v_timeline := v_timeline || jsonb_build_array(jsonb_build_object(
    'action', CASE WHEN is_verified THEN 'hospital_case_verified' ELSE 'hospital_case_unverified' END,
    'note', NULLIF(btrim(COALESCE(staff_note, '')), ''),
    'time', timezone('utc'::text, now())
  ));

  UPDATE public.blood_requests
  SET is_verified_hospital_case = is_verified,
      staff_notes = v_notes,
      timeline = v_timeline,
      updated_at = timezone('utc'::text, now())
  WHERE id = request_id;

  PERFORM private.log_admin_action(
    'verify_hospital_case',
    'request',
    request_id::text,
    jsonb_build_object('is_verified', is_verified, 'staff_note', staff_note)
  );

  RETURN jsonb_build_object('success', true, 'request_id', request_id, 'is_verified', is_verified);
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_moderation_report(
  p_report_id uuid,
  p_action text,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_report public.reports%ROWTYPE;
  v_status text;
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  v_status := CASE
    WHEN LOWER(BTRIM(p_action)) IN ('dismiss', 'dismissed') THEN 'dismissed'
    WHEN LOWER(BTRIM(p_action)) = 'action_taken' THEN 'action_taken'
    ELSE NULL
  END;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Invalid report action: %', p_action;
  END IF;

  SELECT * INTO v_report FROM public.reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  IF v_status = 'action_taken' THEN
    IF v_report.reported_type = 'request' AND v_report.target_id ~* '^[0-9a-f-]{36}$' THEN
      UPDATE public.blood_requests
      SET status = 'Cancelled',
          cancellation_reason = COALESCE(NULLIF(btrim(p_notes), ''), 'Closed following moderation review'),
          timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
            'action', 'request_cancelled_moderation',
            'note', COALESCE(NULLIF(btrim(p_notes), ''), v_report.reason),
            'time', timezone('utc'::text, now())
          )),
          updated_at = timezone('utc'::text, now())
      WHERE id = v_report.target_id::uuid;
    ELSIF v_report.reported_type = 'profile' AND v_report.target_id ~* '^[0-9a-f-]{36}$' THEN
      UPDATE public.profiles
      SET is_banned = true,
          ban_reason = COALESCE(NULLIF(btrim(p_notes), ''), 'Suspended following moderation report: ' || v_report.reason),
          is_available_to_donate = false,
          availability_status = 'unavailable',
          updated_at = timezone('utc'::text, now())
      WHERE id = v_report.target_id::uuid
        AND COALESCE(role, 'user') <> 'admin';
    END IF;
  END IF;

  UPDATE public.reports
  SET status = v_status,
      resolved_by = (SELECT auth.uid()),
      resolved_at = timezone('utc'::text, now()),
      resolution_notes = p_notes
  WHERE id = p_report_id;

  PERFORM private.log_admin_action(
    'resolve_report',
    'report',
    p_report_id::text,
    jsonb_build_object('status', v_status, 'reported_type', v_report.reported_type, 'target_id', v_report.target_id, 'notes', p_notes)
  );

  RETURN jsonb_build_object('success', true, 'status', v_status);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_emergency_broadcast(
  broadcast_title text,
  broadcast_message text,
  b_type text DEFAULT 'shortage',
  target_blood text DEFAULT NULL,
  target_city text DEFAULT NULL,
  broadcast_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_broadcast_id uuid;
  v_rec RECORD;
  v_sent_count integer := 0;
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  INSERT INTO public.system_broadcasts (
    title,
    message,
    broadcast_type,
    target_blood_type,
    target_city,
    created_by,
    created_at,
    is_active,
    expires_at
  ) VALUES (
    broadcast_title,
    broadcast_message,
    COALESCE(b_type, 'shortage'),
    NULLIF(BTRIM(COALESCE(target_blood, '')), ''),
    NULLIF(BTRIM(COALESCE(target_city, '')), ''),
    (SELECT auth.uid()),
    timezone('utc'::text, now()),
    true,
    broadcast_expires_at
  ) RETURNING id INTO v_broadcast_id;

  FOR v_rec IN
    SELECT id FROM public.profiles
    WHERE (target_blood IS NULL OR BTRIM(target_blood) = '' OR UPPER(BTRIM(target_blood)) = 'ALL' OR blood_type = target_blood)
      AND (target_city IS NULL OR BTRIM(target_city) = '' OR location_city ILIKE '%' || BTRIM(target_city) || '%')
      AND COALESCE(is_banned, false) = false
      AND (notifications_paused_until IS NULL OR notifications_paused_until <= timezone('utc'::text, now()))
      AND COALESCE((notification_preferences->>'system_broadcasts')::boolean, true) = true
  LOOP
    INSERT INTO public.notifications (
      user_id, title, body, type, screen, resource_id, is_read, created_at
    ) VALUES (
      v_rec.id,
      broadcast_title,
      broadcast_message,
      'emergency_broadcast',
      '/home',
      v_broadcast_id::text,
      false,
      timezone('utc'::text, now())
    );
    v_sent_count := v_sent_count + 1;
  END LOOP;

  PERFORM private.log_admin_action(
    'send_broadcast',
    'broadcast',
    v_broadcast_id::text,
    jsonb_build_object('title', broadcast_title, 'type', b_type, 'target_blood', target_blood, 'target_city', target_city, 'notified_count', v_sent_count)
  );

  RETURN jsonb_build_object('success', true, 'broadcast_id', v_broadcast_id, 'notified_count', v_sent_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_emergency_broadcast(
  broadcast_title text,
  broadcast_message text,
  b_type text DEFAULT 'shortage',
  target_blood text DEFAULT NULL,
  target_city text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN public.create_emergency_broadcast(broadcast_title, broadcast_message, b_type, target_blood, target_city, NULL::timestamptz);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_direct_admin_notification(
  p_target_user_id uuid,
  p_title text,
  p_message text,
  p_type text DEFAULT 'general'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  INSERT INTO public.notifications (
    user_id, title, body, type, screen, resource_id, is_read, created_at
  ) VALUES (
    p_target_user_id,
    p_title,
    p_message,
    COALESCE(NULLIF(BTRIM(p_type), ''), 'system'),
    '/notifications',
    p_target_user_id::text,
    false,
    timezone('utc'::text, now())
  );

  PERFORM private.log_admin_action(
    'send_direct_notification',
    'profile',
    p_target_user_id::text,
    jsonb_build_object('title', p_title, 'type', p_type)
  );

  RETURN jsonb_build_object('success', true, 'notified_count', 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_system_broadcast(
  p_id uuid,
  p_title text,
  p_message text,
  p_broadcast_type text DEFAULT 'shortage',
  p_target_blood_type text DEFAULT NULL,
  p_target_city text DEFAULT NULL,
  p_is_active boolean DEFAULT true,
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  UPDATE public.system_broadcasts
  SET title = p_title,
      message = p_message,
      broadcast_type = p_broadcast_type,
      target_blood_type = p_target_blood_type,
      target_city = p_target_city,
      is_active = p_is_active,
      expires_at = p_expires_at,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_id;

  PERFORM private.log_admin_action(
    'update_broadcast',
    'broadcast',
    p_id::text,
    jsonb_build_object('title', p_title, 'is_active', p_is_active)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.check_and_expire_requests()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.blood_requests
  SET status = 'Expired',
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'request_expired',
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE status IN ('Open', 'Partially Fulfilled')
    AND expiry_at IS NOT NULL
    AND expiry_at < timezone('utc'::text, now());

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 10. Atomic Multi-Donor Request & Fulfillment RPCs (Row-Level Locking)
CREATE OR REPLACE FUNCTION public.submit_blood_offer(
  p_request_id uuid,
  p_offered_units integer DEFAULT 1,
  p_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_donor public.profiles%ROWTYPE;
  v_offer_id text;
  v_units integer;
  v_existing jsonb;
  v_new_offer jsonb;
  v_badges jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_donor FROM public.profiles WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Please complete your donor profile before responding to requests.';
  END IF;

  IF COALESCE(v_donor.is_banned, false) THEN
    RAISE EXCEPTION 'Your account is currently suspended.';
  END IF;

  IF v_donor.blood_type IS NULL OR BTRIM(v_donor.blood_type) = '' THEN
    RAISE EXCEPTION 'Please set your blood group in your profile before offering to donate.';
  END IF;

  IF v_donor.next_eligible_date IS NOT NULL AND v_donor.next_eligible_date > timezone('utc'::text, now()) THEN
    RAISE EXCEPTION 'Safety cooldown active: you will be eligible to donate again on %.', to_char(v_donor.next_eligible_date, 'Mon DD, YYYY');
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id = v_uid THEN
    RAISE EXCEPTION 'You cannot submit a donor offer on your own request.';
  END IF;

  IF v_req.expiry_at IS NOT NULL AND v_req.expiry_at < timezone('utc'::text, now()) AND v_req.status IN ('Open', 'Partially Fulfilled') THEN
    UPDATE public.blood_requests
    SET status = 'Expired', updated_at = timezone('utc'::text, now())
    WHERE id = p_request_id;
    RAISE EXCEPTION 'This blood request has expired.';
  END IF;

  IF v_req.status NOT IN ('Open', 'Partially Fulfilled') OR COALESCE(v_req.remaining_units, 0) <= 0 THEN
    RAISE EXCEPTION 'This request is no longer accepting donor offers (current status: %).', v_req.status;
  END IF;

  IF NOT private.is_blood_compatible(v_donor.blood_type, v_req.required_blood_type, COALESCE(v_req.component_type, 'Whole Blood')) THEN
    RAISE EXCEPTION 'Incompatible blood group for %: % donor cannot donate to a % recipient.', COALESCE(v_req.component_type, 'Whole Blood'), v_donor.blood_type, v_req.required_blood_type;
  END IF;

  -- Check duplicate active offer
  SELECT elem INTO v_existing
  FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb)) elem
  WHERE elem->>'donorId' = v_uid::text
    AND COALESCE(elem->>'status', 'pending') IN ('pending', 'accepted')
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'You already have an active offer on this blood request.';
  END IF;

  v_units := GREATEST(1, LEAST(COALESCE(p_offered_units, 1), v_req.remaining_units));
  v_offer_id := 'offer_' || replace(gen_random_uuid()::text, '-', '');

  v_new_offer := jsonb_build_object(
    'id', v_offer_id,
    'donorId', v_uid::text,
    'donorName', COALESCE(NULLIF(BTRIM(v_donor.name), ''), split_part(COALESCE(v_donor.email, 'Donor'), '@', 1)),
    'donorBloodType', v_donor.blood_type,
    'donorPhone', COALESCE(v_donor.phone_number, ''),
    'donorIsVerified', COALESCE(v_donor.is_verified_donor, false),
    'offeredUnits', v_units,
    'note', COALESCE(p_note, ''),
    'status', 'pending',
    'offerTimestamp', timezone('utc'::text, now())
  );

  UPDATE public.blood_requests
  SET offers = COALESCE(offers, '[]'::jsonb) || jsonb_build_array(v_new_offer),
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'offer_submitted',
        'by', v_new_offer->>'donorName',
        'donorId', v_uid::text,
        'units', v_units,
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  -- Award Standby Guardian badge & +5 responsiveness points if not already awarded for Standby Guardian
  v_badges := COALESCE(v_donor.badges, '[]'::jsonb);
  IF NOT (v_badges @> '["Standby Guardian"]'::jsonb) THEN
    v_badges := v_badges || '["Standby Guardian"]'::jsonb;
    UPDATE public.profiles
    SET badges = v_badges,
        points = COALESCE(points, 0) + 10,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_uid;
  END IF;

  -- Notify requester
  INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
  VALUES (
    v_req.requester_user_id,
    'New Donor Offer (' || v_donor.blood_type || ')',
    (v_new_offer->>'donorName') || ' offered ' || v_units || ' unit(s) for ' || v_req.hospital_name || '.',
    'donor_offer',
    '/request-details',
    p_request_id::text,
    false,
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object('success', true, 'offer', v_new_offer);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_blood_offer(
  p_request_id uuid,
  p_offer_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_offer jsonb;
  v_updated_offers jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_found boolean := false;
  v_offered_units integer;
  v_new_accepted integer;
  v_new_remaining integer;
  v_new_status text;
  v_donor_id text;
  v_accepted_ids jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id <> v_uid AND NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: only the requester or staff can accept donor offers.';
  END IF;

  IF v_req.status NOT IN ('Open', 'Partially Fulfilled') OR v_req.remaining_units <= 0 THEN
    RAISE EXCEPTION 'This request cannot accept additional units (status: %, remaining: %).', v_req.status, v_req.remaining_units;
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb))
  LOOP
    IF (v_elem->>'id') = p_offer_id OR ((v_elem->>'id') IS NULL AND (v_elem->>'donorId') = p_offer_id) THEN
      IF COALESCE(v_elem->>'status', 'pending') <> 'pending' THEN
        RAISE EXCEPTION 'Offer is already %.', v_elem->>'status';
      END IF;
      v_offered_units := GREATEST(1, COALESCE((v_elem->>'offeredUnits')::integer, 1));
      IF v_offered_units > v_req.remaining_units THEN
        RAISE EXCEPTION 'Cannot accept % unit(s): only % unit(s) remain needed.', v_offered_units, v_req.remaining_units;
      END IF;
      v_found := true;
      v_donor_id := v_elem->>'donorId';
      v_offer := v_elem || jsonb_build_object(
        'status', 'accepted',
        'acceptedAt', timezone('utc'::text, now())
      );
      v_updated_offers := v_updated_offers || jsonb_build_array(v_offer);
    ELSE
      v_updated_offers := v_updated_offers || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  IF NOT v_found THEN
    RAISE EXCEPTION 'Offer not found.';
  END IF;

  v_new_accepted := COALESCE(v_req.accepted_units, 0) + v_offered_units;
  v_new_remaining := GREATEST(0, v_req.required_units - v_new_accepted);
  v_new_status := CASE WHEN v_new_remaining = 0 THEN 'Fulfilled' ELSE 'Partially Fulfilled' END;

  v_accepted_ids := COALESCE(v_req.accepted_donor_ids, '[]'::jsonb);
  IF v_donor_id IS NOT NULL AND NOT (v_accepted_ids @> to_jsonb(v_donor_id)) THEN
    v_accepted_ids := v_accepted_ids || jsonb_build_array(v_donor_id);
  END IF;

  UPDATE public.blood_requests
  SET offers = v_updated_offers,
      accepted_units = v_new_accepted,
      remaining_units = v_new_remaining,
      accepted_donor_ids = v_accepted_ids,
      status = v_new_status,
      fulfilled_at = CASE WHEN v_new_remaining = 0 THEN timezone('utc'::text, now()) ELSE fulfilled_at END,
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', CASE WHEN v_new_remaining = 0 THEN 'request_fulfilled' ELSE 'offer_accepted' END,
        'donorId', v_donor_id,
        'by', v_offer->>'donorName',
        'units', v_offered_units,
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  IF v_donor_id IS NOT NULL AND v_donor_id ~* '^[0-9a-f-]{36}$' THEN
    INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
    VALUES (
      v_donor_id::uuid,
      'Your Blood Offer Was Accepted!',
      'Please proceed to ' || v_req.hospital_name || ' or coordinate directly with the patient contact.',
      'offer_accepted',
      '/request-details',
      p_request_id::text,
      false,
      timezone('utc'::text, now())
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_new_status,
    'accepted_units', v_new_accepted,
    'remaining_units', v_new_remaining
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_blood_offer(
  p_request_id uuid,
  p_offer_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_elem jsonb;
  v_updated_offers jsonb := '[]'::jsonb;
  v_donor_id text;
  v_found boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id <> v_uid AND NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: only the requester or staff can decline offers.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb))
  LOOP
    IF (v_elem->>'id') = p_offer_id OR ((v_elem->>'id') IS NULL AND (v_elem->>'donorId') = p_offer_id) THEN
      v_found := true;
      v_donor_id := v_elem->>'donorId';
      v_updated_offers := v_updated_offers || jsonb_build_array(
        v_elem || jsonb_build_object('status', 'declined', 'declinedAt', timezone('utc'::text, now()))
      );
    ELSE
      v_updated_offers := v_updated_offers || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  IF NOT v_found THEN
    RAISE EXCEPTION 'Offer not found.';
  END IF;

  UPDATE public.blood_requests
  SET offers = v_updated_offers,
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'offer_declined',
        'donorId', v_donor_id,
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  IF v_donor_id IS NOT NULL AND v_donor_id ~* '^[0-9a-f-]{36}$' THEN
    INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
    VALUES (
      v_donor_id::uuid,
      'Offer Status Update',
      'Your offer for ' || v_req.hospital_name || ' was not needed at this time. Thank you for stepping up!',
      'offer_declined',
      '/request-details',
      p_request_id::text,
      false,
      timezone('utc'::text, now())
    );
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.withdraw_blood_offer(
  p_request_id uuid,
  p_offer_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_elem jsonb;
  v_updated_offers jsonb := '[]'::jsonb;
  v_was_accepted boolean := false;
  v_units integer := 0;
  v_new_accepted integer;
  v_new_remaining integer;
  v_new_status text;
  v_found boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb))
  LOOP
    IF ((v_elem->>'id') = p_offer_id OR (v_elem->>'donorId') = v_uid::text) AND NOT v_found AND COALESCE(v_elem->>'status', 'pending') IN ('pending', 'accepted') THEN
      IF (v_elem->>'donorId') <> v_uid::text THEN
        RAISE EXCEPTION 'Unauthorized: you can only withdraw your own offer.';
      END IF;
      IF COALESCE((v_elem->>'donationVerified')::boolean, false) THEN
        RAISE EXCEPTION 'Completed donations cannot be withdrawn.';
      END IF;
      v_found := true;
      v_was_accepted := (v_elem->>'status') = 'accepted';
      v_units := GREATEST(1, COALESCE((v_elem->>'offeredUnits')::integer, 1));
      v_updated_offers := v_updated_offers || jsonb_build_array(
        v_elem || jsonb_build_object('status', 'withdrawn', 'withdrawnAt', timezone('utc'::text, now()))
      );
    ELSE
      v_updated_offers := v_updated_offers || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  IF NOT v_found THEN
    RAISE EXCEPTION 'Active offer not found.';
  END IF;

  v_new_accepted := CASE WHEN v_was_accepted THEN GREATEST(0, COALESCE(v_req.accepted_units, 0) - v_units) ELSE COALESCE(v_req.accepted_units, 0) END;
  v_new_remaining := GREATEST(0, v_req.required_units - v_new_accepted);
  v_new_status := CASE
    WHEN v_req.status IN ('Cancelled', 'Expired') THEN v_req.status
    WHEN v_new_accepted = 0 THEN 'Open'
    WHEN v_new_remaining > 0 THEN 'Partially Fulfilled'
    ELSE 'Fulfilled'
  END;

  UPDATE public.blood_requests
  SET offers = v_updated_offers,
      accepted_units = v_new_accepted,
      remaining_units = v_new_remaining,
      status = v_new_status,
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'offer_withdrawn',
        'donorId', v_uid::text,
        'units', v_units,
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
  VALUES (
    v_req.requester_user_id,
    'Donor Offer Withdrawn',
    'A donor had to withdraw their offer for ' || v_req.hospital_name || '. Remaining units updated automatically.',
    'request_update',
    '/request-details',
    p_request_id::text,
    false,
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object('success', true, 'status', v_new_status, 'remaining_units', v_new_remaining);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_blood_request(
  p_request_id uuid,
  p_reason text DEFAULT 'Cancelled by requester'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_elem jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id <> v_uid AND NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: only the requester or staff can cancel this request.';
  END IF;

  UPDATE public.blood_requests
  SET status = 'Cancelled',
      cancellation_reason = COALESCE(NULLIF(BTRIM(p_reason), ''), 'Cancelled by requester'),
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'request_cancelled',
        'note', COALESCE(NULLIF(BTRIM(p_reason), ''), 'Cancelled by requester'),
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb))
  LOOP
    IF COALESCE(v_elem->>'status', '') IN ('pending', 'accepted') AND (v_elem->>'donorId') ~* '^[0-9a-f-]{36}$' THEN
      INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
      VALUES (
        (v_elem->>'donorId')::uuid,
        'Blood Request Closed',
        'The blood request at ' || v_req.hospital_name || ' has been cancelled: ' || COALESCE(NULLIF(BTRIM(p_reason), ''), 'Closed by requester'),
        'request_update',
        '/request-details',
        p_request_id::text,
        false,
        timezone('utc'::text, now())
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_blood_donation(
  p_request_id uuid,
  p_offer_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_donor public.profiles%ROWTYPE;
  v_elem jsonb;
  v_updated_offers jsonb := '[]'::jsonb;
  v_target_offer jsonb;
  v_donor_uid uuid;
  v_units integer := 1;
  v_cert_id text;
  v_new_total integer;
  v_bonus_points integer := 50;
  v_badges jsonb;
  v_next_eligible timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id <> v_uid AND NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: only the requester or staff can verify donation completion.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb))
  LOOP
    IF (v_elem->>'id') = p_offer_id THEN
      IF COALESCE(v_elem->>'status', '') <> 'accepted' THEN
        RAISE EXCEPTION 'Offer must be accepted before marking donation as completed.';
      END IF;
      IF COALESCE((v_elem->>'donationVerified')::boolean, false) THEN
        RAISE EXCEPTION 'This donation has already been verified and recorded.';
      END IF;
      v_cert_id := 'RCN-' || UPPER(SUBSTR(REPLACE(gen_random_uuid()::text, '-', ''), 1, 8));
      v_units := GREATEST(1, COALESCE((v_elem->>'offeredUnits')::integer, 1));
      v_target_offer := v_elem || jsonb_build_object(
        'donationVerified', true,
        'completedAt', timezone('utc'::text, now()),
        'certificateId', v_cert_id
      );
      v_updated_offers := v_updated_offers || jsonb_build_array(v_target_offer);
    ELSE
      v_updated_offers := v_updated_offers || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  IF v_target_offer IS NULL THEN
    RAISE EXCEPTION 'Accepted offer not found.';
  END IF;

  UPDATE public.blood_requests
  SET offers = v_updated_offers,
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'donation_completed',
        'by', v_target_offer->>'donorName',
        'donorId', v_target_offer->>'donorId',
        'units', v_units,
        'certificateId', v_cert_id,
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  IF (v_target_offer->>'donorId') ~* '^[0-9a-f-]{36}$' THEN
    v_donor_uid := (v_target_offer->>'donorId')::uuid;
    SELECT * INTO v_donor FROM public.profiles WHERE id = v_donor_uid FOR UPDATE;
    IF FOUND THEN
      v_new_total := COALESCE(v_donor.total_donations, 0) + 1;
      IF v_req.urgency_level = 'Critical' THEN
        v_bonus_points := 65;
      END IF;
      v_next_eligible := timezone('utc'::text, now()) + make_interval(days => COALESCE(v_donor.cooldown_days, 90));
      v_badges := COALESCE(v_donor.badges, '[]'::jsonb);

      IF v_new_total >= 1 AND NOT (v_badges @> '["First Drop"]'::jsonb) THEN
        v_badges := v_badges || '["First Drop"]'::jsonb;
      END IF;
      IF v_new_total >= 5 AND NOT (v_badges @> '["High Five"]'::jsonb) THEN
        v_badges := v_badges || '["High Five"]'::jsonb;
      END IF;
      IF v_new_total >= 10 AND NOT (v_badges @> '["Double Digits"]'::jsonb) THEN
        v_badges := v_badges || '["Double Digits"]'::jsonb;
      END IF;
      IF v_new_total >= 15 AND NOT (v_badges @> '["Legend Donor"]'::jsonb) THEN
        v_badges := v_badges || '["Legend Donor"]'::jsonb;
      END IF;
      IF COALESCE(v_donor.blood_type, '') IN ('O-', 'AB-', 'AB+', 'B-', 'A-') AND NOT (v_badges @> '["Rare Hero"]'::jsonb) THEN
        v_badges := v_badges || '["Rare Hero"]'::jsonb;
      END IF;
      IF v_req.urgency_level = 'Critical' AND NOT (v_badges @> '["Crisis Warrior"]'::jsonb) THEN
        v_badges := v_badges || '["Crisis Warrior"]'::jsonb;
      END IF;

      UPDATE public.profiles
      SET total_donations = v_new_total,
          points = COALESCE(points, 0) + v_bonus_points,
          badges = v_badges,
          last_donation_date = timezone('utc'::text, now()),
          next_eligible_date = v_next_eligible,
          is_available_to_donate = false,
          availability_status = 'unavailable',
          donation_history = jsonb_build_array(jsonb_build_object(
            'id', 'don_' || replace(gen_random_uuid()::text, '-', ''),
            'date', timezone('utc'::text, now()),
            'hospital', v_req.hospital_name,
            'location', COALESCE(NULLIF(v_req.hospital_address, ''), v_req.city),
            'bloodType', COALESCE(v_donor.blood_type, v_req.required_blood_type),
            'units', v_units,
            'notes', 'Verified hospital donation via RedCellNet (' || COALESCE(v_req.component_type, 'Whole Blood') || ')',
            'requestId', p_request_id::text,
            'verified', true,
            'certificateId', v_cert_id
          )) || COALESCE(donation_history, '[]'::jsonb),
          updated_at = timezone('utc'::text, now())
      WHERE id = v_donor_uid;

      INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
      VALUES (
        v_donor_uid,
        'Verified Donation Recorded — Thank You!',
        'Your donation at ' || v_req.hospital_name || ' is verified! Certificate ' || v_cert_id || ' is now unlocked in your profile.',
        'donation_completed',
        '/profile',
        p_request_id::text,
        false,
        timezone('utc'::text, now())
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'certificate_id', v_cert_id);
END;
$$;

-- 11. Smart Compatible Emergency Donor Notification Dispatch RPC
CREATE OR REPLACE FUNCTION public.dispatch_emergency_request_notifications(
  p_request_id uuid,
  p_radius_km double precision DEFAULT 15.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_req_lat double precision;
  v_req_lng double precision;
  v_rec RECORD;
  v_notified integer := 0;
  v_fallback boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id <> v_uid AND NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_req_lat := (v_req.location_coords->>'latitude')::double precision;
  v_req_lng := (v_req.location_coords->>'longitude')::double precision;

  -- Pass 1: Nearby compatible available eligible donors within p_radius_km
  IF v_req_lat IS NOT NULL AND v_req_lng IS NOT NULL THEN
    FOR v_rec IN
      SELECT p.id,
             private.haversine_km(
               v_req_lat, v_req_lng,
               (p.location_coords->>'latitude')::double precision,
               (p.location_coords->>'longitude')::double precision
             ) AS dist_km
      FROM public.profiles p
      WHERE p.id <> v_req.requester_user_id
        AND COALESCE(p.is_banned, false) = false
        AND private.is_blood_compatible(p.blood_type, v_req.required_blood_type, COALESCE(v_req.component_type, 'Whole Blood'))
        AND (
          COALESCE(p.is_available_to_donate, false) = true
          OR (p.availability_status = 'temporarily_unavailable' AND p.available_until IS NOT NULL AND p.available_until <= timezone('utc'::text, now()))
        )
        AND (p.next_eligible_date IS NULL OR p.next_eligible_date <= timezone('utc'::text, now()))
        AND (p.notifications_paused_until IS NULL OR p.notifications_paused_until <= timezone('utc'::text, now()))
        AND COALESCE((p.notification_preferences->>'emergency_alerts')::boolean, true) = true
        AND p.location_coords IS NOT NULL
        AND private.haversine_km(
              v_req_lat, v_req_lng,
              (p.location_coords->>'latitude')::double precision,
              (p.location_coords->>'longitude')::double precision
            ) <= GREATEST(2.0, COALESCE(p_radius_km, 15.0))
        AND NOT EXISTS (
          SELECT 1 FROM public.notifications n
          WHERE n.user_id = p.id AND n.resource_id = p_request_id::text
        )
        AND (
          SELECT count(*) FROM public.notifications n2
          WHERE n2.user_id = p.id
            AND n2.type = 'emergency_request'
            AND n2.created_at > timezone('utc'::text, now()) - interval '1 hour'
        ) < 5
      ORDER BY dist_km ASC NULLS LAST
      LIMIT 50
    LOOP
      INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
      VALUES (
        v_rec.id,
        v_req.urgency_level || ': ' || v_req.required_blood_type || ' Blood Needed Nearby',
        v_req.remaining_units || ' unit(s) needed at ' || v_req.hospital_name || ' (' || ROUND(v_rec.dist_km::numeric, 1) || ' km away).',
        'emergency_request',
        '/request-details',
        p_request_id::text,
        false,
        timezone('utc'::text, now())
      );
      v_notified := v_notified + 1;
    END LOOP;
  END IF;

  -- Pass 2: Fallback expansion (same city or wider compatible pool when 0 nearby donors matched)
  IF v_notified = 0 THEN
    v_fallback := true;
    FOR v_rec IN
      SELECT p.id
      FROM public.profiles p
      WHERE p.id <> v_req.requester_user_id
        AND COALESCE(p.is_banned, false) = false
        AND private.is_blood_compatible(p.blood_type, v_req.required_blood_type, COALESCE(v_req.component_type, 'Whole Blood'))
        AND (
          COALESCE(p.is_available_to_donate, false) = true
          OR (p.availability_status = 'temporarily_unavailable' AND p.available_until IS NOT NULL AND p.available_until <= timezone('utc'::text, now()))
        )
        AND (p.next_eligible_date IS NULL OR p.next_eligible_date <= timezone('utc'::text, now()))
        AND (p.notifications_paused_until IS NULL OR p.notifications_paused_until <= timezone('utc'::text, now()))
        AND COALESCE((p.notification_preferences->>'emergency_alerts')::boolean, true) = true
        AND NOT EXISTS (
          SELECT 1 FROM public.notifications n
          WHERE n.user_id = p.id AND n.resource_id = p_request_id::text
        )
        AND (
          SELECT count(*) FROM public.notifications n2
          WHERE n2.user_id = p.id
            AND n2.type = 'emergency_request'
            AND n2.created_at > timezone('utc'::text, now()) - interval '1 hour'
        ) < 5
      ORDER BY
        CASE WHEN v_req.city <> '' AND p.location_city ILIKE '%' || v_req.city || '%' THEN 0 ELSE 1 END,
        COALESCE(p.is_verified_donor, false) DESC
      LIMIT 50
    LOOP
      INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
      VALUES (
        v_rec.id,
        v_req.urgency_level || ': ' || v_req.required_blood_type || ' Blood Needed',
        v_req.remaining_units || ' unit(s) needed at ' || v_req.hospital_name || COALESCE(' (' || NULLIF(v_req.city, '') || ')', '') || '.',
        'emergency_request',
        '/request-details',
        p_request_id::text,
        false,
        timezone('utc'::text, now())
      );
      v_notified := v_notified + 1;
    END LOOP;
  END IF;

  UPDATE public.blood_requests
  SET notified_donor_count = COALESCE(notified_donor_count, 0) + v_notified,
      timeline = CASE
        WHEN v_notified > 0 THEN COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
          'action', 'donors_notified',
          'note', v_notified || ' compatible donor(s) alerted',
          'time', timezone('utc'::text, now())
        ))
        ELSE timeline
      END
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'notified_count', v_notified, 'fallback_used', v_fallback);
END;
$$;

-- 12. Self-Service Account Deletion RPC
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.blood_requests
  SET status = 'Cancelled',
      cancellation_reason = 'Account deleted by requester',
      updated_at = timezone('utc'::text, now())
  WHERE requester_user_id = v_uid
    AND status IN ('Open', 'Partially Fulfilled');

  DELETE FROM public.notifications WHERE user_id = v_uid;
  DELETE FROM public.blood_requests WHERE requester_user_id = v_uid;
  DELETE FROM public.profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 13. Lock Down EXECUTE Privileges on All Public RPCs (Never Executable by PUBLIC / anon)
REVOKE ALL ON FUNCTION public.verify_donor(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_donor(uuid, boolean, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.manage_user_role(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manage_user_role(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_user_ban_status(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_user_ban_status(uuid, boolean, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.verify_hospital_case(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_hospital_case(uuid, boolean, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.resolve_moderation_report(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_moderation_report(uuid, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_emergency_broadcast(text, text, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_emergency_broadcast(text, text, text, text, text, timestamptz) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_emergency_broadcast(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_emergency_broadcast(text, text, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.send_direct_admin_notification(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_direct_admin_notification(uuid, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.update_system_broadcast(uuid, text, text, text, text, text, boolean, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_system_broadcast(uuid, text, text, text, text, text, boolean, timestamptz) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.check_and_expire_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_and_expire_requests() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_blood_offer(uuid, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_blood_offer(uuid, integer, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.accept_blood_offer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_blood_offer(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reject_blood_offer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_blood_offer(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.withdraw_blood_offer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.withdraw_blood_offer(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cancel_blood_request(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_blood_request(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.complete_blood_donation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_blood_donation(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.dispatch_emergency_request_notifications(uuid, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_emergency_request_notifications(uuid, double precision) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated, service_role;


-- 14. Requester Release / No-Show Reopen Accepted Offer RPC & Privacy-Safe Donor Clusters RPC
CREATE OR REPLACE FUNCTION public.release_accepted_offer(
  p_request_id uuid,
  p_offer_id text,
  p_reason text DEFAULT 'Donor could not attend'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_elem jsonb;
  v_updated_offers jsonb := '[]'::jsonb;
  v_units integer := 0;
  v_donor_id text;
  v_new_accepted integer;
  v_new_remaining integer;
  v_new_status text;
  v_found boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req FROM public.blood_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found.';
  END IF;

  IF v_req.requester_user_id <> v_uid AND NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: only the requester or staff can release an accepted offer.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.offers, '[]'::jsonb))
  LOOP
    IF (v_elem->>'id') = p_offer_id AND NOT v_found THEN
      IF (v_elem->>'status') <> 'accepted' THEN
        RAISE EXCEPTION 'Only accepted offers can be released.';
      END IF;
      IF COALESCE((v_elem->>'donationVerified')::boolean, false) THEN
        RAISE EXCEPTION 'Verified completed donations cannot be released.';
      END IF;
      v_found := true;
      v_donor_id := v_elem->>'donorId';
      v_units := GREATEST(1, COALESCE((v_elem->>'offeredUnits')::integer, 1));
      v_updated_offers := v_updated_offers || jsonb_build_array(
        v_elem || jsonb_build_object(
          'status', 'declined',
          'releaseReason', COALESCE(NULLIF(BTRIM(p_reason), ''), 'Released by requester'),
          'releasedAt', timezone('utc'::text, now())
        )
      );
    ELSE
      v_updated_offers := v_updated_offers || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  IF NOT v_found THEN
    RAISE EXCEPTION 'Accepted offer not found.';
  END IF;

  v_new_accepted := GREATEST(0, COALESCE(v_req.accepted_units, 0) - v_units);
  v_new_remaining := GREATEST(0, v_req.required_units - v_new_accepted);
  v_new_status := CASE
    WHEN v_new_accepted = 0 THEN 'Open'
    WHEN v_new_remaining > 0 THEN 'Partially Fulfilled'
    ELSE 'Fulfilled'
  END;

  UPDATE public.blood_requests
  SET offers = v_updated_offers,
      accepted_units = v_new_accepted,
      remaining_units = v_new_remaining,
      status = v_new_status,
      timeline = COALESCE(timeline, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'action', 'offer_released',
        'donorId', v_donor_id,
        'units', v_units,
        'note', COALESCE(NULLIF(BTRIM(p_reason), ''), 'Released by requester'),
        'time', timezone('utc'::text, now())
      )),
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  IF v_donor_id IS NOT NULL AND v_donor_id ~* '^[0-9a-f-]{36}$' THEN
    INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
    VALUES (
      v_donor_id::uuid,
      'Accepted Slot Reopened',
      'Your slot for ' || v_req.hospital_name || ' was released so another donor can assist.',
      'request_update',
      '/request-details',
      p_request_id::text,
      false,
      timezone('utc'::text, now())
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'status', v_new_status, 'remaining_units', v_new_remaining);
END;
$$;

-- Privacy-Safe Anonymized Nearby Donor Clusters (~2km coarse grid, zero PII or exact coordinates)
CREATE OR REPLACE FUNCTION public.get_nearby_donor_clusters(
  p_lat double precision DEFAULT 23.8103,
  p_lng double precision DEFAULT 90.4125,
  p_radius_km double precision DEFAULT 25.0,
  p_blood_type text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      COALESCE(NULLIF(BTRIM(p.location_city), ''), 'Local Area') AS area_label,
      ROUND(COALESCE((p.location_coords->>'latitude')::numeric, p_lat::numeric), 2)::double precision AS coarse_lat,
      ROUND(COALESCE((p.location_coords->>'longitude')::numeric, p_lng::numeric), 2)::double precision AS coarse_lng,
      COUNT(*)::integer AS donor_count,
      COUNT(*) FILTER (WHERE COALESCE(p.is_verified_donor, false) = true)::integer AS verified_count,
      jsonb_agg(DISTINCT p.blood_type) FILTER (WHERE p.blood_type IS NOT NULL) AS blood_types
    FROM public.profiles p
    WHERE COALESCE(p.is_banned, false) = false
      AND p.blood_type IS NOT NULL
      AND COALESCE(p.is_available_to_donate, false) = true
      AND COALESCE((p.privacy_settings->>'show_area_availability')::boolean, true) = true
      AND (p.next_eligible_date IS NULL OR p.next_eligible_date <= timezone('utc'::text, now()))
      AND (
        p_blood_type IS NULL
        OR BTRIM(p_blood_type) = ''
        OR UPPER(BTRIM(p_blood_type)) = 'ALL'
        OR private.is_blood_compatible(p.blood_type, p_blood_type, 'Whole Blood')
      )
      AND (
        p.location_coords IS NULL
        OR private.haversine_km(
             p_lat, p_lng,
             (p.location_coords->>'latitude')::double precision,
             (p.location_coords->>'longitude')::double precision
           ) <= GREATEST(2.0, COALESCE(p_radius_km, 25.0))
      )
    GROUP BY
      COALESCE(NULLIF(BTRIM(p.location_city), ''), 'Local Area'),
      ROUND(COALESCE((p.location_coords->>'latitude')::numeric, p_lat::numeric), 2),
      ROUND(COALESCE((p.location_coords->>'longitude')::numeric, p_lng::numeric), 2)
    LIMIT 30
  ) t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.release_accepted_offer(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.release_accepted_offer(uuid, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_nearby_donor_clusters(double precision, double precision, double precision, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_donor_clusters(double precision, double precision, double precision, text) TO authenticated, service_role;

-- Privacy-Safe Anonymized Community Metrics RPC
CREATE OR REPLACE FUNCTION public.get_community_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_available_donors integer := 0;
  v_verified_donors integer := 0;
  v_fulfilled_requests integer := 0;
  v_active_requests integer := 0;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE COALESCE(is_available_to_donate, false) = true AND COALESCE(is_banned, false) = false),
    COUNT(*) FILTER (WHERE COALESCE(is_verified_donor, false) = true AND COALESCE(is_banned, false) = false)
  INTO v_available_donors, v_verified_donors
  FROM public.profiles;

  SELECT
    COUNT(*) FILTER (WHERE status = 'Fulfilled'),
    COUNT(*) FILTER (WHERE status IN ('Open', 'Partially Fulfilled') AND (expiry_at IS NULL OR expiry_at > timezone('utc'::text, now())))
  INTO v_fulfilled_requests, v_active_requests
  FROM public.blood_requests;

  RETURN jsonb_build_object(
    'available_donors', v_available_donors,
    'verified_donors', v_verified_donors,
    'fulfilled_requests', v_fulfilled_requests,
    'active_requests', v_active_requests
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_community_metrics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_community_metrics() TO authenticated, service_role;


-- 15. Atomic Educational Content Points & 'Health Aware' Badge Unlocking RPC
CREATE OR REPLACE FUNCTION public.award_content_reading_points(
  p_content_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_prof public.profiles%ROWTYPE;
  v_viewed jsonb;
  v_badges jsonb;
  v_pts integer := 5;
  v_badge_unlocked boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_content_id IS NULL OR BTRIM(p_content_id) = '' THEN
    RETURN jsonb_build_object('awarded', false, 'points_added', 0);
  END IF;

  SELECT * INTO v_prof FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('awarded', false, 'points_added', 0);
  END IF;

  v_viewed := COALESCE(v_prof.viewed_content_ids, '[]'::jsonb);
  IF v_viewed @> to_jsonb(p_content_id) THEN
    RETURN jsonb_build_object('awarded', false, 'points_added', 0);
  END IF;

  IF p_content_id ~* '^[0-9a-f-]{36}$' THEN
    SELECT COALESCE(points_value, points, 5)
    INTO v_pts
    FROM public.educational_content
    WHERE id = p_content_id::uuid;
    v_pts := COALESCE(v_pts, 5);
  END IF;

  v_viewed := v_viewed || jsonb_build_array(p_content_id);
  v_badges := COALESCE(v_prof.badges, '[]'::jsonb);

  IF jsonb_array_length(v_viewed) >= 3 AND NOT (v_badges @> '["Health Aware"]'::jsonb) THEN
    v_badges := v_badges || '["Health Aware"]'::jsonb;
    v_pts := v_pts + 10;
    v_badge_unlocked := true;
  END IF;

  UPDATE public.profiles
  SET viewed_content_ids = v_viewed,
      points = COALESCE(points, 0) + v_pts,
      badges = v_badges,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'awarded', true,
    'points_added', v_pts,
    'badge_unlocked', CASE WHEN v_badge_unlocked THEN 'Health Aware' ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.award_content_reading_points(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_content_reading_points(text) TO authenticated, service_role;
