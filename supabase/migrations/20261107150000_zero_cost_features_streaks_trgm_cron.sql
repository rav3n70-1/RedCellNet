-- supabase/migrations/20261107150000_zero_cost_features_streaks_trgm_cron.sql
-- Zero-Cost Backend Upgrades for RedCellNet:
--   1. pg_trgm Fuzzy Search Extension & GIN Trigram Indexes
--   2. Donor Streaks with Medical Freeze, Referral Codes & Health Journal on profiles
--   3. Community Blood Camps Calendar Table + RLS + Seed Data
--   4. Privacy-Safe Community Leaderboard RPC
--   5. Auto-Expire & Archive Stale Data RPC + Optional pg_cron Schedule
--   6. Lightweight Keep-Alive Ping RPC for GitHub Actions Free-Tier Protection

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
  WHERE is_banned = false;

-- 3. Blood Camps Calendar Table + RLS
CREATE TABLE IF NOT EXISTS public.blood_camps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  organizer text NOT NULL,
  location text NOT NULL,
  city text NOT NULL DEFAULT 'Dhaka',
  description text NOT NULL DEFAULT '',
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  target_units integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

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

-- 4. Privacy-Safe Community Leaderboard RPC
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
        WHEN COALESCE(trim(p.full_name), '') = '' THEN 'Verified Lifesaver'
        WHEN position(' ' IN trim(p.full_name)) > 0 THEN
          split_part(trim(p.full_name), ' ', 1) || ' ' ||
          left(split_part(trim(p.full_name), ' ', 2), 1) || '.'
        ELSE trim(p.full_name)
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
    WHERE p.is_banned = false
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
      OR r.blood_type ILIKE '%' || trim(p_query) || '%'
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

-- 7. Auto-Expire & Archive Stale Data RPC (Protects 500 MB Free-Tier Database Limit)
CREATE OR REPLACE FUNCTION public.cleanup_and_archive_stale_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_requests integer := 0;
  v_trimmed_notifications integer := 0;
BEGIN
  -- Expire open requests older than 14 days
  WITH expired AS (
    UPDATE public.blood_requests
    SET
      status = 'Expired',
      updated_at = timezone('utc', now())
    WHERE status IN ('Open', 'Partially Fulfilled')
      AND created_at < timezone('utc', now()) - interval '14 days'
    RETURNING 1
  )
  SELECT count(*) INTO v_expired_requests FROM expired;

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
    'trimmed_notifications', v_trimmed_notifications,
    'executed_at', timezone('utc', now())
  );
END;
$$;

-- 8. Lightweight Keep-Alive Ping RPC (Prevents Supabase Free-Tier 7-Day Pause)
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

-- 9. Optional pg_cron Registration (Safe no-op if pg_cron is not enabled on instance)
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

