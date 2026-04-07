-- ============================================================
-- MIGRATION: Conversation Settings, Read Receipts & Roles
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Enable trigram extension for text search (if not already)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- 1. ALTER conversation_user — add role, creator, archive, pin, read receipts
-- ============================================================

ALTER TABLE conversation_user
  ADD COLUMN IF NOT EXISTS role smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_creator boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_read_at timestamptz DEFAULT now();

-- ============================================================
-- 2. ALTER messages — add delivered_at, expires_at
-- ============================================================

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz DEFAULT NULL;

-- ============================================================
-- 3. CREATE conversation_settings
-- ============================================================

CREATE TABLE IF NOT EXISTS conversation_settings (
  id serial PRIMARY KEY,
  conversation_id int NOT NULL UNIQUE REFERENCES conversations(id) ON DELETE CASCADE,
  who_can_manage_members smallint NOT NULL DEFAULT 0,
  who_can_edit_info smallint NOT NULL DEFAULT 0,
  who_can_send_messages smallint NOT NULL DEFAULT 0,
  ephemeral_duration smallint NOT NULL DEFAULT 0,
  theme smallint NOT NULL DEFAULT 0,
  image text DEFAULT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. CREATE conversation_notifications
-- ============================================================

CREATE TABLE IF NOT EXISTS conversation_notifications (
  id serial PRIMARY KEY,
  conversation_id int NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id int NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_muted boolean NOT NULL DEFAULT false,
  muted_until timestamptz DEFAULT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- ============================================================
-- 5. DATABASE INDICES for performance
-- ============================================================

-- Message queries (pagination, conversation loading)
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON messages(conversation_id, created_at DESC);

-- Expired ephemeral messages
CREATE INDEX IF NOT EXISTS idx_messages_expires
  ON messages(expires_at) WHERE expires_at IS NOT NULL;

-- Undelivered messages (for marking delivered_at)
CREATE INDEX IF NOT EXISTS idx_messages_undelivered
  ON messages(conversation_id, delivered_at) WHERE delivered_at IS NULL;

-- Conversation membership lookups
CREATE INDEX IF NOT EXISTS idx_conv_user_user
  ON conversation_user(user_id);

CREATE INDEX IF NOT EXISTS idx_conv_user_conv
  ON conversation_user(conversation_id);

-- Active (non-archived) conversations per user
CREATE INDEX IF NOT EXISTS idx_conv_user_active
  ON conversation_user(user_id, is_archived) WHERE is_archived = false;

-- Notification lookups
CREATE INDEX IF NOT EXISTS idx_conv_notif_lookup
  ON conversation_notifications(conversation_id, user_id);

-- Settings lookup
CREATE INDEX IF NOT EXISTS idx_conv_settings_conv
  ON conversation_settings(conversation_id);

-- Message text search (trigram)
CREATE INDEX IF NOT EXISTS idx_messages_body_trgm
  ON messages USING gin(body gin_trgm_ops);

-- ============================================================
-- 6. BACKFILL: Set earliest participant as creator/admin for existing conversations
-- ============================================================

-- For each conversation, the user with the earliest created_at in conversation_user becomes creator+admin
UPDATE conversation_user cu
SET role = 1, is_creator = true
FROM (
  SELECT DISTINCT ON (conversation_id) id
  FROM conversation_user
  ORDER BY conversation_id, created_at ASC, id ASC
) first_members
WHERE cu.id = first_members.id;

-- ============================================================
-- 7. Create default conversation_settings for existing conversations
-- ============================================================

INSERT INTO conversation_settings (conversation_id)
SELECT id FROM conversations
WHERE id NOT IN (SELECT conversation_id FROM conversation_settings)
ON CONFLICT (conversation_id) DO NOTHING;
