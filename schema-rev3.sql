-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.achievements (
  id smallint NOT NULL DEFAULT nextval('achievements_id_seq'::regclass),
  code text NOT NULL UNIQUE,
  title text NOT NULL UNIQUE,
  description text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT achievements_pkey PRIMARY KEY (id)
);
CREATE TABLE public.admin_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_user_id uuid NOT NULL,
  action text NOT NULL,
  target_kind USER-DEFINED NOT NULL DEFAULT 'system'::admin_action_target,
  target_user_id uuid,
  target_session_id uuid,
  details jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT admin_logs_pkey PRIMARY KEY (id),
  CONSTRAINT admin_logs_target_session_id_fkey FOREIGN KEY (target_session_id) REFERENCES public.sessions(id)
);
CREATE TABLE public.sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  workout_type USER-DEFINED NOT NULL,
  won boolean NOT NULL,
  rounds_completed integer NOT NULL DEFAULT 0 CHECK (rounds_completed >= 0 AND rounds_completed <= 10),
  total_reps integer NOT NULL DEFAULT 0 CHECK (total_reps >= 0 AND total_reps <= 91),
  lives_lost integer NOT NULL DEFAULT 0 CHECK (lives_lost >= 0 AND lives_lost <= 3),
  total_time_seconds numeric CHECK (total_time_seconds IS NULL OR total_time_seconds > 0::numeric),
  best_rep_interval_seconds numeric CHECK (best_rep_interval_seconds IS NULL OR best_rep_interval_seconds > 0::numeric),
  avg_rep_interval_seconds numeric CHECK (avg_rep_interval_seconds IS NULL OR avg_rep_interval_seconds > 0::numeric),
  completed_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.user_achievements (
  user_id uuid NOT NULL,
  achievement_id smallint NOT NULL,
  unlocked_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_achievements_pkey PRIMARY KEY (user_id, achievement_id),
  CONSTRAINT user_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT user_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.achievements(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  username text NOT NULL,
  email text NOT NULL UNIQUE,
  role USER-DEFINED NOT NULL DEFAULT 'player'::user_role,
  is_email_verified boolean NOT NULL DEFAULT false,
  show_tutorial boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
