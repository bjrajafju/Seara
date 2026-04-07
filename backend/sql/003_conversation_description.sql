-- Task 12: Add description column for group bio/description
-- Fix #1: Add who_can_edit_bio permission column
ALTER TABLE conversation_settings
ADD COLUMN IF NOT EXISTS description TEXT DEFAULT NULL;

ALTER TABLE conversation_settings
ADD COLUMN IF NOT EXISTS who_can_edit_bio INTEGER DEFAULT 0;
