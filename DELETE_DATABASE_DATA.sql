-- ===================================================
-- DELETE ALL DATA FROM ENCLOSURE DATABASE TABLES
-- ===================================================
-- 
-- ⚠️ WARNING: This will DELETE ALL DATA!
-- 
-- PRESERVES (NOT deleted):
--   - emoji_table
--   - emoji_tbl
--   - country_list
-- 
-- ===================================================

-- Disable foreign key checks temporarily
SET FOREIGN_KEY_CHECKS = 0;

-- ===================================================
-- DELETE DATA FROM ALL TABLES (except 3 preserved)
-- ===================================================

-- Admin & Advertisement
TRUNCATE TABLE admin_advertisement;
TRUNCATE TABLE advertisement_plan;
TRUNCATE TABLE manage_advertisement;

-- User Management
TRUNCATE TABLE user_details;
TRUNCATE TABLE user_profile_images;
TRUNCATE TABLE user_contacts;
TRUNCATE TABLE user_contact_files;

-- Block & Privacy
TRUNCATE TABLE block_user;
TRUNCATE TABLE blocked_contact_list;

-- Chat & Messages
TRUNCATE TABLE individual_chat;
TRUNCATE TABLE group_chat;
TRUNCATE TABLE deleted_messages;
TRUNCATE TABLE seen_msg;
TRUNCATE TABLE conversation_summary;
TRUNCATE TABLE msg_limit_for_user_chat;

-- Groups
TRUNCATE TABLE groups;
TRUNCATE TABLE group_members;
TRUNCATE TABLE request_to_join;

-- Calling
TRUNCATE TABLE calling_details;
TRUNCATE TABLE group_calling_details;
TRUNCATE TABLE voice_calling_details;

-- Plans & Revenue
TRUNCATE TABLE business_profile_plan;
TRUNCATE TABLE subscription_plan;
TRUNCATE TABLE subscription_plan_old;
TRUNCATE TABLE video_plan;
TRUNCATE TABLE revenue_management;

-- App Settings
TRUNCATE TABLE faq;
TRUNCATE TABLE get_in_touch;
TRUNCATE TABLE privacy_policy;
TRUNCATE TABLE terms_and_conditions;
TRUNCATE TABLE languages;

-- Theme
TRUNCATE TABLE themes;
TRUNCATE TABLE theme_colors;

-- ===================================================
-- PRESERVED TABLES (Data NOT deleted)
-- ===================================================
-- ✅ emoji_table - PRESERVED
-- ✅ emoji_tbl - PRESERVED
-- ✅ country_list - PRESERVED

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ===================================================
-- VERIFICATION QUERIES
-- ===================================================

-- Check row counts after deletion
SELECT 
    'admin_advertisement' AS table_name, 
    COUNT(*) AS row_count 
FROM admin_advertisement
UNION ALL
SELECT 'advertisement_plan', COUNT(*) FROM advertisement_plan
UNION ALL
SELECT 'block_user', COUNT(*) FROM block_user
UNION ALL
SELECT 'blocked_contact_list', COUNT(*) FROM blocked_contact_list
UNION ALL
SELECT 'business_profile_plan', COUNT(*) FROM business_profile_plan
UNION ALL
SELECT 'calling_details', COUNT(*) FROM calling_details
UNION ALL
SELECT 'conversation_summary', COUNT(*) FROM conversation_summary
UNION ALL
SELECT 'deleted_messages', COUNT(*) FROM deleted_messages
UNION ALL
SELECT 'faq', COUNT(*) FROM faq
UNION ALL
SELECT 'get_in_touch', COUNT(*) FROM get_in_touch
UNION ALL
SELECT 'group_calling_details', COUNT(*) FROM group_calling_details
UNION ALL
SELECT 'group_chat', COUNT(*) FROM group_chat
UNION ALL
SELECT 'group_members', COUNT(*) FROM group_members
UNION ALL
SELECT 'groups', COUNT(*) FROM groups
UNION ALL
SELECT 'individual_chat', COUNT(*) FROM individual_chat
UNION ALL
SELECT 'languages', COUNT(*) FROM languages
UNION ALL
SELECT 'manage_advertisement', COUNT(*) FROM manage_advertisement
UNION ALL
SELECT 'msg_limit_for_user_chat', COUNT(*) FROM msg_limit_for_user_chat
UNION ALL
SELECT 'privacy_policy', COUNT(*) FROM privacy_policy
UNION ALL
SELECT 'request_to_join', COUNT(*) FROM request_to_join
UNION ALL
SELECT 'revenue_management', COUNT(*) FROM revenue_management
UNION ALL
SELECT 'seen_msg', COUNT(*) FROM seen_msg
UNION ALL
SELECT 'subscription_plan', COUNT(*) FROM subscription_plan
UNION ALL
SELECT 'subscription_plan_old', COUNT(*) FROM subscription_plan_old
UNION ALL
SELECT 'terms_and_conditions', COUNT(*) FROM terms_and_conditions
UNION ALL
SELECT 'theme_colors', COUNT(*) FROM theme_colors
UNION ALL
SELECT 'themes', COUNT(*) FROM themes
UNION ALL
SELECT 'user_contact_files', COUNT(*) FROM user_contact_files
UNION ALL
SELECT 'user_contacts', COUNT(*) FROM user_contacts
UNION ALL
SELECT 'user_details', COUNT(*) FROM user_details
UNION ALL
SELECT 'user_profile_images', COUNT(*) FROM user_profile_images
UNION ALL
SELECT 'video_plan', COUNT(*) FROM video_plan
UNION ALL
SELECT 'voice_calling_details', COUNT(*) FROM voice_calling_details
UNION ALL
SELECT '✅ emoji_table (PRESERVED)', COUNT(*) FROM emoji_table
UNION ALL
SELECT '✅ emoji_tbl (PRESERVED)', COUNT(*) FROM emoji_tbl
UNION ALL
SELECT '✅ country_list (PRESERVED)', COUNT(*) FROM country_list;

-- ===================================================
-- SUMMARY
-- ===================================================

/*
WHAT THIS SCRIPT DOES:

✅ DELETES data from 32 tables:
   - All user data (user_details, user_contacts, etc.)
   - All chat data (individual_chat, group_chat, etc.)
   - All call records (calling_details, voice_calling_details, etc.)
   - All groups (groups, group_members, etc.)
   - All subscriptions and plans
   - All admin and advertisement data

❌ PRESERVES data in 3 tables:
   - emoji_table
   - emoji_tbl
   - country_list

HOW TO RUN:
1. Backup database first! (mysqldump or export)
2. Open MySQL/phpMyAdmin
3. Select your database (encdb)
4. Run this script
5. Verify row counts at the end

⚠️ WARNING: This is IRREVERSIBLE! Make sure to backup first!
*/
