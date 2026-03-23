-- ============================================================================
-- FITFUSION DATABASE SCHEMA
-- Target: Supabase (PostgreSQL)
-- Reference: DATABASE.md v1.0
--
-- INSTRUCTIONS:
--   1. Open your Supabase project dashboard
--   2. Go to SQL Editor (left sidebar)
--   3. Paste this entire file into the editor
--   4. Click "Run"
--   5. Verify all 6 tables appear under Table Editor
--
-- This script creates all tables, indexes, constraints, triggers, and
-- Row-Level Security policies for the FitFusion database.
-- ============================================================================


-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================
-- gen_random_uuid() is available by default on Supabase (pgcrypto enabled).
-- No additional extensions are required.


-- ============================================================================
-- 2. TABLE: public.users
-- ============================================================================
-- Core user profile table. Linked 1:1 with auth.users by UUID.
-- Supabase Auth owns password storage and OTP logic.
-- This table holds only the public-facing profile.

CREATE TABLE IF NOT EXISTS public.users (
  id                 UUID          PRIMARY KEY,
  username           TEXT          NOT NULL,
  email              TEXT          NOT NULL UNIQUE,
  is_email_verified  BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Case-insensitive username uniqueness:
-- 'JOHNDOE', 'johndoe', and 'JohnDoe' all resolve to the same index entry.
CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_idx
  ON public.users (LOWER(username));

COMMENT ON TABLE public.users IS
  'Core user profile table. Linked 1:1 with auth.users by UUID.';
COMMENT ON COLUMN public.users.id IS
  'Same UUID as auth.users.id. Copied on sign-up.';
COMMENT ON COLUMN public.users.username IS
  'Display name. Case-insensitive uniqueness enforced via LOWER() unique index.';
COMMENT ON COLUMN public.users.email IS
  'Player email. Mirrors auth.users.email. Updated on email change.';
COMMENT ON COLUMN public.users.is_email_verified IS
  'TRUE after successful OTP verification on sign-up. Reset to FALSE on email change.';


-- ============================================================================
-- 2.5 TABLE: public.admin_users
-- ============================================================================
-- Dedicated admin portal accounts. Independent from player users.

CREATE TABLE IF NOT EXISTS public.admin_users (
  id         UUID          PRIMARY KEY,
  email      TEXT          NOT NULL UNIQUE,
  role       TEXT          NOT NULL DEFAULT 'admin'
                           CHECK (role IN ('admin','superadmin')),
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.admin_users IS
  'Admin portal users. Independent from player users; no game data rows.';
COMMENT ON COLUMN public.admin_users.id IS
  'Same UUID as auth.users.id for the admin.';
COMMENT ON COLUMN public.admin_users.role IS
  'Admin role level: admin or superadmin.';


-- Auto-update updated_at on admin_users
CREATE OR REPLACE FUNCTION public.handle_admin_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_admin_users_updated ON public.admin_users;
CREATE TRIGGER on_admin_users_updated
  BEFORE UPDATE ON public.admin_users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_admin_users_updated_at();


-- ============================================================================
-- 3. TABLE: public.sessions
-- ============================================================================
-- One row per completed game session (win or loss).
-- Immutable once inserted — no updates or deletes by the player.
-- Sessions from forced exits (back/home button) are also recorded
-- with won=FALSE, lives_lost=3.

CREATE TABLE IF NOT EXISTS public.sessions (
  id                          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                     UUID            NOT NULL
                                              REFERENCES public.users(id) ON DELETE CASCADE,
  workout_type                TEXT            NOT NULL,
  won                         BOOLEAN         NOT NULL,
  total_reps                  INT             NOT NULL DEFAULT 0,
  total_reps_required         INT             NOT NULL DEFAULT 65,
  total_time_seconds          NUMERIC(10,4)   NOT NULL,
  rounds_completed            INT             NOT NULL DEFAULT 0,
  best_rep_interval_seconds   NUMERIC(10,4),
  avg_rep_interval_seconds    NUMERIC(10,4),
  lives_lost                  INT             NOT NULL DEFAULT 0,
  completed_at                TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

  -- Enum check: workout_type must be one of the 3 supported types
  CONSTRAINT sessions_workout_type_check
    CHECK (workout_type IN ('squats', 'jumping_jacks', 'side_crunches')),

  -- Range checks
  CONSTRAINT sessions_total_reps_range
    CHECK (total_reps >= 0 AND total_reps <= 65),

  CONSTRAINT sessions_rounds_range
    CHECK (rounds_completed >= 0 AND rounds_completed <= 10),

  CONSTRAINT sessions_lives_lost_range
    CHECK (lives_lost >= 0 AND lives_lost <= 3),

  CONSTRAINT sessions_time_positive
    CHECK (total_time_seconds > 0)
);

CREATE INDEX IF NOT EXISTS sessions_user_id_idx
  ON public.sessions (user_id);
CREATE INDEX IF NOT EXISTS sessions_workout_type_idx
  ON public.sessions (workout_type);
CREATE INDEX IF NOT EXISTS sessions_completed_at_idx
  ON public.sessions (completed_at DESC);

COMMENT ON TABLE public.sessions IS
  'One row per completed game session. Immutable once inserted.';
COMMENT ON COLUMN public.sessions.workout_type IS
  'squats | jumping_jacks | side_crunches';
COMMENT ON COLUMN public.sessions.total_reps_required IS
  'Always 65 for a full game. Stored for historical reference.';
COMMENT ON COLUMN public.sessions.best_rep_interval_seconds IS
  'Fastest single rep interval in seconds. NULL if fewer than 2 reps performed.';
COMMENT ON COLUMN public.sessions.avg_rep_interval_seconds IS
  'Mean rep interval in seconds. NULL if fewer than 2 reps performed.';


-- ============================================================================
-- 4. TABLE: public.user_stats
-- ============================================================================
-- One row per user. Pre-computed aggregate statistics.
-- Updated immediately after every session save.
-- Wide flat layout: 3 workout types x stat columns.
--
-- PB clear time: only from won sessions.
-- PB best interval: from any session with a valid interval.
-- Average clear time & average rep interval: computed at query time
--   from the sessions table (not stored here).

CREATE TABLE IF NOT EXISTS public.user_stats (
  user_id                            UUID            PRIMARY KEY
                                                     REFERENCES public.users(id) ON DELETE CASCADE,

  -- Lifetime aggregates (across all workout types)
  total_sessions                     INT             NOT NULL DEFAULT 0,
  total_reps                         INT             NOT NULL DEFAULT 0,
  total_rounds                       INT             NOT NULL DEFAULT 0,

  -- ── Squats ──
  squats_victories                   INT             NOT NULL DEFAULT 0,
  squats_defeats                     INT             NOT NULL DEFAULT 0,
  squats_rounds_completed            INT             NOT NULL DEFAULT 0,
  squats_reps_finished               INT             NOT NULL DEFAULT 0,
  squats_pb_clear_time_seconds       NUMERIC(10,4),
  squats_pb_best_interval_seconds    NUMERIC(10,4),

  -- ── Jumping Jacks ──
  jacks_victories                    INT             NOT NULL DEFAULT 0,
  jacks_defeats                      INT             NOT NULL DEFAULT 0,
  jacks_rounds_completed             INT             NOT NULL DEFAULT 0,
  jacks_reps_finished                INT             NOT NULL DEFAULT 0,
  jacks_pb_clear_time_seconds        NUMERIC(10,4),
  jacks_pb_best_interval_seconds     NUMERIC(10,4),

  -- ── Side Crunches ──
  crunches_victories                 INT             NOT NULL DEFAULT 0,
  crunches_defeats                   INT             NOT NULL DEFAULT 0,
  crunches_rounds_completed          INT             NOT NULL DEFAULT 0,
  crunches_reps_finished             INT             NOT NULL DEFAULT 0,
  crunches_pb_clear_time_seconds     NUMERIC(10,4),
  crunches_pb_best_interval_seconds  NUMERIC(10,4),

  updated_at                         TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_stats IS
  'One row per user. Pre-computed aggregate stats updated on every session save.';
COMMENT ON COLUMN public.user_stats.total_sessions IS
  'Lifetime count of all completed sessions (wins + losses).';
COMMENT ON COLUMN public.user_stats.squats_pb_clear_time_seconds IS
  'PB clear time for squats. Only set from won sessions. NULL if no win yet.';
COMMENT ON COLUMN public.user_stats.squats_pb_best_interval_seconds IS
  'PB best single rep interval for squats. From any session. NULL if never recorded.';
COMMENT ON COLUMN public.user_stats.jacks_pb_clear_time_seconds IS
  'PB clear time for jumping jacks. Only set from won sessions. NULL if no win yet.';
COMMENT ON COLUMN public.user_stats.jacks_pb_best_interval_seconds IS
  'PB best single rep interval for jumping jacks. From any session. NULL if never recorded.';
COMMENT ON COLUMN public.user_stats.crunches_pb_clear_time_seconds IS
  'PB clear time for side crunches. Only set from won sessions. NULL if no win yet.';
COMMENT ON COLUMN public.user_stats.crunches_pb_best_interval_seconds IS
  'PB best single rep interval for side crunches. From any session. NULL if never recorded.';


-- ============================================================================
-- 5. TABLE: public.user_achievements
-- ============================================================================
-- One row per user. 13 achievements, each with a boolean flag and
-- an unlock timestamp.
-- Achievements are one-way: once TRUE, never reverted unless
-- "Reset Game Data" is triggered.

CREATE TABLE IF NOT EXISTS public.user_achievements (
  user_id                              UUID          PRIMARY KEY
                                                     REFERENCES public.users(id) ON DELETE CASCADE,

  -- #1  First Blood: Complete your first session (win or lose)
  first_blood                          BOOLEAN       NOT NULL DEFAULT FALSE,
  first_blood_unlocked_at              TIMESTAMPTZ,

  -- #2  Iron Will: Complete 30 total sessions
  iron_will                            BOOLEAN       NOT NULL DEFAULT FALSE,
  iron_will_unlocked_at                TIMESTAMPTZ,

  -- #3  Blood Pumper: Reach 300 lifetime reps
  blood_pumper                         BOOLEAN       NOT NULL DEFAULT FALSE,
  blood_pumper_unlocked_at             TIMESTAMPTZ,

  -- #4  Survivor: Complete 100 total rounds
  survivor                             BOOLEAN       NOT NULL DEFAULT FALSE,
  survivor_unlocked_at                 TIMESTAMPTZ,

  -- #5  Halfway Hero: Reach 5 rounds in a single session
  halfway_hero                         BOOLEAN       NOT NULL DEFAULT FALSE,
  halfway_hero_unlocked_at             TIMESTAMPTZ,

  -- #6  Monster Hunter: Win a full 10-round session
  monster_hunter                       BOOLEAN       NOT NULL DEFAULT FALSE,
  monster_hunter_unlocked_at           TIMESTAMPTZ,

  -- #7  Triple Crown: Win at least one session in all 3 workout types
  triple_crown                         BOOLEAN       NOT NULL DEFAULT FALSE,
  triple_crown_unlocked_at             TIMESTAMPTZ,

  -- #8  Speed Demon: Achieve a best rep interval under 1.8 seconds
  speed_demon                          BOOLEAN       NOT NULL DEFAULT FALSE,
  speed_demon_unlocked_at              TIMESTAMPTZ,

  -- #9  Blinding Steel: Win with an average rep interval under 2.3 seconds
  blinding_steel                       BOOLEAN       NOT NULL DEFAULT FALSE,
  blinding_steel_unlocked_at           TIMESTAMPTZ,

  -- #10 Record Breaker: Beat your personal best clear time
  record_breaker                       BOOLEAN       NOT NULL DEFAULT FALSE,
  record_breaker_unlocked_at           TIMESTAMPTZ,

  -- #11 Sharper Than Yesterday: Beat your personal best rep interval
  sharper_than_yesterday               BOOLEAN       NOT NULL DEFAULT FALSE,
  sharper_than_yesterday_unlocked_at   TIMESTAMPTZ,

  -- #12 Untouchable: Win with 0 lives lost
  untouchable                          BOOLEAN       NOT NULL DEFAULT FALSE,
  untouchable_unlocked_at              TIMESTAMPTZ,

  -- #13 Last Stand: Win with exactly 2 lives lost
  last_stand                           BOOLEAN       NOT NULL DEFAULT FALSE,
  last_stand_unlocked_at               TIMESTAMPTZ
);

COMMENT ON TABLE public.user_achievements IS
  'One row per user. 13 achievements with boolean flags and unlock timestamps.';


-- ============================================================================
-- 6. TABLE: public.leaderboard_entries
-- ============================================================================
-- Top 10 per metric per workout type = 9 independent boards.
-- One entry per user per board (UNIQUE constraint).
-- username is denormalized for fast leaderboard reads.
-- All 3 metrics are "lower is better" (time in seconds).

CREATE TABLE IF NOT EXISTS public.leaderboard_entries (
  id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_type   TEXT            NOT NULL,
  metric         TEXT            NOT NULL,
  user_id        UUID            NOT NULL
                                 REFERENCES public.users(id) ON DELETE CASCADE,
  username       TEXT            NOT NULL,
  value          NUMERIC(10,4)   NOT NULL,
  session_id     UUID            NOT NULL
                                 REFERENCES public.sessions(id) ON DELETE CASCADE,
  rank           INT             NOT NULL,
  recorded_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

  -- One entry per user per board
  CONSTRAINT leaderboard_entries_user_board_unique
    UNIQUE (workout_type, metric, user_id),

  -- Enum checks
  CONSTRAINT leaderboard_entries_workout_type_check
    CHECK (workout_type IN ('squats', 'jumping_jacks', 'side_crunches')),

  CONSTRAINT leaderboard_entries_metric_check
    CHECK (metric IN ('clear_time', 'best_rep_interval', 'avg_rep_interval')),

  CONSTRAINT leaderboard_entries_rank_range
    CHECK (rank >= 1 AND rank <= 10)
);

-- Composite index for fast board lookups (sorted by rank)
CREATE INDEX IF NOT EXISTS leaderboard_entries_board_idx
  ON public.leaderboard_entries (workout_type, metric, rank ASC);

COMMENT ON TABLE public.leaderboard_entries IS
  'Top 10 per metric per workout type. 9 boards total. Materialized.';
COMMENT ON COLUMN public.leaderboard_entries.username IS
  'Denormalized from users.username for fast leaderboard reads. Synced on username change.';
COMMENT ON COLUMN public.leaderboard_entries.value IS
  'Metric value in seconds. All 3 metrics are lower-is-better.';
COMMENT ON COLUMN public.leaderboard_entries.session_id IS
  'The specific session that produced this score. Cascade-deleted if session is removed.';


-- ============================================================================
-- 7. TRIGGER FUNCTION: handle_new_user()
-- ============================================================================
-- Auto-creates companion rows in user_stats and user_achievements
-- when a new public.users row is inserted.
-- This runs AFTER the public.users INSERT so the FK references are valid.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_stats (user_id)
    VALUES (NEW.id);

  INSERT INTO public.user_achievements (user_id)
    VALUES (NEW.id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_user_created ON public.users;
CREATE TRIGGER on_user_created
  AFTER INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

COMMENT ON FUNCTION public.handle_new_user() IS
  'Auto-creates user_stats and user_achievements rows when a new public.users row is inserted.';


-- ============================================================================
-- 8. TRIGGER FUNCTION: handle_auth_user_created()
-- ============================================================================
-- Routes auth.users sign-ups:
-- - If app_metadata.role is 'admin' or 'superadmin' => insert into admin_users
-- - Else => insert into public.users (cascades to stats/achievements)
-- Username comes from raw_user_meta_data.username or defaults to user_<uuid_prefix>.

CREATE OR REPLACE FUNCTION public.handle_auth_user_created()
RETURNS TRIGGER AS $$
DECLARE
  _role TEXT;
BEGIN
  _role := NEW.raw_app_meta_data->>'role';

  IF _role = 'admin' OR _role = 'superadmin' THEN
    INSERT INTO public.admin_users (id, email, role, created_at, updated_at)
      VALUES (
        NEW.id,
        NEW.email,
        COALESCE(_role, 'admin'),
        NOW(),
        NOW()
      );
  ELSE
    INSERT INTO public.users (id, email, username, is_email_verified, created_at, updated_at)
      VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || LEFT(NEW.id::text, 8)),
        COALESCE(NEW.email_confirmed_at IS NOT NULL, FALSE),
        NOW(),
        NOW()
      );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user_created();

COMMENT ON FUNCTION public.handle_auth_user_created() IS
  'Routes auth.users sign-ups: admins -> admin_users, players -> public.users (cascades to stats/achievements).';


-- ============================================================================
-- 9. TRIGGER FUNCTION: handle_username_change()
-- ============================================================================
-- Syncs the denormalized username column in leaderboard_entries
-- whenever a user updates their username in public.users.

CREATE OR REPLACE FUNCTION public.handle_username_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.username IS DISTINCT FROM NEW.username THEN
    UPDATE public.leaderboard_entries
      SET username = NEW.username
      WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_username_changed ON public.users;
CREATE TRIGGER on_username_changed
  AFTER UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_username_change();

COMMENT ON FUNCTION public.handle_username_change() IS
  'Syncs denormalized username in leaderboard_entries when a user changes their username.';


-- ============================================================================
-- 10. TRIGGER FUNCTION: Auto-update updated_at on public.users
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_users_updated ON public.users;
CREATE TRIGGER on_users_updated
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_users_updated_at();


-- ============================================================================
-- 11. TRIGGER FUNCTION: Auto-update updated_at on public.user_stats
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_user_stats_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_user_stats_updated ON public.user_stats;
CREATE TRIGGER on_user_stats_updated
  BEFORE UPDATE ON public.user_stats
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_stats_updated_at();


-- ============================================================================
-- 12. ROW LEVEL SECURITY (RLS)
-- ============================================================================
-- RLS is enabled on all 6 tables.
-- Player policies: scoped to auth.uid() = user's own UUID.
-- Admin operations: use the service_role key which bypasses RLS entirely.

-- ── Enable RLS ──
ALTER TABLE public.users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stats          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users         ENABLE ROW LEVEL SECURITY;


-- ────────────────────────────────────────────────────────────────────────────
-- 12a. public.users
-- ────────────────────────────────────────────────────────────────────────────

-- Players can read their own profile
CREATE POLICY "users: select own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- Players can update their own profile (username, email changes)
CREATE POLICY "users: update own"
  ON public.users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Insert is handled by the auth trigger (SECURITY DEFINER bypasses RLS),
-- but we also allow it for the auth.uid() = id case as a safety net.
CREATE POLICY "users: insert own"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);


-- ────────────────────────────────────────────────────────────────────────────
-- 12b. public.sessions
-- ────────────────────────────────────────────────────────────────────────────

-- Players can read their own sessions
CREATE POLICY "sessions: select own"
  ON public.sessions FOR SELECT
  USING (auth.uid() = user_id);

-- Players can insert their own sessions
CREATE POLICY "sessions: insert own"
  ON public.sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- No UPDATE or DELETE policies for players. Sessions are immutable.


-- ────────────────────────────────────────────────────────────────────────────
-- 12c. public.user_stats
-- ────────────────────────────────────────────────────────────────────────────

-- Players can read their own stats
CREATE POLICY "user_stats: select own"
  ON public.user_stats FOR SELECT
  USING (auth.uid() = user_id);

-- Players can update their own stats (app updates after session save)
CREATE POLICY "user_stats: update own"
  ON public.user_stats FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Insert handled by trigger (SECURITY DEFINER), safety net for auth.uid()
CREATE POLICY "user_stats: insert own"
  ON public.user_stats FOR INSERT
  WITH CHECK (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 12d. public.user_achievements
-- ────────────────────────────────────────────────────────────────────────────

-- Players can read their own achievements
CREATE POLICY "user_achievements: select own"
  ON public.user_achievements FOR SELECT
  USING (auth.uid() = user_id);

-- Players can update their own achievements (app updates after session)
CREATE POLICY "user_achievements: update own"
  ON public.user_achievements FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Insert handled by trigger, safety net
CREATE POLICY "user_achievements: insert own"
  ON public.user_achievements FOR INSERT
  WITH CHECK (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 12e. public.leaderboard_entries
-- ────────────────────────────────────────────────────────────────────────────

-- Everyone authenticated can read all leaderboard entries (public leaderboard)
CREATE POLICY "leaderboard_entries: select all authenticated"
  ON public.leaderboard_entries FOR SELECT
  USING (auth.role() = 'authenticated');

-- Players can insert their own entries
CREATE POLICY "leaderboard_entries: insert own"
  ON public.leaderboard_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Players can update their own entries (when they beat their own score)
CREATE POLICY "leaderboard_entries: update own"
  ON public.leaderboard_entries FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Players can delete their own entries (for eviction during re-ranking)
CREATE POLICY "leaderboard_entries: delete own"
  ON public.leaderboard_entries FOR DELETE
  USING (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 12f. public.admin_users
-- ────────────────────────────────────────────────────────────────────────────

-- Admin can read their own row (auth.uid matches id)
CREATE POLICY "admin_users: select own"
  ON public.admin_users FOR SELECT
  USING (auth.uid() = id);

-- Admin can update their own row (email sync)
CREATE POLICY "admin_users: update own"
  ON public.admin_users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- ============================================================================
-- 13. ADMIN / SERVICE ROLE NOTE
-- ============================================================================
-- The Supabase service_role key bypasses RLS entirely.
-- No additional admin policies are needed.
-- The admin web portal will use the service_role key (server-side only,
-- NEVER exposed to clients or committed to source control).


-- ============================================================================
-- VERIFICATION QUERIES (optional — run these after the script to confirm)
-- ============================================================================
-- Uncomment and run individually to verify:
--
-- SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public'
--   ORDER BY table_name;
--
-- Expected: leaderboard_entries, sessions, user_achievements, user_stats, users
--
-- SELECT trigger_name, event_object_table FROM information_schema.triggers
--   WHERE trigger_schema = 'public' OR event_object_schema = 'auth'
--   ORDER BY trigger_name;
--
-- Expected: on_auth_user_created, on_user_created, on_user_stats_updated,
--           on_username_changed, on_users_updated


-- ============================================================================
-- DONE
-- ============================================================================
-- Schema creation complete.
--
-- Tables:    users, admin_users, sessions, user_stats, user_achievements, leaderboard_entries
-- Triggers:  on_auth_user_created      → routes admins → admin_users, players → users
--            on_user_created           → creates user_stats + user_achievements (players only)
--            on_username_changed       → syncs leaderboard_entries.username
--            on_users_updated          → auto updated_at on users
--            on_user_stats_updated     → auto updated_at on user_stats
--            on_admin_users_updated    → auto updated_at on admin_users
-- RLS:       Enabled on all 6 tables with scoped policies; service_role bypasses RLS.
--
-- Next steps:
--   1. Verify tables in Table Editor
--   2. Test sign-up flow (auth.users → public.users → user_stats → user_achievements)
--   3. Wire supabase_flutter into the Flutter app
