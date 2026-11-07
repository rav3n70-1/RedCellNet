-- supabase/migrations/20261107150000_zero_cost_features_streaks_trgm_cron.sql
-- Zero-Cost Backend Upgrades & Strict Donor/Staff Separation for RedCellNet:
--   1. pg_trgm Fuzzy Search Extension & GIN Trigram Indexes
--   2. Donor Streaks with Medical Freeze, Referral Codes & Health Journal on profiles
--   3. Community Blood Camps Calendar Table + RLS (supports both App & Web Admin Panels)
--   4. Privacy-Safe Community Leaderboard RPC (excludes Admin/Moderator Staff)
--   5. Strict Admin/Staff vs Donor Separation across Metrics, Map Clusters, Dispatches & Role Management
--   6. Auto-Expire & Archive Stale Data RPC + Optional pg_cron Schedule
--   7. Lightweight Keep-Alive Ping RPC for GitHub Actions Free-Tier Protection

BEGIN;

-- 1. Enable pg_trgm for zero-cost typo-tolerant fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_blood_requests_hospital_trgm
  ON public.blood_requests USING gin (hospital_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_blood_requests_city_trgm
  ON public.blood_requests USING gin (city gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_donation_centers_name_trgm
  ON public.donation_centers USING gin (name gin_trgm_ops);

-- 2. Extend public.profiles with Streak Freeze, Referral Code & Health Journal
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS streak_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS streak_frozen boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS streak_freeze_reason text,
  ADD COLUMN IF NOT EXISTS referral_code text,
  ADD COLUMN IF NOT EXISTS referred_by text,
  ADD COLUMN IF NOT EXISTS health_journal jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_profiles_leaderboard_points
  ON public.profiles (points DESC, total_donations DESC)
  WHERE is_banned = false AND COALESCE(role, 'user') = 'user';

-- Ensure all existing Admin & Moderator accounts are isolated from the active donor pool
UPDATE public.profiles
SET
  is_available_to_donate = false,
  availability_status = 'unavailable'
WHERE role IN ('admin', 'moderator');

-- 3. Blood Camps Calendar Table + RLS
CREATE TABLE IF NOT EXISTS public.blood_camps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  organizer text NOT NULL DEFAULT 'RedCellNet',
  venue text NOT NULL DEFAULT '',
  location text NOT NULL DEFAULT '',
  city text NOT NULL DEFAULT 'Dhaka',
  event_date text NOT NULL DEFAULT '',
  contact_phone text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  start_time timestamptz NOT NULL DEFAULT timezone('utc', now()),
  end_time timestamptz NOT NULL DEFAULT (timezone('utc', now()) + interval '6 hours'),
  target_units integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.blood_camps
  ADD COLUMN IF NOT EXISTS venue text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS location text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city text NOT NULL DEFAULT 'Dhaka',
  ADD COLUMN IF NOT EXISTS event_date text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS contact_phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS start_time timestamptz NOT NULL DEFAULT timezone('utc', now()),
  ADD COLUMN IF NOT EXISTS end_time timestamptz NOT NULL DEFAULT (timezone('utc', now()) + interval '6 hours'),
  ADD COLUMN IF NOT EXISTS target_units integer NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

ALTER TABLE public.blood_camps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active blood camps" ON public.blood_camps;
CREATE POLICY "Anyone can view active blood camps"
  ON public.blood_camps
  FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Staff can manage blood camps" ON public.blood_camps;
CREATE POLICY "Staff can manage blood camps"
  ON public.blood_camps
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role IN ('admin', 'moderator')
        AND p.is_banned = false
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role IN ('admin', 'moderator')
        AND p.is_banned = false
    )
  );

-- 4. Privacy-Safe Community Leaderboard RPC (Strictly Regular Donors Only)
CREATE OR REPLACE FUNCTION public.get_community_leaderboard(p_city text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      ROW_NUMBER() OVER (ORDER BY p.points DESC, p.total_donations DESC) AS rank,
      CASE
        WHEN COALESCE(trim(p.name), '') = '' THEN 'Verified Lifesaver'
        WHEN position(' ' IN trim(p.name)) > 0 THEN
          split_part(trim(p.name), ' ', 1) || ' ' ||
          left(split_part(trim(p.name), ' ', 2), 1) || '.'
        ELSE trim(p.name)
      END AS display_name,
      COALESCE(NULLIF(trim(p.blood_type), ''), 'O+') AS blood_type,
      COALESCE(NULLIF(trim(p.location_city), ''), 'Bangladesh') AS city,
      COALESCE(p.total_donations, 0) AS total_donations,
      COALESCE(p.points, 0) AS points,
      CASE
        WHEN COALESCE(p.total_donations, 0) >= 5 OR COALESCE(p.points, 0) >= 500 THEN 'Gold Guardian'
        WHEN COALESCE(p.total_donations, 0) >= 2 OR COALESCE(p.points, 0) >= 200 THEN 'Silver Hero'
        ELSE 'Verified Hero'
      END AS tier,
      COALESCE(p.is_verified_donor, false) AS is_verified
    FROM public.profiles p
    WHERE COALESCE(p.is_banned, false) = false
      AND COALESCE(p.role, 'user') = 'user'
      AND (COALESCE(p.total_donations, 0) > 0 OR COALESCE(p.points, 0) > 0)
      AND COALESCE((p.privacy_settings->>'share_stats_on_pass')::boolean, true) = true
      AND (
        p_city IS NULL
        OR trim(p_city) = ''
        OR p.location_city ILIKE '%' || trim(p_city) || '%'
      )
    ORDER BY p.points DESC, p.total_donations DESC
    LIMIT 20
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_community_leaderboard(text) TO anon, authenticated;

-- 5. Toggle Medical Streak Freeze RPC
CREATE OR REPLACE FUNCTION public.toggle_medical_streak_freeze(
  p_frozen boolean,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.profiles
  SET
    streak_frozen = COALESCE(p_frozen, false),
    streak_freeze_reason = CASE WHEN COALESCE(p_frozen, false) THEN p_reason ELSE NULL END,
    updated_at = timezone('utc', now())
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'streak_frozen', COALESCE(p_frozen, false),
    'reason', p_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_medical_streak_freeze(boolean, text) TO authenticated;

-- 6. Typo-Tolerant Fuzzy Search RPC using pg_trgm
CREATE OR REPLACE FUNCTION public.search_requests_fuzzy(p_query text)
RETURNS SETOF public.blood_requests
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.*
  FROM public.blood_requests r
  WHERE r.status IN ('Open', 'Partially Fulfilled')
    AND (
      COALESCE(trim(p_query), '') = ''
      OR r.hospital_name ILIKE '%' || trim(p_query) || '%'
      OR r.city ILIKE '%' || trim(p_query) || '%'
      OR r.required_blood_type ILIKE '%' || trim(p_query) || '%'
      OR similarity(COALESCE(r.hospital_name, ''), trim(p_query)) > 0.22
      OR similarity(COALESCE(r.city, ''), trim(p_query)) > 0.25
    )
  ORDER BY
    GREATEST(
      similarity(COALESCE(r.hospital_name, ''), COALESCE(trim(p_query), '')),
      similarity(COALESCE(r.city, ''), COALESCE(trim(p_query), ''))
    ) DESC,
    r.created_at DESC
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.search_requests_fuzzy(text) TO anon, authenticated;

-- 7. Strict Donor/Staff Separation in Community Metrics, Clusters, Dispatches & Role Management
CREATE OR REPLACE FUNCTION public.get_community_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
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
    COUNT(*) FILTER (
      WHERE COALESCE(role, 'user') = 'user'
        AND COALESCE(is_available_to_donate, false) = true
        AND COALESCE(is_banned, false) = false
    ),
    COUNT(*) FILTER (
      WHERE COALESCE(role, 'user') = 'user'
        AND COALESCE(is_verified_donor, false) = true
        AND COALESCE(is_banned, false) = false
    )
  INTO v_available_donors, v_verified_donors
  FROM public.profiles;

  SELECT
    COUNT(*) FILTER (WHERE status = 'Fulfilled'),
    COUNT(*) FILTER (
      WHERE status IN ('Open', 'Partially Fulfilled')
        AND (expiry_at IS NULL OR expiry_at > timezone('utc'::text, now()))
    )
  INTO v_fulfilled_requests, v_active_requests
  FROM public.blood_requests;

  RETURN jsonb_build_object(
    'available_donors', v_available_donors,
    'verified_donors', v_verified_donors,
    'fulfilled_requests', v_fulfilled_requests,
    'active_requests', v_active_requests
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_nearby_donor_clusters(
  p_lat double precision DEFAULT 23.8103,
  p_lng double precision DEFAULT 90.4125,
  p_radius_km double precision DEFAULT 25.0,
  p_blood_type text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
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
      AND COALESCE(p.role, 'user') = 'user'
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
$function$;

CREATE OR REPLACE FUNCTION public.dispatch_emergency_request_notifications(
  p_request_id uuid,
  p_radius_km double precision DEFAULT 15.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
        AND COALESCE(p.role, 'user') = 'user'
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

  IF v_notified = 0 THEN
    v_fallback := true;
    FOR v_rec IN
      SELECT p.id
      FROM public.profiles p
      WHERE p.id <> v_req.requester_user_id
        AND COALESCE(p.is_banned, false) = false
        AND COALESCE(p.role, 'user') = 'user'
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
$function$;

CREATE OR REPLACE FUNCTION public.create_emergency_broadcast(
  broadcast_title text,
  broadcast_message text,
  b_type text DEFAULT 'shortage'::text,
  target_blood text DEFAULT NULL::text,
  target_city text DEFAULT NULL::text,
  broadcast_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
    WHERE COALESCE(role, 'user') = 'user'
      AND (target_blood IS NULL OR BTRIM(target_blood) = '' OR UPPER(BTRIM(target_blood)) = 'ALL' OR blood_type = target_blood)
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
$function$;

CREATE OR REPLACE FUNCTION public.manage_user_role(target_user_id uuid, new_role text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
      is_available_to_donate = CASE WHEN v_role IN ('admin', 'moderator') THEN false ELSE is_available_to_donate END,
      availability_status = CASE WHEN v_role IN ('admin', 'moderator') THEN 'unavailable' ELSE availability_status END,
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
$function$;

-- 8. Auto-Expire & Archive Stale Data RPC (Protects 500 MB Free-Tier Database Limit)
CREATE OR REPLACE FUNCTION public.cleanup_and_archive_stale_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_requests integer := 0;
  v_expired_broadcasts integer := 0;
  v_trimmed_notifications integer := 0;
BEGIN
  -- Expire open requests past expiry_at or older than 14 days
  WITH expired AS (
    UPDATE public.blood_requests
    SET
      status = 'Expired',
      updated_at = timezone('utc', now())
    WHERE status IN ('Open', 'Partially Fulfilled')
      AND (
        (expiry_at IS NOT NULL AND expiry_at <= timezone('utc', now()))
        OR created_at < timezone('utc', now()) - interval '14 days'
      )
    RETURNING 1
  )
  SELECT count(*) INTO v_expired_requests FROM expired;

  -- Deactivate expired system broadcasts
  WITH expired_b AS (
    UPDATE public.system_broadcasts
    SET is_active = false
    WHERE is_active = true
      AND expires_at IS NOT NULL
      AND expires_at <= timezone('utc', now())
    RETURNING 1
  )
  SELECT count(*) INTO v_expired_broadcasts FROM expired_b;

  -- Trim read notifications older than 60 days
  WITH trimmed AS (
    DELETE FROM public.notifications
    WHERE is_read = true
      AND created_at < timezone('utc', now()) - interval '60 days'
    RETURNING 1
  )
  SELECT count(*) INTO v_trimmed_notifications FROM trimmed;

  RETURN jsonb_build_object(
    'expired_requests', v_expired_requests,
    'expired_requests_closed', v_expired_requests,
    'expired_broadcasts_deactivated', v_expired_broadcasts,
    'trimmed_notifications', v_trimmed_notifications,
    'executed_at', timezone('utc', now())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_and_archive_stale_data() TO authenticated;

-- 9. Lightweight Keep-Alive Ping RPC (Prevents Supabase Free-Tier 7-Day Pause)
CREATE OR REPLACE FUNCTION public.health_keepalive_ping()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'status', 'ok',
    'service', 'RedCellNet LifePulse',
    'timestamp', timezone('utc', now())
  );
$$;

GRANT EXECUTE ON FUNCTION public.health_keepalive_ping() TO anon, authenticated;

-- 10. Optional pg_cron Registration (Safe no-op if pg_cron is not enabled on instance)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron'
  ) THEN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    PERFORM cron.schedule(
      'redcellnet_nightly_cleanup',
      '15 3 * * *',
      $cron$SELECT public.cleanup_and_archive_stale_data();$cron$
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

COMMIT;
