-- =====================================================
-- Migration: Add is_system column to messages table
-- Purpose: Support system-generated messages (joins, leaves, name changes)
-- Run this in your Supabase SQL editor
-- =====================================================

-- 1. Add is_system column (defaults to false)
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT false;

-- 2. Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_messages_is_system
ON messages (conversation_id, is_system)
WHERE is_system = true;

-- 3. Allow user_id = 0 for system messages
-- (If user_id has a foreign key constraint, we need a system user)
-- Insert a system user with id=0 if it doesn't exist
INSERT INTO users (id, username, name, email, avatar)
VALUES (0, 'system', 'Sistema', 'system@seara.app', '')
ON CONFLICT (id) DO NOTHING;
