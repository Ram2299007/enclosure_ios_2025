-- ===================================================
-- BACKUP DATABASE BEFORE DELETION
-- ===================================================
-- 
-- ⚠️ CRITICAL: Run this BEFORE running DELETE_DATABASE_DATA.sql!
-- 
-- ===================================================

-- Option 1: Backup entire database using mysqldump (RECOMMENDED)
-- Run this in terminal/command prompt:

/*
mysqldump -u your_username -p encdb > encdb_backup_2026_02_11.sql
*/

-- Option 2: Create backup tables (within MySQL)

-- Backup user data
CREATE TABLE user_details_backup_20260211 AS SELECT * FROM user_details;
CREATE TABLE user_contacts_backup_20260211 AS SELECT * FROM user_contacts;

-- Backup chat data
CREATE TABLE individual_chat_backup_20260211 AS SELECT * FROM individual_chat;
CREATE TABLE group_chat_backup_20260211 AS SELECT * FROM group_chat;

-- Backup call data
CREATE TABLE calling_details_backup_20260211 AS SELECT * FROM calling_details;
CREATE TABLE voice_calling_details_backup_20260211 AS SELECT * FROM voice_calling_details;

-- Backup groups
CREATE TABLE groups_backup_20260211 AS SELECT * FROM groups;
CREATE TABLE group_members_backup_20260211 AS SELECT * FROM group_members;

-- ===================================================
-- VERIFY BACKUP
-- ===================================================

-- Check backup tables exist and have data
SELECT 
    'user_details_backup_20260211' AS backup_table,
    COUNT(*) AS row_count
FROM user_details_backup_20260211
UNION ALL
SELECT 'individual_chat_backup_20260211', COUNT(*) FROM individual_chat_backup_20260211
UNION ALL
SELECT 'group_chat_backup_20260211', COUNT(*) FROM group_chat_backup_20260211
UNION ALL
SELECT 'calling_details_backup_20260211', COUNT(*) FROM calling_details_backup_20260211
UNION ALL
SELECT 'groups_backup_20260211', COUNT(*) FROM groups_backup_20260211;

-- ===================================================
-- AFTER BACKUP IS COMPLETE
-- ===================================================

/*
✅ If backup is successful, then run:
   DELETE_DATABASE_DATA.sql

⚠️ Keep backup for at least 7 days before deleting
*/
