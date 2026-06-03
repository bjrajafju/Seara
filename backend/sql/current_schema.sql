-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.cache (
  key text NOT NULL,
  value text NOT NULL,
  expiration integer NOT NULL,
  CONSTRAINT cache_pkey PRIMARY KEY (key)
);
CREATE TABLE public.cache_locks (
  key text NOT NULL,
  owner text NOT NULL,
  expiration integer NOT NULL,
  CONSTRAINT cache_locks_pkey PRIMARY KEY (key)
);
CREATE TABLE public.conversations (
  id bigint NOT NULL DEFAULT nextval('conversations_id_seq'::regclass),
  name text,
  is_group boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.users (
  id bigint NOT NULL DEFAULT nextval('users_id_seq'::regclass),
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  email_verified_at timestamp without time zone,
  remember_token text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  bio text,
  avatar text,
  is_private boolean NOT NULL DEFAULT false,
  auth_id uuid NOT NULL UNIQUE,
  username text NOT NULL UNIQUE,
  theme text NOT NULL DEFAULT 'light'::text,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
CREATE TABLE public.conversation_user (
  id bigint NOT NULL DEFAULT nextval('conversation_user_id_seq'::regclass),
  conversation_id bigint NOT NULL,
  user_id bigint NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  role smallint NOT NULL DEFAULT 0,
  is_creator boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  is_pinned boolean NOT NULL DEFAULT false,
  last_read_at timestamp with time zone DEFAULT now(),
  CONSTRAINT conversation_user_pkey PRIMARY KEY (id),
  CONSTRAINT conversation_user_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT conversation_user_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.desafios (
  id bigint NOT NULL DEFAULT nextval('desafios_id_seq'::regclass),
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT desafios_pkey PRIMARY KEY (id)
);
CREATE TABLE public.failed_jobs (
  id bigint NOT NULL DEFAULT nextval('failed_jobs_id_seq'::regclass),
  uuid text NOT NULL UNIQUE,
  connection text NOT NULL,
  queue text NOT NULL,
  payload text NOT NULL,
  exception text NOT NULL,
  failed_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT failed_jobs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.followers (
  id bigint NOT NULL DEFAULT nextval('followers_id_seq'::regclass),
  user_id bigint NOT NULL,
  follower_id bigint NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT followers_pkey PRIMARY KEY (id),
  CONSTRAINT followers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT followers_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id)
);
CREATE TABLE public.job_batches (
  id text NOT NULL,
  name text NOT NULL,
  total_jobs integer NOT NULL,
  pending_jobs integer NOT NULL,
  failed_jobs integer NOT NULL,
  failed_job_ids text NOT NULL,
  options text,
  cancelled_at integer,
  created_at integer NOT NULL,
  finished_at integer,
  CONSTRAINT job_batches_pkey PRIMARY KEY (id)
);
CREATE TABLE public.jobs (
  id bigint NOT NULL DEFAULT nextval('jobs_id_seq'::regclass),
  queue text NOT NULL,
  payload text NOT NULL,
  attempts smallint NOT NULL,
  reserved_at integer,
  available_at integer NOT NULL,
  created_at integer NOT NULL,
  CONSTRAINT jobs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.messages (
  id bigint NOT NULL DEFAULT nextval('messages_id_seq'::regclass),
  conversation_id bigint NOT NULL,
  user_id bigint NOT NULL,
  body text,
  attachment text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  attachment_type text,
  attachment_name text,
  delivered_at timestamp with time zone,
  expires_at timestamp with time zone,
  is_system boolean DEFAULT false,
  edited_at timestamp with time zone,
  deleted_at timestamp with time zone,
  is_forwarded boolean DEFAULT false,
  reply_to_message_id bigint,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT messages_reply_to_message_id_fkey FOREIGN KEY (reply_to_message_id) REFERENCES public.messages(id)
);
CREATE TABLE public.migrations (
  id integer NOT NULL DEFAULT nextval('migrations_id_seq'::regclass),
  migration text NOT NULL,
  batch integer NOT NULL,
  CONSTRAINT migrations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.password_reset_tokens (
  email text NOT NULL,
  token text NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email)
);
CREATE TABLE public.sessions (
  id text NOT NULL,
  user_id bigint,
  ip_address text,
  user_agent text,
  payload text NOT NULL,
  last_activity integer NOT NULL,
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.submissaos (
  id bigint NOT NULL DEFAULT nextval('submissaos_id_seq'::regclass),
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT submissaos_pkey PRIMARY KEY (id)
);
CREATE TABLE public.conversation_settings (
  id integer NOT NULL DEFAULT nextval('conversation_settings_id_seq'::regclass),
  conversation_id integer NOT NULL UNIQUE,
  who_can_manage_members smallint NOT NULL DEFAULT 0,
  who_can_edit_info smallint NOT NULL DEFAULT 0,
  who_can_send_messages smallint NOT NULL DEFAULT 0,
  ephemeral_duration smallint NOT NULL DEFAULT 0,
  theme smallint NOT NULL DEFAULT 0,
  image text,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  description text,
  who_can_edit_bio integer DEFAULT 0,
  CONSTRAINT conversation_settings_pkey PRIMARY KEY (id),
  CONSTRAINT conversation_settings_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
);
CREATE TABLE public.conversation_notifications (
  id integer NOT NULL DEFAULT nextval('conversation_notifications_id_seq'::regclass),
  conversation_id integer NOT NULL,
  user_id integer NOT NULL,
  is_muted boolean NOT NULL DEFAULT false,
  muted_until timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversation_notifications_pkey PRIMARY KEY (id),
  CONSTRAINT conversation_notifications_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT conversation_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.pinned_messages (
  id bigint NOT NULL DEFAULT nextval('pinned_messages_id_seq'::regclass),
  conversation_id bigint,
  message_id bigint,
  pinned_by bigint,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pinned_messages_pkey PRIMARY KEY (id),
  CONSTRAINT pinned_messages_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id),
  CONSTRAINT pinned_messages_pinned_by_fkey FOREIGN KEY (pinned_by) REFERENCES public.users(id),
  CONSTRAINT pinned_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
);
CREATE TABLE public.message_reactions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  message_id bigint NOT NULL,
  user_id bigint NOT NULL,
  reaction text NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT message_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT message_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id),
  CONSTRAINT message_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.stories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  media_url text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['image'::text, 'video'::text])),
  duration double precision DEFAULT 6.0,
  created_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
  CONSTRAINT stories_pkey PRIMARY KEY (id),
  CONSTRAINT stories_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(auth_id)
);
CREATE TABLE public.story_views (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL,
  viewer_id uuid NOT NULL,
  viewed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT story_views_pkey PRIMARY KEY (id),
  CONSTRAINT story_views_story_id_fkey FOREIGN KEY (story_id) REFERENCES public.stories(id),
  CONSTRAINT story_views_viewer_id_fkey FOREIGN KEY (viewer_id) REFERENCES public.users(auth_id)
);
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  media_url text NOT NULL,
  media_type text NOT NULL CHECK (media_type = ANY (ARRAY['image'::text, 'video'::text])),
  caption text,
  thumbnail_url text,
  crop jsonb NOT NULL DEFAULT '{"scale": 1, "offsetX": 0, "offsetY": 0}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(auth_id)
);
CREATE TABLE public.post_comments (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_comments_pkey PRIMARY KEY (id),
  CONSTRAINT post_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(auth_id),
  CONSTRAINT post_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.post_likes (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_likes_pkey PRIMARY KEY (id),
  CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(auth_id),
  CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.daily_questions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  date text UNIQUE,
  question text NOT NULL,
  option_a text NOT NULL,
  option_b text NOT NULL,
  option_c text NOT NULL,
  option_d text NOT NULL,
  correct_option text NOT NULL,
  explanation text,
  topic text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT daily_questions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_daily_answers (
  user_id uuid NOT NULL,
  question_id uuid NOT NULL,
  selected_option text NOT NULL,
  is_correct boolean NOT NULL,
  answered_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_daily_answers_pkey PRIMARY KEY (user_id, question_id),
  CONSTRAINT user_daily_answers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(auth_id),
  CONSTRAINT user_daily_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.daily_questions(id)
);