# DATABASE.md — FitFusion Database Schema Reference

**Version:** 1.0  
**Backend:** Supabase / PostgreSQL  
**Audience:** App developers (Flutter), Admin Portal developers (Web), Database administrators  
**Purpose:** This document is the single authoritative reference for FitFusion's data model. All application code, query logic, and admin portal behavior must conform to this schema.

---

## Table of Contents

1. [Overview](#overview)
2. [Entity-Relationship Diagram](#entity-relationship-diagram)
3. [Tables](#tables)
   - [users](#1-users)
   - [sessions](#2-sessions)
   - [user_stats](#3-user_stats)
   - [user_achievements](#4-user_achievements)
   - [leaderboard_entries](#5-leaderboard_entries)
   - [admin_users](#6-admin_users)
4. [Relationships](#relationships)
5. [Enumerations & Constraints](#enumerations--constraints)
6. [Data Update Logic](#data-update-logic)
   - [On Session Save](#on-session-save)
   - [Leaderboard Update Logic](#leaderboard-update-logic)
   - [Stats Update Logic](#stats-update-logic)
   - [Achievement Evaluation Logic](#achievement-evaluation-logic)
7. [Data Lifecycle](#data-lifecycle)
   - [Account Creation](#account-creation)
   - [Reset Game Data](#reset-game-data)
   - [Delete Account](#delete-account)
8. [Notes & Design Decisions](#notes--design-decisions)

---

## Overview

FitFusion's database supports two separate consumers:

- **The Flutter Mobile App** — reads and writes on behalf of authenticated players. Manages sessions, stats, achievements, and leaderboards per user.
- **The Web Admin Portal** — reads all data for oversight; performs administrative write actions (user management, leaderboard resets, data export).

The database is hosted on **Supabase** (managed PostgreSQL). Authentication is handled via **Supabase Auth**, which manages the `auth.users` table internally. FitFusion extends that with `public.users` for players and `public.admin_users` for admin portal accounts (both keyed to `auth.users.id`).
All timestamps are stored as `TIMESTAMPTZ` in UTC.  
All duration/interval values are stored in **seconds** as `NUMERIC(10, 4)` (4 decimal places of precision).  
All foreign keys use `ON DELETE CASCADE` to support clean account deletion.

---

## Entity-Relationship Diagram

```mermaid
erDiagram
    users {
        uuid id PK
        text username
        text email
        boolean is_email_verified
        timestamptz created_at
        timestamptz updated_at
    }

    sessions {
        uuid id PK
        uuid user_id FK
        text workout_type
        boolean won
        int total_reps
        int total_reps_required
        numeric total_time_seconds
        int rounds_completed
        numeric best_rep_interval_seconds
        numeric avg_rep_interval_seconds
        int lives_lost
        timestamptz completed_at
    }

    user_stats {
        uuid user_id PK FK
        int total_sessions
        int total_reps
        int total_rounds
        int squats_victories
        int squats_defeats
        int squats_rounds_completed
        int squats_reps_finished
        numeric squats_pb_clear_time_seconds
        numeric squats_pb_best_interval_seconds
        int jacks_victories
        int jacks_defeats
        int jacks_rounds_completed
        int jacks_reps_finished
        numeric jacks_pb_clear_time_seconds
        numeric jacks_pb_best_interval_seconds
        int crunches_victories
        int crunches_defeats
        int crunches_rounds_completed
        int crunches_reps_finished
        numeric crunches_pb_clear_time_seconds
        numeric crunches_pb_best_interval_seconds
        timestamptz updated_at
    }

    user_achievements {
        uuid user_id PK FK
        boolean first_blood
        timestamptz first_blood_unlocked_at
        boolean iron_will
        timestamptz iron_will_unlocked_at
        boolean blood_pumper
        timestamptz blood_pumper_unlocked_at
        boolean survivor
        timestamptz survivor_unlocked_at
        boolean halfway_hero
        timestamptz halfway_hero_unlocked_at
        boolean monster_hunter
        timestamptz monster_hunter_unlocked_at
        boolean triple_crown
        timestamptz triple_crown_unlocked_at
        boolean speed_demon
        timestamptz speed_demon_unlocked_at
        boolean blinding_steel
        timestamptz blinding_steel_unlocked_at
        boolean record_breaker
        timestamptz record_breaker_unlocked_at
        boolean sharper_than_yesterday
        timestamptz sharper_than_yesterday_unlocked_at
        boolean untouchable
        timestamptz untouchable_unlocked_at
        boolean last_stand
        timestamptz last_stand_unlocked_at
    }

    leaderboard_entries {
        uuid id PK
        text workout_type
        text metric
        uuid user_id FK
        text username
        numeric value
        uuid session_id FK
        int rank
        timestamptz recorded_at
    }

    admin_users {
        uuid id PK
        text email
        text role
        timestamptz created_at
        timestamptz updated_at
    }

    users ||--|{ sessions : has
    users ||--|| user_stats : has
    users ||--|| user_achievements : has
    users ||--|{ leaderboard_entries : contributes_to
    admin_users ||--|| auth_users : mirrors
    sessions ||--o{ leaderboard_entries : "sourced from"
```

---

## Tables

---

### 1. `users`

The core profile table for each registered player. Linked 1:1 with Supabase Auth's `auth.users` by the same UUID.

| Column             | Type          | Constraints                        | Description |
|--------------------|---------------|------------------------------------|-------------|
| `id`               | `UUID`        | `PRIMARY KEY`                      | Same UUID as `auth.users.id`. Populated on sign-up. |
| `username`         | `TEXT`        | `UNIQUE`, `NOT NULL`               | Player's chosen display name. Case-insensitive uniqueness enforced via a unique index on `LOWER(username)`. |
| `email`            | `TEXT`        | `UNIQUE`, `NOT NULL`               | Player's email address. Mirrors `auth.users.email`. Updated on email change. |
| `is_email_verified`| `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`        | Set to `TRUE` after successful OTP verification on sign-up. |
| `created_at`       | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`        | Timestamp of account creation. |
| `updated_at`       | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`        | Timestamp of last profile update. Updated on email/username change. |

**Indexes:**
```sql
CREATE UNIQUE INDEX users_username_lower_idx ON users (LOWER(username));
```

**Notes:**
- `id` is not auto-generated here — it is copied from `auth.users.id` at sign-up time to maintain FK integrity.
- Supabase Auth owns password storage and OTP logic. This table holds only the public-facing profile.
- On email change: `email` and `is_email_verified` must be updated. Re-verification via OTP is required.
- `username` must be case-insensitively unique. `JOHNDOE`, `johndoe`, and `JohnDoe` are all the same username.

---

### 2. `sessions`

One row per completed game session. A session is written to the database only when the game ends — either by victory, defeat, or forced exit (back/home button). Sessions are immutable once inserted.

| Column                       | Type          | Constraints                              | Description |
|------------------------------|---------------|------------------------------------------|-------------|
| `id`                         | `UUID`        | `PRIMARY KEY`, `DEFAULT gen_random_uuid()` | Unique session identifier. |
| `user_id`                    | `UUID`        | `NOT NULL`, `FK → users.id ON DELETE CASCADE` | The player who played this session. |
| `workout_type`               | `TEXT`        | `NOT NULL`, CHECK constraint (enum)      | The workout performed. Values: `'squats'`, `'jumping_jacks'`, `'side_crunches'`. |
| `won`                        | `BOOLEAN`     | `NOT NULL`                               | `TRUE` if the player defeated all 10 rounds. `FALSE` otherwise. |
| `total_reps`                 | `INT`         | `NOT NULL`, `DEFAULT 0`                  | Total reps performed during the session. Maximum 65 (for a won session). |
| `total_reps_required`        | `INT`         | `NOT NULL`, `DEFAULT 65`                 | Always 65 for a full game. Stored for historical reference. |
| `total_time_seconds`         | `NUMERIC(10,4)`| `NOT NULL`                              | Total elapsed session duration in seconds, from round 1 cooldown start to game end. |
| `rounds_completed`           | `INT`         | `NOT NULL`, `DEFAULT 0`                  | Number of rounds the player fully cleared (defeated the monster). Range: 0–10. |
| `best_rep_interval_seconds`  | `NUMERIC(10,4)`| `NULLABLE`                              | Fastest time (in seconds) between two consecutive reps within the session. `NULL` if fewer than 2 reps were performed. |
| `avg_rep_interval_seconds`   | `NUMERIC(10,4)`| `NULLABLE`                              | Mean time (in seconds) between all consecutive rep pairs in the session. `NULL` if fewer than 2 reps were performed. |
| `lives_lost`                 | `INT`         | `NOT NULL`, `DEFAULT 0`                  | Number of lives lost to pace failures. Range: 0–3. A value of 3 always means defeat. |
| `completed_at`               | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`              | UTC timestamp when the session ended. |

**Indexes:**
```sql
CREATE INDEX sessions_user_id_idx ON sessions (user_id);
CREATE INDEX sessions_workout_type_idx ON sessions (workout_type);
CREATE INDEX sessions_completed_at_idx ON sessions (completed_at DESC);
```

**Check Constraints:**
```sql
CONSTRAINT sessions_workout_type_check
  CHECK (workout_type IN ('squats', 'jumping_jacks', 'side_crunches')),

CONSTRAINT sessions_total_reps_range
  CHECK (total_reps >= 0 AND total_reps <= 65),

CONSTRAINT sessions_rounds_range
  CHECK (rounds_completed >= 0 AND rounds_completed <= 10),

CONSTRAINT sessions_lives_lost_range
  CHECK (lives_lost >= 0 AND lives_lost <= 3),

CONSTRAINT sessions_time_positive
  CHECK (total_time_seconds > 0)
```

**Notes:**
- Sessions initiated by a forced exit (back/home/overview button) are still recorded with `won = FALSE`, `lives_lost = 3`, and whatever stats were accumulated at the time of exit.
- `avg_rep_interval_seconds` is only meaningful (and only qualifies for leaderboard ranking) when the session has at least 2 reps, i.e. `total_reps >= 2`.
- `total_time_seconds` does **not** include cooldown periods — it measures only active gameplay time. *(To be confirmed during implementation; document will be updated if needed.)*
- Sessions are **never deleted individually** by the app. They are only removed by cascade when a user deletes their account, or wiped in bulk during "Reset Game Data".

---

### 3. `user_stats`

One row per user. Stores pre-computed aggregate statistics to enable fast reads on the Stats screen without querying and aggregating the entire sessions table at runtime.

This table is **always** updated immediately after a session is written.

| Column                           | Type           | Constraints                                   | Description |
|----------------------------------|----------------|-----------------------------------------------|-------------|
| `user_id`                        | `UUID`         | `PRIMARY KEY`, `FK → users.id ON DELETE CASCADE` | One row per user. |
| `total_sessions`                 | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Lifetime count of all completed sessions (wins + losses). |
| `total_reps`                     | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Lifetime total reps performed across all sessions and workout types. |
| `total_rounds`                   | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Lifetime total rounds completed across all sessions. |
| `squats_victories`               | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Total winning sessions where `workout_type = 'squats'`. |
| `squats_defeats`                 | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Total losing sessions where `workout_type = 'squats'`. |
| `squats_rounds_completed`        | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Cumulative rounds cleared in all squats sessions. |
| `squats_reps_finished`           | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Cumulative reps performed in all squats sessions. |
| `squats_pb_clear_time_seconds`   | `NUMERIC(10,4)`| `NULLABLE`                                    | Personal best clear time (lowest `total_time_seconds` among won squats sessions). `NULL` if no squats win yet. |
| `squats_pb_best_interval_seconds`| `NUMERIC(10,4)`| `NULLABLE`                                    | Personal best single rep interval (lowest `best_rep_interval_seconds`) across all squats sessions. `NULL` if never recorded. |
| `jacks_victories`                | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Total winning sessions where `workout_type = 'jumping_jacks'`. |
| `jacks_defeats`                  | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Total losing sessions where `workout_type = 'jumping_jacks'`. |
| `jacks_rounds_completed`         | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Cumulative rounds cleared in all jumping jacks sessions. |
| `jacks_reps_finished`            | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Cumulative reps performed in all jumping jacks sessions. |
| `jacks_pb_clear_time_seconds`    | `NUMERIC(10,4)`| `NULLABLE`                                    | Personal best clear time for jumping jacks won sessions. |
| `jacks_pb_best_interval_seconds` | `NUMERIC(10,4)`| `NULLABLE`                                    | Personal best single rep interval across all jumping jacks sessions. |
| `crunches_victories`             | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Total winning sessions where `workout_type = 'side_crunches'`. |
| `crunches_defeats`               | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Total losing sessions where `workout_type = 'side_crunches'`. |
| `crunches_rounds_completed`      | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Cumulative rounds cleared in all side crunches sessions. |
| `crunches_reps_finished`         | `INT`          | `NOT NULL`, `DEFAULT 0`                       | Cumulative reps performed in all side crunches sessions. |
| `crunches_pb_clear_time_seconds` | `NUMERIC(10,4)`| `NULLABLE`                                    | Personal best clear time for side crunches won sessions. |
| `crunches_pb_best_interval_seconds`| `NUMERIC(10,4)`| `NULLABLE`                                  | Personal best single rep interval across all side crunches sessions. |
| `updated_at`                     | `TIMESTAMPTZ`  | `NOT NULL`, `DEFAULT NOW()`                   | Timestamp of the last update to this row. |

**Notes:**
- A `user_stats` row is created (with all defaults) immediately when a new user account is created.
- `*_pb_clear_time_seconds` only considers **won** sessions (`won = TRUE`). A defeat cannot set a clear time PB.
- `*_pb_best_interval_seconds` considers **all** sessions where `best_rep_interval_seconds IS NOT NULL`, regardless of win/loss.
- The Stats screen computes **Average Clear Time** and **Average Rep Interval** on the fly from the `sessions` table (filtered by user and workout type), since these are not stored as pre-computed columns. These are the only two values that require a live query.
- "Reset Game Data" sets all numeric columns to `0` and all `NULLABLE` PB columns to `NULL`, and deletes all rows in `sessions` for that user.

---

### 4. `user_achievements`

One row per user. Stores the unlock state of all 13 achievements with their unlock timestamps. This table is updated immediately after a session completes and stats are evaluated.

| Column                               | Type          | Constraints                                        | Description |
|--------------------------------------|---------------|----------------------------------------------------|-------------|
| `user_id`                            | `UUID`        | `PRIMARY KEY`, `FK → users.id ON DELETE CASCADE`   | One row per user. |
| `first_blood`                        | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked after completing the first session (win or loss). |
| `first_blood_unlocked_at`            | `TIMESTAMPTZ` | `NULLABLE`                                         | Timestamp when `first_blood` was set to `TRUE`. `NULL` if locked. |
| `iron_will`                          | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when `total_sessions >= 30`. |
| `iron_will_unlocked_at`              | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `blood_pumper`                       | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when `total_reps >= 300`. |
| `blood_pumper_unlocked_at`           | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `survivor`                           | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when `total_rounds >= 100`. |
| `survivor_unlocked_at`               | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `halfway_hero`                       | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when any single session has `rounds_completed >= 5`. |
| `halfway_hero_unlocked_at`           | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `monster_hunter`                     | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when any session has `won = TRUE`. |
| `monster_hunter_unlocked_at`         | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `triple_crown`                       | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when the user has at least one win in each of the 3 workout types (`squats_victories >= 1 AND jacks_victories >= 1 AND crunches_victories >= 1`). |
| `triple_crown_unlocked_at`           | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `speed_demon`                        | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when any session has `best_rep_interval_seconds < 1.8`. |
| `speed_demon_unlocked_at`            | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `blinding_steel`                     | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when any won session has `avg_rep_interval_seconds < 2.3`. |
| `blinding_steel_unlocked_at`         | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `record_breaker`                     | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when a won session's `total_time_seconds` is lower than the user's previous PB for that workout type (i.e., a new PB was just set and a prior PB already existed). |
| `record_breaker_unlocked_at`         | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `sharper_than_yesterday`             | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when a session's `best_rep_interval_seconds` is lower than the user's previous PB interval for that workout type (and a prior PB already existed). |
| `sharper_than_yesterday_unlocked_at` | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `untouchable`                        | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when a won session has `lives_lost = 0`. |
| `untouchable_unlocked_at`            | `TIMESTAMPTZ` | `NULLABLE`                                         | |
| `last_stand`                         | `BOOLEAN`     | `NOT NULL`, `DEFAULT FALSE`                        | Unlocked when a won session has `lives_lost = 2`. |
| `last_stand_unlocked_at`             | `TIMESTAMPTZ` | `NULLABLE`                                         | |

**Notes:**
- Achievements are **one-way** — once unlocked (`TRUE`), they are never reverted to `FALSE` unless the user performs "Reset Game Data".
- "Reset Game Data" sets all achievement columns to `FALSE` and all `*_unlocked_at` to `NULL`.
- A `user_achievements` row is created (all `FALSE`) when a new user account is created.
- Achievement checks for `record_breaker` and `sharper_than_yesterday` must compare the **pre-update** PB value (before `user_stats` is updated) against the new session value. If the new session beats the old PB **and** a prior PB existed (was not `NULL`), the achievement unlocks.

---

### 5. `leaderboard_entries`

Stores the top 10 scores per metric per workout type. This represents 9 independent leaderboard boards (3 workout types × 3 metrics). Each board holds at most 10 rows (one per rank 1–10). Only one entry per user per board is kept (the user's personal best for that metric).

| Column         | Type           | Constraints                                        | Description |
|----------------|----------------|----------------------------------------------------|-------------|
| `id`           | `UUID`         | `PRIMARY KEY`, `DEFAULT gen_random_uuid()`         | Unique row identifier. |
| `workout_type` | `TEXT`         | `NOT NULL`, CHECK constraint (enum)                | The workout type this board belongs to. Values: `'squats'`, `'jumping_jacks'`, `'side_crunches'`. |
| `metric`       | `TEXT`         | `NOT NULL`, CHECK constraint (enum)                | The ranked metric. Values: `'clear_time'`, `'best_rep_interval'`, `'avg_rep_interval'`. |
| `user_id`      | `UUID`         | `NOT NULL`, `FK → users.id ON DELETE CASCADE`      | The user this entry belongs to. |
| `username`     | `TEXT`         | `NOT NULL`                                         | Denormalized username for fast display. Updated if the user changes their username. |
| `value`        | `NUMERIC(10,4)`| `NOT NULL`                                         | The metric value in seconds. All 3 metrics are **lower is better**. |
| `session_id`   | `UUID`         | `NOT NULL`, `FK → sessions.id ON DELETE CASCADE`   | The specific session that produced this score. |
| `rank`         | `INT`          | `NOT NULL`                                         | Current rank position (1 = best). Recomputed after any insert/update to the board. |
| `recorded_at`  | `TIMESTAMPTZ`  | `NOT NULL`, `DEFAULT NOW()`                        | Timestamp when this entry was last set or updated. |

**Unique Constraints:**
```sql
-- One entry per user per board
CONSTRAINT leaderboard_entries_user_board_unique
  UNIQUE (workout_type, metric, user_id)
```

**Check Constraints:**
```sql
CONSTRAINT leaderboard_entries_workout_type_check
  CHECK (workout_type IN ('squats', 'jumping_jacks', 'side_crunches')),

CONSTRAINT leaderboard_entries_metric_check
  CHECK (metric IN ('clear_time', 'best_rep_interval', 'avg_rep_interval')),

CONSTRAINT leaderboard_entries_rank_range
  CHECK (rank >= 1 AND rank <= 10)
```

**Indexes:**
```sql
CREATE INDEX leaderboard_entries_board_idx
  ON leaderboard_entries (workout_type, metric, rank ASC);
```

**Notes:**
- `clear_time` entries only come from sessions where `won = TRUE`. A defeat time is not eligible.
- `avg_rep_interval` entries only come from sessions where `total_reps >= 2` (so that the average is meaningful).
- `best_rep_interval` entries come from any session where `best_rep_interval_seconds IS NOT NULL` (win or loss).
- If a user's new session qualifies for a board and is **better** than their existing entry on that board, the existing entry is **updated** (UPSERT), ranks are recomputed, and the 11th-place entry (if any) is evicted.
- If a user's new session qualifies but is **worse** than their existing entry, no change is made to the leaderboard.
- `username` is denormalized into this table. On username change, all leaderboard entries for that user must be updated.
- On session delete (cascade from user delete), leaderboard entries for that session are also cascade-deleted, and ranks are recomputed.

---

### 6. `admin_users`

Dedicated table for admin portal accounts. Admins do **not** get game data rows.

| Column      | Type          | Constraints                              | Description |
|-------------|---------------|------------------------------------------|-------------|
| `id`        | `UUID`        | `PRIMARY KEY`                            | Same UUID as `auth.users.id` for the admin. |
| `email`     | `TEXT`        | `UNIQUE`, `NOT NULL`                     | Admin email (mirrors `auth.users.email`). |
| `role`      | `TEXT`        | `NOT NULL`, `DEFAULT 'admin'`, `CHECK (role IN ('admin','superadmin'))` | Admin role level. |
| `created_at`| `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`              | Created timestamp. |
| `updated_at`| `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()`              | Updated via trigger on update. |

Triggers:
```sql
CREATE TRIGGER on_admin_users_updated
  BEFORE UPDATE ON public.admin_users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_admin_users_updated_at();
```

Comments:
- Independent from player `users`; no cascade into `user_stats` or `user_achievements`.
- Populated when an auth user is created with `app_metadata.role = 'admin'` (or `superadmin`).

---

## Relationships

```
users (1) ──────────────── (N) sessions
  │  One user can have many sessions.
  │  A session belongs to exactly one user.

users (1) ──────────────── (1) user_stats
  │  One user has exactly one stats row.
  │  Created on sign-up; deleted on account delete.

users (1) ──────────────── (1) user_achievements
  │  One user has exactly one achievements row.
  │  Created on sign-up; deleted on account delete.

users (1) ──────────────── (N) leaderboard_entries
  │  One user can appear in multiple leaderboard boards.
  │  At most one entry per user per (workout_type, metric) board.

sessions (1) ───────────── (N) leaderboard_entries
     A session can source multiple leaderboard entries
     (e.g., same session qualifies for both clear_time and best_rep_interval).
     If that session is deleted, its leaderboard entries are cascade-deleted.
```

---

## Enumerations & Constraints

### `workout_type` values

| App Value (Dart enum)            | DB String Value   |
|----------------------------------|-------------------|
| `WorkoutType.squats`             | `'squats'`        |
| `WorkoutType.jumpingJacks`       | `'jumping_jacks'` |
| `WorkoutType.obliqueCrunches`    | `'side_crunches'` |

### `metric` values (leaderboard)

| Metric                 | DB String Value        | Lower is better? | Eligible sessions         |
|------------------------|------------------------|------------------|---------------------------|
| Clear Time             | `'clear_time'`         | Yes              | Won sessions only         |
| Best Rep Interval      | `'best_rep_interval'`  | Yes              | Any session with ≥2 reps  |
| Average Rep Interval   | `'avg_rep_interval'`   | Yes              | Any session with ≥2 reps  |

### Password Rules (enforced at application layer, not DB layer)

- Minimum 8 characters total
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 alphanumeric character (digit)
- At least 1 special character

### Username Rules (DB + application layer)

- Case-insensitive uniqueness (enforced via `LOWER(username)` unique index)
- No leading/trailing whitespace (enforced at application layer)

---

## Data Update Logic

### On Session Save

The following sequence occurs **atomically** (within a single transaction or Supabase Edge Function) every time a session record is written:

```
1. INSERT into sessions (the raw session record)
2. READ the current user_stats row (to capture pre-update PB values)
3. UPDATE user_stats (increment counters, update PBs if improved)
4. EVALUATE achievements (compare session + updated stats against unlock conditions)
5. UPDATE user_achievements (set newly unlocked achievements + timestamps)
6. EVALUATE leaderboard eligibility (per metric per workout type)
7. UPSERT leaderboard_entries if session qualifies
8. RECOMPUTE ranks for affected boards
9. EVICT any entries ranked > 10 from affected boards
```

---

### Leaderboard Update Logic

After a session is saved, for each of the 3 metrics:

```
For each metric M in {clear_time, best_rep_interval, avg_rep_interval}:

  1. Check if session is eligible for metric M:
     - clear_time:          won == TRUE
     - best_rep_interval:   best_rep_interval_seconds IS NOT NULL
     - avg_rep_interval:    avg_rep_interval_seconds IS NOT NULL (requires total_reps >= 2)

  2. If eligible:
     a. Check if a leaderboard_entries row already exists for
        (user_id, workout_type, M).

     b. If EXISTS and new value < existing value:
        → UPDATE the row: set value, session_id, recorded_at
        → RECOMPUTE ranks for all rows on this board

     c. If NOT EXISTS:
        → Check if the new value qualifies for top 10
          (i.e., the board has fewer than 10 rows, OR new value < the current 10th-place value)
        → If qualifies: INSERT the new entry
        → RECOMPUTE ranks for all rows on this board
        → DELETE any row with rank > 10 (evict 11th place)

     d. If EXISTS and new value >= existing value:
        → No change. (User's existing entry is still their best.)
```

Rank recomputation:
```sql
-- After any insert/update on a specific board:
UPDATE leaderboard_entries
SET rank = sub.new_rank
FROM (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY workout_type, metric
           ORDER BY value ASC
         ) AS new_rank
  FROM leaderboard_entries
  WHERE workout_type = $workout_type
    AND metric = $metric
) sub
WHERE leaderboard_entries.id = sub.id;
```

---

### Stats Update Logic

After a session is saved, `user_stats` is updated as follows:

```
Always (all sessions):
  total_sessions        += 1
  total_reps            += session.total_reps
  total_rounds          += session.rounds_completed

  {type}_rounds_completed += session.rounds_completed
  {type}_reps_finished    += session.total_reps

  IF won:
    {type}_victories += 1
  ELSE:
    {type}_defeats   += 1

PB Updates:
  IF session.best_rep_interval_seconds IS NOT NULL:
    IF {type}_pb_best_interval_seconds IS NULL
       OR session.best_rep_interval_seconds < {type}_pb_best_interval_seconds:
      {type}_pb_best_interval_seconds = session.best_rep_interval_seconds

  IF won:
    IF {type}_pb_clear_time_seconds IS NULL
       OR session.total_time_seconds < {type}_pb_clear_time_seconds:
      {type}_pb_clear_time_seconds = session.total_time_seconds

  updated_at = NOW()
```

Where `{type}` is one of `squats`, `jacks`, or `crunches` depending on `session.workout_type`.

---

### Achievement Evaluation Logic

Achievements are evaluated **after** `user_stats` is updated. The pre-update snapshot of `user_stats` must be captured before the update to correctly evaluate `record_breaker` and `sharper_than_yesterday`.

Evaluation order and unlock conditions (matches README achievement table):

| # | Achievement ID             | Unlock Condition                                                                                                                  |
|---|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| 1 | `first_blood`              | `user_stats.total_sessions >= 1`                                                                                                  |
| 2 | `iron_will`                | `user_stats.total_sessions >= 30`                                                                                                 |
| 3 | `blood_pumper`             | `user_stats.total_reps >= 300`                                                                                                    |
| 4 | `survivor`                 | `user_stats.total_rounds >= 100`                                                                                                  |
| 5 | `halfway_hero`             | `session.rounds_completed >= 5`                                                                                                   |
| 6 | `monster_hunter`           | `session.won == TRUE`                                                                                                             |
| 7 | `triple_crown`             | `squats_victories >= 1 AND jacks_victories >= 1 AND crunches_victories >= 1` (using post-update stats)                            |
| 8 | `speed_demon`              | `session.best_rep_interval_seconds < 1.8`                                                                                        |
| 9 | `blinding_steel`           | `session.won == TRUE AND session.avg_rep_interval_seconds < 2.3`                                                                  |
| 10| `record_breaker`           | `session.won == TRUE AND pre_update_{type}_pb_clear_time_seconds IS NOT NULL AND session.total_time_seconds < pre_update_{type}_pb_clear_time_seconds` |
| 11| `sharper_than_yesterday`   | `pre_update_{type}_pb_best_interval_seconds IS NOT NULL AND session.best_rep_interval_seconds < pre_update_{type}_pb_best_interval_seconds` |
| 12| `untouchable`              | `session.won == TRUE AND session.lives_lost == 0`                                                                                 |
| 13| `last_stand`               | `session.won == TRUE AND session.lives_lost == 2`                                                                                 |

For any achievement that is already `TRUE`, skip the evaluation (no double-unlock, no timestamp overwrite).

If a new unlock is detected:
```
SET achievement_column = TRUE
SET achievement_unlocked_at = NOW()
```

---

## Data Lifecycle

### Account Creation

When a user successfully signs up and verifies their email, the following rows are created:

```
1. Supabase Auth creates auth.users row (managed internally)
2. INSERT into public.users   (id, username, email, is_email_verified=TRUE, created_at)
3. INSERT into user_stats     (user_id, all counters = 0, all PBs = NULL)
4. INSERT into user_achievements (user_id, all booleans = FALSE, all timestamps = NULL)
```

No `sessions` or `leaderboard_entries` rows are created at sign-up.

---

### Reset Game Data

Triggered from the user's Profile Settings screen. Wipes all gameplay progress while keeping the account active and credentials intact.

```
1. DELETE FROM sessions WHERE user_id = $user_id
   (leaderboard_entries with session_id referencing these sessions are cascade-deleted)

2. UPDATE user_stats SET
     total_sessions = 0, total_reps = 0, total_rounds = 0,
     squats_victories = 0, squats_defeats = 0,
     squats_rounds_completed = 0, squats_reps_finished = 0,
     squats_pb_clear_time_seconds = NULL,
     squats_pb_best_interval_seconds = NULL,
     jacks_victories = 0, jacks_defeats = 0,
     jacks_rounds_completed = 0, jacks_reps_finished = 0,
     jacks_pb_clear_time_seconds = NULL,
     jacks_pb_best_interval_seconds = NULL,
     crunches_victories = 0, crunches_defeats = 0,
     crunches_rounds_completed = 0, crunches_reps_finished = 0,
     crunches_pb_clear_time_seconds = NULL,
     crunches_pb_best_interval_seconds = NULL,
     updated_at = NOW()
   WHERE user_id = $user_id

3. UPDATE user_achievements SET
     first_blood = FALSE, first_blood_unlocked_at = NULL,
     iron_will = FALSE, iron_will_unlocked_at = NULL,
     blood_pumper = FALSE, blood_pumper_unlocked_at = NULL,
     survivor = FALSE, survivor_unlocked_at = NULL,
     halfway_hero = FALSE, halfway_hero_unlocked_at = NULL,
     monster_hunter = FALSE, monster_hunter_unlocked_at = NULL,
     triple_crown = FALSE, triple_crown_unlocked_at = NULL,
     speed_demon = FALSE, speed_demon_unlocked_at = NULL,
     blinding_steel = FALSE, blinding_steel_unlocked_at = NULL,
     record_breaker = FALSE, record_breaker_unlocked_at = NULL,
     sharper_than_yesterday = FALSE, sharper_than_yesterday_unlocked_at = NULL,
     untouchable = FALSE, untouchable_unlocked_at = NULL,
     last_stand = FALSE, last_stand_unlocked_at = NULL
   WHERE user_id = $user_id

4. Leaderboard entries for this user are already gone via session cascade.
   Any remaining entries (if session_id was nullable in the future) must also be deleted:
   DELETE FROM leaderboard_entries WHERE user_id = $user_id

5. RECOMPUTE ranks for all affected leaderboard boards.
```

After this operation: the user's account exists and is fully functional, but their stats, sessions, and achievements are as if they just signed up.

---

### Delete Account

Triggered from the user's Profile Settings screen. Irreversible.

```
1. DELETE FROM public.users WHERE id = $user_id
   -- Cascades to: sessions, user_stats, user_achievements, leaderboard_entries

2. Supabase Auth deletes auth.users row (handled via Supabase Auth API)

3. RECOMPUTE ranks for all leaderboard boards that had entries from this user.
```

All data belonging to this user is permanently removed. The username and email become available for re-registration.

---

## Notes & Design Decisions

### Why a flat wide `user_stats` table instead of a normalized per-workout-type table?

A normalized approach would use a table like `user_stats_by_workout (user_id, workout_type, victories, defeats, ...)` with 3 rows per user. The flat wide table was chosen because:
- There are exactly 3 workout types that will not change.
- All stats for a user are almost always read together (for the Stats screen, which shows all 3 workout types at once).
- A single row read is faster and simpler than a 3-row join.

### Why store `username` in `leaderboard_entries`?

Denormalization is intentional here. The leaderboard is a hot read path (displayed on every home screen visit). Avoiding a JOIN to `users` on every leaderboard read is a deliberate performance trade-off. The trade-off is that `username` must be kept in sync with `users.username` on username change — this is an acceptable overhead since username changes are rare.

### Why are all 3 leaderboard metrics "lower is better"?

- **Clear Time:** Lower time = faster completion = better player.
- **Best Rep Interval:** Lower interval = faster reps = better athleticism.
- **Average Rep Interval:** Lower average = consistently faster reps = better endurance.

All three use the same ranking direction, simplifying leaderboard query logic.

### Why is `total_time_seconds` stored in sessions as a `NUMERIC` rather than an `INTERVAL`?

The app calculates and transmits this as a plain decimal number (seconds with millisecond precision). Storing as `NUMERIC(10, 4)` avoids any interval parsing overhead and keeps the value directly comparable for leaderboard ranking and personal best checks.

### Supabase Auth integration note

Supabase Auth provides `auth.users` internally. `public.users.id` must always equal `auth.users.id`. This is enforced at the application layer (sign-up procedure), not by a DB-level foreign key into `auth.users` (which is not recommended by Supabase). A Supabase trigger or Edge Function is the recommended mechanism to automatically create the `public.users`, `user_stats`, and `user_achievements` rows when `auth.users` is inserted.

### Row-Level Security (RLS)

Supabase RLS policies should be applied as follows (implementation detail for when Supabase is set up):

| Table                 | Player Policy                                      | Admin Policy            |
|-----------------------|----------------------------------------------------|-------------------------|
| `users`               | Read/update own row only                           | Read all, write all     |
| `sessions`            | Read/insert own rows only; no update/delete        | Read all, delete all    |
| `user_stats`          | Read own row only; no direct write (server-side only) | Read all, write all  |
| `user_achievements`   | Read own row only; no direct write (server-side only) | Read all, write all  |
| `leaderboard_entries` | Read all (public leaderboard); no direct write     | Read all, write all     |
| `admin_users`         | Read/update own row only (for auth checks)         | Read all, write all     |

---

*This document is maintained alongside the codebase. When any schema change is made, this file must be updated first.*
