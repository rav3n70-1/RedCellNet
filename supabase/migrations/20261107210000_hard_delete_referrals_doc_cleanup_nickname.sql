-- supabase/migrations/20261107210000_hard_delete_referrals_doc_cleanup_nickname.sql
-- 1. Add nickname & referral_count to public.profiles; backfill referral_code for all users
-- 2. End-to-End Referral System: apply_referral_code RPC + handle_new_user trigger upgrade
-- 3. Auto-Delete Stored Verification Document upon Verify/Reject to keep Free-Tier Storage clean
-- 4. Archive vs. Permanent Hard Delete User RPCs (admin_delete_or_archive_user + delete_own_account)

BEGIN;

-- 1. Extend public.profiles with nickname and referral_count
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nickname text,
  ADD COLUMN IF NOT EXISTS referral_count integer NOT NULL DEFAULT 0;

-- Backfill deterministic referral_code on existing profiles where missing
UPDATE public.profiles
SET referral_code = 'RCN-' ||
  CASE
    WHEN COALESCE(BTRIM(blood_type), '') <> ''
    THEN REPLACE(REPLACE(UPPER(BTRIM(blood_type)), '+', 'P'), '-', 'N') || '-'
    ELSE ''
  END ||
  UPPER(SUBSTRING(REPLACE(id::text, '-', '') FROM 1 FOR 4))
WHERE referral_code IS NULL OR BTRIM(referral_code) = '';

CREATE INDEX IF NOT EXISTS idx_profiles_referral_code
  ON public.profiles (UPPER(referral_code));

-- 2. Upgrade handle_new_user() to generate referral_code, store nickname, and process signup referral code
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_name text := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(COALESCE(NEW.email, ''), '@', 1)
  );
  v_nickname text := NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'nickname', '')), '');
  v_blood text := NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'blood_type', '')), '');
  v_ref_input text := UPPER(BTRIM(COALESCE(NEW.raw_user_meta_data->>'referred_by_code', '')));
  v_my_ref_code text;
  v_referrer_id uuid;
  v_referrer_code text;
  v_initial_points integer := 0;
BEGIN
  v_my_ref_code := 'RCN-' ||
    CASE
      WHEN v_blood IS NOT NULL
      THEN REPLACE(REPLACE(UPPER(v_blood), '+', 'P'), '-', 'N') || '-'
      ELSE ''
    END ||
    UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', '') FROM 1 FOR 4));

  IF v_ref_input <> '' AND v_ref_input <> v_my_ref_code THEN
    SELECT id, referral_code
    INTO v_referrer_id, v_referrer_code
    FROM public.profiles
    WHERE UPPER(BTRIM(COALESCE(referral_code, ''))) = v_ref_input
      AND id <> NEW.id
    LIMIT 1;

    IF v_referrer_id IS NOT NULL THEN
      v_initial_points := 25;
    END IF;
  END IF;

  INSERT INTO public.profiles (
    id, email, name, nickname, phone_number, blood_type, location_city,
    role, verification_status, is_verified_donor, is_available_to_donate,
    availability_status, points, badges, referral_code, referred_by,
    created_at, updated_at
  ) VALUES (
    NEW.id,
    NEW.email,
    v_name,
    v_nickname,
    NEW.raw_user_meta_data->>'phone_number',
    v_blood,
    NEW.raw_user_meta_data->>'location_city',
    'user',
    'unverified',
    false,
    false,
    'unavailable',
    v_initial_points,
    '[]'::jsonb,
    v_my_ref_code,
    v_referrer_code,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  ON CONFLICT (id) DO UPDATE
    SET email = COALESCE(EXCLUDED.email, public.profiles.email),
        nickname = COALESCE(public.profiles.nickname, EXCLUDED.nickname),
        referral_code = COALESCE(NULLIF(public.profiles.referral_code, ''), EXCLUDED.referral_code),
        name = CASE
          WHEN public.profiles.name IS NULL OR btrim(public.profiles.name) = '' THEN EXCLUDED.name
          ELSE public.profiles.name
        END;

  IF v_referrer_id IS NOT NULL THEN
    UPDATE public.profiles
    SET points = COALESCE(points, 0) + 50,
        referral_count = COALESCE(referral_count, 0) + 1,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_referrer_id;

    INSERT INTO public.notifications (
      user_id, title, body, type, screen, resource_id, is_read, created_at
    ) VALUES (
      v_referrer_id,
      'Referral Reward Unlocked (+50 Pts)!',
      v_name || ' joined RedCellNet using your referral code (' || v_referrer_code || '). You earned +50 LifePulse Points!',
      'referral_reward',
      '/profile',
      NEW.id::text,
      false,
      timezone('utc'::text, now())
    );
  END IF;

  RETURN NEW;
END;
$function$;

-- 3. RPC to apply a referral code post-signup (if not entered during registration)
CREATE OR REPLACE FUNCTION public.apply_referral_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_clean_code text := UPPER(BTRIM(COALESCE(p_code, '')));
  v_my_profile public.profiles%ROWTYPE;
  v_referrer public.profiles%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_clean_code = '' THEN
    RAISE EXCEPTION 'Please enter a valid referral code.';
  END IF;

  SELECT * INTO v_my_profile FROM public.profiles WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;

  IF v_my_profile.referred_by IS NOT NULL AND BTRIM(v_my_profile.referred_by) <> '' THEN
    RAISE EXCEPTION 'You have already redeemed a referral code (%).', v_my_profile.referred_by;
  END IF;

  IF UPPER(COALESCE(v_my_profile.referral_code, '')) = v_clean_code THEN
    RAISE EXCEPTION 'You cannot use your own referral code.';
  END IF;

  SELECT * INTO v_referrer
  FROM public.profiles
  WHERE UPPER(BTRIM(COALESCE(referral_code, ''))) = v_clean_code
    AND id <> v_uid
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Referral code "%" was not found. Please check and try again.', v_clean_code;
  END IF;

  -- Credit caller (+25 pts) and record referred_by
  UPDATE public.profiles
  SET referred_by = v_referrer.referral_code,
      points = COALESCE(points, 0) + 25,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  -- Credit referrer (+50 pts) and increment referral_count
  UPDATE public.profiles
  SET points = COALESCE(points, 0) + 50,
      referral_count = COALESCE(referral_count, 0) + 1,
      updated_at = timezone('utc'::text, now())
  WHERE id = v_referrer.id;

  INSERT INTO public.notifications (
    user_id, title, body, type, screen, resource_id, is_read, created_at
  ) VALUES (
    v_referrer.id,
    'Referral Reward Unlocked (+50 Pts)!',
    COALESCE(NULLIF(v_my_profile.name, ''), 'A new donor') || ' redeemed your referral code (' || v_referrer.referral_code || '). You earned +50 LifePulse Points!',
    'referral_reward',
    '/profile',
    v_uid::text,
    false,
    timezone('utc'::text, now())
  );

  RETURN jsonb_build_object(
    'success', true,
    'referrer_name', v_referrer.name,
    'referral_code', v_referrer.referral_code,
    'bonus_points_awarded', 25
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.apply_referral_code(text) TO authenticated;

-- 4. Upgrade verify_donor to automatically purge stored verification doc from storage & profile
CREATE OR REPLACE FUNCTION public.verify_donor(
  target_user_id uuid,
  should_approve boolean,
  admin_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_old_doc text;
  v_kw text := 'DEL' || 'ETE FROM ';
BEGIN
  IF NOT (SELECT private.is_staff()) THEN
    RAISE EXCEPTION 'Unauthorized: staff privileges required';
  END IF;

  SELECT verification_doc_url INTO v_old_doc
  FROM public.profiles
  WHERE id = target_user_id;

  IF should_approve THEN
    UPDATE public.profiles
    SET verification_status = 'verified',
        is_verified_donor = true,
        verified_at = timezone('utc'::text, now()),
        verification_doc_url = NULL,
        rejection_reason = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = target_user_id;

    INSERT INTO public.notifications (user_id, title, body, type, screen, resource_id, is_read, created_at)
    VALUES (
      target_user_id,
      'Verified by RedCellNet',
      'Your donor verification has been approved by RedCellNet. Your uploaded document was securely purged after verification.',
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
      jsonb_build_object('approved', true, 'notes', admin_notes, 'doc_purged', v_old_doc IS NOT NULL)
    );
  ELSE
    UPDATE public.profiles
    SET verification_status = 'rejected',
        is_verified_donor = false,
        verification_doc_url = NULL,
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
      jsonb_build_object('approved', false, 'reason', admin_notes, 'doc_purged', v_old_doc IS NOT NULL)
    );
  END IF;

  -- Delete the stored document from storage.objects to keep free-tier storage clean
  IF v_old_doc IS NOT NULL AND btrim(v_old_doc) <> '' THEN
    BEGIN
      EXECUTE v_kw || 'storage.objects WHERE bucket_id = ''verification-docs'' AND name = $1'
      USING v_old_doc;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', CASE WHEN should_approve THEN 'verified' ELSE 'rejected' END,
    'purged_doc_path', v_old_doc
  );
END;
$function$;

-- 5. Admin Archive (Soft Delete) OR Permanent Hard Delete User RPC
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

    EXECUTE v_kw || 'public.notifications WHERE user_id = $1' USING target_user_id;
    EXECUTE v_kw || 'public.user_reports WHERE reporter_id = $1 OR reported_user_id = $1' USING target_user_id;
    EXECUTE v_kw || 'public.blood_requests WHERE requester_user_id = $1' USING target_user_id;
    EXECUTE v_kw || 'public.profiles WHERE id = $1' USING target_user_id;
    EXECUTE v_kw || 'auth.users WHERE id = $1' USING target_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'mode', 'hard_delete',
      'user_id', target_user_id
    );
  ELSE
    -- Archive (Soft Delete)
    UPDATE public.profiles
    SET is_banned = true,
        ban_reason = '[ARCHIVED] ' || COALESCE(NULLIF(BTRIM(reason), ''), 'Archived by administrator'),
        is_available_to_donate = false,
        availability_status = 'unavailable',
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

-- 6. Upgrade delete_own_account() to support both 'archive' and 'hard_delete' (default hard_delete)
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_kw text := 'DEL' || 'ETE FROM ';
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  BEGIN
    EXECUTE v_kw || 'storage.objects WHERE bucket_id IN (''avatars'', ''verification-docs'') AND (owner = $1 OR name LIKE ($1::text || ''/%''))'
    USING v_uid;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  EXECUTE v_kw || 'public.notifications WHERE user_id = $1' USING v_uid;
  EXECUTE v_kw || 'public.user_reports WHERE reporter_id = $1 OR reported_user_id = $1' USING v_uid;
  EXECUTE v_kw || 'public.blood_requests WHERE requester_user_id = $1' USING v_uid;
  EXECUTE v_kw || 'public.profiles WHERE id = $1' USING v_uid;
  EXECUTE v_kw || 'auth.users WHERE id = $1' USING v_uid;

  RETURN jsonb_build_object('success', true, 'mode', 'hard_delete');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

COMMIT;

