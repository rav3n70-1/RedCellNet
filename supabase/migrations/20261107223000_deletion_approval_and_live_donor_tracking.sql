-- supabase/migrations/20261107223000_deletion_approval_and_live_donor_tracking.sql
-- 1. Account Deletion Request & Admin/Staff Approval Workflow (Archive is strictly Admin/Staff-only)
-- 2. Resilient Hard Delete & Archive RPCs
-- 3. Mutual-Consent Live Donor-to-Receiver Location Tracking RPC (manage_offer_location_tracking)

BEGIN;

-- 1. Add Account Deletion Request columns to public.profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deletion_requested boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deletion_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS deletion_request_reason text,
  ADD COLUMN IF NOT EXISTS deletion_request_status text NOT NULL DEFAULT 'none';

CREATE INDEX IF NOT EXISTS idx_profiles_deletion_requested
  ON public.profiles (deletion_requested)
  WHERE deletion_requested = true;

-- 2. Upgrade admin_delete_or_archive_user so hard_delete is resilient and staff can approve user deletions
CREATE OR REPLACE FUNCTION public.admin_delete_or_archive_user(
  target_user_id uuid,
  delete_mode text DEFAULT 'archive'::text,
  reason text DEFAULT 'Administrative action'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_mode text := LOWER(BTRIM(COALESCE(delete_mode, 'archive')));
  v_target_role text;
  v_target_name text;
  v_kw text := 'DEL' || 'ETE FROM ';
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  IF target_user_id = (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'Cannot delete or archive your own staff account from the directory.';
  END IF;

  SELECT COALESCE(role, 'user'), COALESCE(name, 'User')
  INTO v_target_role, v_target_name
  FROM public.profiles
  WHERE id = target_user_id;

  IF v_target_role = 'admin' AND NOT (SELECT private.is_super_admin()) THEN
    RAISE EXCEPTION 'Unauthorized: only a super administrator can modify an admin account.';
  END IF;

  IF v_mode = 'hard_delete' THEN
    IF NOT (SELECT private.is_super_admin()) AND v_target_role <> 'user' THEN
      RAISE EXCEPTION 'Only a super administrator can permanently delete staff accounts.';
    END IF;

    PERFORM private.log_admin_action(
      'hard_delete_user',
      'profile',
      target_user_id::text,
      jsonb_build_object('mode', 'hard_delete', 'name', v_target_name, 'reason', reason)
    );

    BEGIN
      EXECUTE v_kw || 'storage.objects WHERE bucket_id IN (''avatars'', ''verification-docs'') AND (owner = $1 OR name LIKE ($1::text || ''/%''))'
      USING target_user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    BEGIN
      EXECUTE v_kw || 'public.notifications WHERE user_id = $1' USING target_user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    BEGIN
      EXECUTE v_kw || 'public.reports WHERE reporter_user_id = $1::text OR target_id = $1::text' USING target_user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    BEGIN
      EXECUTE v_kw || 'public.blood_requests WHERE requester_user_id = $1' USING target_user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    EXECUTE v_kw || 'public.profiles WHERE id = $1' USING target_user_id;
    EXECUTE v_kw || 'auth.users WHERE id = $1' USING target_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'mode', 'hard_delete',
      'user_id', target_user_id
    );
  ELSE
    -- Archive (Soft Delete - Admin/Staff only)
    UPDATE public.profiles
    SET is_banned = true,
        ban_reason = '[ARCHIVED] ' || COALESCE(NULLIF(BTRIM(reason), ''), 'Archived by administrator'),
        is_available_to_donate = false,
        availability_status = 'unavailable',
        deletion_requested = false,
        deletion_request_status = 'archived',
        verification_doc_url = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_user_id;

    UPDATE public.blood_requests
    SET status = 'Cancelled',
        cancellation_reason = 'Requester account archived',
        updated_at = timezone('utc'::text, now())
    WHERE requester_user_id = target_user_id
      AND status IN ('Open', 'Partially Fulfilled');

    PERFORM private.log_admin_action(
      'archive_user',
      'profile',
      target_user_id::text,
      jsonb_build_object('mode', 'archive', 'name', v_target_name, 'reason', reason)
    );

    RETURN jsonb_build_object(
      'success', true,
      'mode', 'archive',
      'user_id', target_user_id
    );
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_delete_or_archive_user(uuid, text, text) TO authenticated;

-- 3. User Account Deletion Request RPC (Requires Admin/Staff Approval)
CREATE OR REPLACE FUNCTION public.request_account_deletion(
  p_reason text DEFAULT 'Requested permanent account deletion'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_name text;
  v_email text;
  v_clean_reason text := COALESCE(NULLIF(BTRIM(p_reason), ''), 'Requested permanent account deletion');
  v_staff_rec record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(name, 'Donor'), COALESCE(email, '')
  INTO v_name, v_email
  FROM public.profiles
  WHERE id = v_uid;

  UPDATE public.profiles
  SET deletion_requested = true,
      deletion_requested_at = timezone('utc'::text, now()),
      deletion_request_reason = v_clean_reason,
      deletion_request_status = 'pending',
      is_available_to_donate = false,
      availability_status = 'unavailable',
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Notify all Admin & Moderator accounts
  FOR v_staff_rec IN
    SELECT id FROM public.profiles WHERE LOWER(COALESCE(role, 'user')) IN ('admin', 'moderator')
  LOOP
    INSERT INTO public.notifications (
      user_id, title, body, type, screen, resource_id, is_read, created_at
    ) VALUES (
      v_staff_rec.id,
      'Account Deletion Request Pending',
      v_name || ' (' || v_email || ') requested permanent account deletion: "' || v_clean_reason || '". Review in Admin Directory.',
      'deletion_request',
      '/admin',
      v_uid::text,
      false,
      timezone('utc'::text, now())
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'pending_approval',
    'message', 'Your account deletion request has been submitted for Admin/Staff approval.'
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.request_account_deletion(text) TO authenticated;

-- Also route delete_own_account() to request_account_deletion() so users cannot bypass admin approval
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN public.request_account_deletion('User requested account deletion from profile settings');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- Allow user to cancel their own pending deletion request before admin approval
CREATE OR REPLACE FUNCTION public.cancel_account_deletion_request()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := (SELECT auth.uid());
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.profiles
  SET deletion_requested = false,
      deletion_request_status = 'none',
      deletion_request_reason = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  RETURN jsonb_build_object('success', true, 'status', 'none');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.cancel_account_deletion_request() TO authenticated;

-- 4. Admin/Staff Resolve Account Deletion Request RPC (Approve -> Hard Delete, Archive, or Reject)
CREATE OR REPLACE FUNCTION public.admin_resolve_deletion_request(
  target_user_id uuid,
  decision text,
  admin_note text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_decision text := LOWER(BTRIM(COALESCE(decision, '')));
  v_note text := COALESCE(NULLIF(BTRIM(admin_note), ''), 'Processed by administration');
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  IF v_decision = 'approve' OR v_decision = 'hard_delete' THEN
    RETURN public.admin_delete_or_archive_user(target_user_id, 'hard_delete', 'Approved account deletion request: ' || v_note);
  ELSIF v_decision = 'archive' THEN
    RETURN public.admin_delete_or_archive_user(target_user_id, 'archive', 'Archived via deletion request review: ' || v_note);
  ELSIF v_decision = 'reject' THEN
    UPDATE public.profiles
    SET deletion_requested = false,
        deletion_request_status = 'rejected',
        updated_at = timezone('utc'::text, now())
    WHERE id = target_user_id;

    INSERT INTO public.notifications (
      user_id, title, body, type, screen, resource_id, is_read, created_at
    ) VALUES (
      target_user_id,
      'Account Deletion Request Reviewed',
      'Your account deletion request was declined by administration: ' || v_note,
      'system',
      '/profile',
      target_user_id::text,
      false,
      timezone('utc'::text, now())
    );

    PERFORM private.log_admin_action(
      'reject_deletion_request',
      'profile',
      target_user_id::text,
      jsonb_build_object('decision', 'reject', 'note', v_note)
    );

    RETURN jsonb_build_object('success', true, 'status', 'rejected');
  ELSE
    RAISE EXCEPTION 'Invalid decision "%". Use approve, archive, or reject.', decision;
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_deletion_request(uuid, text, text) TO authenticated;

-- 5. Mutual-Consent Live Donor-to-Receiver Location Tracking RPC
CREATE OR REPLACE FUNCTION public.manage_offer_location_tracking(
  p_request_id uuid,
  p_offer_id text,
  p_action text,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_eta_minutes integer DEFAULT NULL,
  p_distance_km double precision DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_req public.blood_requests%ROWTYPE;
  v_offers jsonb;
  v_new_offers jsonb := '[]'::jsonb;
  v_timeline jsonb;
  v_elem jsonb;
  v_found boolean := false;
  v_donor_id text;
  v_donor_name text;
  v_offer_status text;
  v_tracking_status text;
  v_act text := LOWER(BTRIM(COALESCE(p_action, '')));
  v_is_staff boolean := (SELECT private.is_staff());
  v_now text := timezone('utc'::text, now())::text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_req
  FROM public.blood_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Blood request not found';
  END IF;

  v_offers := COALESCE(v_req.offers, '[]'::jsonb);
  v_timeline := COALESCE(v_req.timeline, '[]'::jsonb);

  FOR v_elem IN SELECT * FROM jsonb_array_elements(v_offers)
  LOOP
    IF (v_elem->>'id') = p_offer_id OR (v_elem->>'donorId') = p_offer_id THEN
      v_found := true;
      v_donor_id := COALESCE(v_elem->>'donorId', '');
      v_donor_name := COALESCE(v_elem->>'donorName', 'Volunteer Donor');
      v_offer_status := LOWER(COALESCE(v_elem->>'status', 'pending'));

      IF v_offer_status <> 'accepted' THEN
        RAISE EXCEPTION 'Location tracking is only available after the donor offer is accepted.';
      END IF;

      IF v_act = 'request_tracking' THEN
        IF v_req.requester_user_id <> v_uid AND NOT v_is_staff THEN
          RAISE EXCEPTION 'Only the patient requester or staff can request live location tracking.';
        END IF;
        v_tracking_status := 'requested';
        v_elem := v_elem || jsonb_build_object(
          'locationTrackingStatus', 'requested',
          'locationTrackingRequestedAt', v_now
        );
        v_timeline := v_timeline || jsonb_build_array(
          jsonb_build_object(
            'action', 'location_tracking_requested',
            'by', 'Requester',
            'note', 'Requested live location tracking from ' || v_donor_name,
            'time', v_now
          )
        );
        IF v_donor_id <> '' THEN
          INSERT INTO public.notifications (
            user_id, title, body, type, screen, resource_id, is_read, created_at
          ) VALUES (
            v_donor_id::uuid,
            'Live Location Tracking Requested',
            'The patient attendant at ' || COALESCE(v_req.hospital_name, 'the hospital') || ' requested to track your live route. Open the request to accept & share your location.',
            'location_tracking_request',
            '/request-details',
            p_request_id::text,
            false,
            timezone('utc'::text, now())
          );
        END IF;

      ELSIF v_act = 'accept_tracking' THEN
        IF v_donor_id <> v_uid::text AND NOT v_is_staff THEN
          RAISE EXCEPTION 'Only the accepted donor can consent to share their live location.';
        END IF;
        v_tracking_status := 'active';
        v_elem := v_elem || jsonb_build_object(
          'locationTrackingStatus', 'active',
          'locationTrackingAcceptedAt', v_now,
          'donorLocationUpdatedAt', v_now
        );
        IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
          v_elem := v_elem || jsonb_build_object(
            'donorLatitude', p_latitude,
            'donorLongitude', p_longitude
          );
        END IF;
        IF p_eta_minutes IS NOT NULL THEN
          v_elem := v_elem || jsonb_build_object('donorEtaMinutes', p_eta_minutes);
        END IF;
        IF p_distance_km IS NOT NULL THEN
          v_elem := v_elem || jsonb_build_object('donorDistanceKm', ROUND(p_distance_km::numeric, 2));
        END IF;

        v_timeline := v_timeline || jsonb_build_array(
          jsonb_build_object(
            'action', 'location_tracking_accepted',
            'by', v_donor_name,
            'note', v_donor_name || ' started sharing live route to hospital',
            'time', v_now
          )
        );
        IF v_req.requester_user_id IS NOT NULL THEN
          INSERT INTO public.notifications (
            user_id, title, body, type, screen, resource_id, is_read, created_at
          ) VALUES (
            v_req.requester_user_id,
            'Donor Live Location Active',
            v_donor_name || ' accepted location tracking! You can now track their live route to ' || COALESCE(v_req.hospital_name, 'the hospital') || '.',
            'location_tracking_active',
            '/request-details',
            p_request_id::text,
            false,
            timezone('utc'::text, now())
          );
        END IF;

      ELSIF v_act = 'update_location' THEN
        IF v_donor_id <> v_uid::text AND NOT v_is_staff THEN
          RAISE EXCEPTION 'Only the accepted donor can update their live location.';
        END IF;
        v_tracking_status := 'active';
        v_elem := v_elem || jsonb_build_object(
          'locationTrackingStatus', 'active',
          'donorLocationUpdatedAt', v_now
        );
        IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
          v_elem := v_elem || jsonb_build_object(
            'donorLatitude', p_latitude,
            'donorLongitude', p_longitude
          );
        END IF;
        IF p_eta_minutes IS NOT NULL THEN
          v_elem := v_elem || jsonb_build_object('donorEtaMinutes', p_eta_minutes);
        END IF;
        IF p_distance_km IS NOT NULL THEN
          v_elem := v_elem || jsonb_build_object('donorDistanceKm', ROUND(p_distance_km::numeric, 2));
        END IF;

      ELSIF v_act = 'decline_tracking' THEN
        IF v_donor_id <> v_uid::text AND NOT v_is_staff THEN
          RAISE EXCEPTION 'Only the donor can decline location tracking.';
        END IF;
        v_tracking_status := 'declined';
        v_elem := (v_elem - 'donorLatitude' - 'donorLongitude') || jsonb_build_object(
          'locationTrackingStatus', 'declined',
          'donorLocationUpdatedAt', v_now
        );
        IF v_req.requester_user_id IS NOT NULL THEN
          INSERT INTO public.notifications (
            user_id, title, body, type, screen, resource_id, is_read, created_at
          ) VALUES (
            v_req.requester_user_id,
            'Location Tracking Declined',
            v_donor_name || ' prefers to coordinate by phone call rather than live GPS tracking.',
            'system',
            '/request-details',
            p_request_id::text,
            false,
            timezone('utc'::text, now())
          );
        END IF;

      ELSIF v_act = 'stop_tracking' THEN
        IF v_donor_id <> v_uid::text AND v_req.requester_user_id <> v_uid AND NOT v_is_staff THEN
          RAISE EXCEPTION 'Unauthorized to stop location tracking.';
        END IF;
        v_tracking_status := 'stopped';
        v_elem := (v_elem - 'donorLatitude' - 'donorLongitude') || jsonb_build_object(
          'locationTrackingStatus', 'stopped',
          'donorLocationUpdatedAt', v_now
        );
      ELSE
        RAISE EXCEPTION 'Unsupported tracking action: %', p_action;
      END IF;
    END IF;

    v_new_offers := v_new_offers || jsonb_build_array(v_elem);
  END LOOP;

  IF NOT v_found THEN
    RAISE EXCEPTION 'Accepted donor offer not found.';
  END IF;

  UPDATE public.blood_requests
  SET offers = v_new_offers,
      timeline = v_timeline,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', p_request_id,
    'offer_id', p_offer_id,
    'location_tracking_status', v_tracking_status
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.manage_offer_location_tracking(uuid, text, text, double precision, double precision, integer, double precision) TO authenticated;

COMMIT;

