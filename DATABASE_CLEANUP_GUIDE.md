# 🗑️ Database Cleanup Guide

## 🎯 What You Want

Delete all data from 35 tables **EXCEPT:**
- ✅ `emoji_table` (preserve)
- ✅ `emoji_tbl` (preserve)  
- ✅ `country_list` (preserve)

---

## ⚠️ CRITICAL WARNING

**This will DELETE ALL:**
- 👥 All users
- 💬 All chats (individual + group)
- 📞 All call records
- 👥 All groups
- 💰 All subscriptions
- 📸 All profile images
- 🚫 All blocked users
- 📊 Everything except emojis and countries

**THIS IS IRREVERSIBLE!**

---

## 🛡️ STEP 1: BACKUP FIRST! (REQUIRED!)

### Option A: Full Database Backup (RECOMMENDED)

**Run in terminal:**

```bash
# Backup entire database
mysqldump -u root -p encdb > encdb_backup_2026_02_11.sql

# Verify backup file created
ls -lh encdb_backup_2026_02_11.sql
```

**Or if using remote database:**

```bash
mysqldump -h your_server_ip -u your_username -p encdb > encdb_backup_2026_02_11.sql
```

---

### Option B: Use phpMyAdmin

1. Open phpMyAdmin
2. Select database `encdb`
3. Click **"Export"**
4. Choose **"Quick"** or **"Custom"**
5. Click **"Go"**
6. Save file: `encdb_backup_2026_02_11.sql`

---

## 🗑️ STEP 2: DELETE DATA

### Method 1: Using SQL File (Easy)

**I created:** `DELETE_DATABASE_DATA.sql`

**To run:**

1. **In terminal:**
   ```bash
   mysql -u root -p encdb < DELETE_DATABASE_DATA.sql
   ```

2. **Or in phpMyAdmin:**
   - Click **"SQL"** tab
   - Open `DELETE_DATABASE_DATA.sql` file
   - Copy all content
   - Paste and click **"Go"**

3. **Or in MySQL Workbench:**
   - Open `DELETE_DATABASE_DATA.sql`
   - Click **"Execute"** (⚡️ icon)

---

### Method 2: Manual Commands

**Copy and paste this:**

```sql
SET FOREIGN_KEY_CHECKS = 0;

-- User data
TRUNCATE TABLE user_details;
TRUNCATE TABLE user_profile_images;
TRUNCATE TABLE user_contacts;
TRUNCATE TABLE user_contact_files;

-- Chat data
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

-- Block
TRUNCATE TABLE block_user;
TRUNCATE TABLE blocked_contact_list;

-- Plans & Revenue
TRUNCATE TABLE business_profile_plan;
TRUNCATE TABLE subscription_plan;
TRUNCATE TABLE subscription_plan_old;
TRUNCATE TABLE video_plan;
TRUNCATE TABLE revenue_management;

-- Admin & Ads
TRUNCATE TABLE admin_advertisement;
TRUNCATE TABLE advertisement_plan;
TRUNCATE TABLE manage_advertisement;

-- App Content
TRUNCATE TABLE faq;
TRUNCATE TABLE get_in_touch;
TRUNCATE TABLE privacy_policy;
TRUNCATE TABLE terms_and_conditions;
TRUNCATE TABLE languages;

-- Theme
TRUNCATE TABLE themes;
TRUNCATE TABLE theme_colors;

-- ✅ PRESERVED (NOT deleted):
-- emoji_table - NOT TRUNCATED
-- emoji_tbl - NOT TRUNCATED
-- country_list - NOT TRUNCATED

SET FOREIGN_KEY_CHECKS = 1;
```

---

## ✅ STEP 3: VERIFY DELETION

**Run this to check:**

```sql
-- Check row counts
SELECT 'user_details' AS table_name, COUNT(*) AS rows FROM user_details
UNION ALL SELECT 'individual_chat', COUNT(*) FROM individual_chat
UNION ALL SELECT 'group_chat', COUNT(*) FROM group_chat
UNION ALL SELECT 'calling_details', COUNT(*) FROM calling_details
UNION ALL SELECT 'groups', COUNT(*) FROM groups
UNION ALL SELECT '✅ emoji_table (PRESERVED)', COUNT(*) FROM emoji_table
UNION ALL SELECT '✅ emoji_tbl (PRESERVED)', COUNT(*) FROM emoji_tbl
UNION ALL SELECT '✅ country_list (PRESERVED)', COUNT(*) FROM country_list;
```

**Expected results:**
- Most tables: `0 rows` ✅
- emoji_table: `X rows` (preserved) ✅
- emoji_tbl: `X rows` (preserved) ✅
- country_list: `X rows` (preserved) ✅

---

## 🔄 STEP 4: RESTORE IF NEEDED

**If you made a mistake, restore from backup:**

```bash
# Restore entire database
mysql -u root -p encdb < encdb_backup_2026_02_11.sql
```

---

## 📊 What Gets Deleted

| Category | Tables | Impact |
|----------|--------|--------|
| **Users** | user_details, user_profile_images, user_contacts | All users deleted |
| **Chats** | individual_chat, group_chat, deleted_messages | All messages deleted |
| **Calls** | calling_details, voice_calling_details, group_calling_details | All call history deleted |
| **Groups** | groups, group_members, request_to_join | All groups deleted |
| **Subscriptions** | subscription_plan, video_plan, revenue_management | All plans deleted |
| **Admin** | admin_advertisement, manage_advertisement | All ads deleted |
| **Settings** | faq, privacy_policy, terms_and_conditions | All content deleted |

---

## ✅ What Gets PRESERVED

| Table | Rows | Why Preserve |
|-------|------|--------------|
| **emoji_table** | ? | Emoji data (static) |
| **emoji_tbl** | ? | Emoji configurations |
| **country_list** | ~200 | Country codes & flags |

---

## 🎯 Quick Execution Steps

### In Terminal:

```bash
# 1. Backup first!
mysqldump -u root -p encdb > encdb_backup_2026_02_11.sql

# 2. Delete data
mysql -u root -p encdb < DELETE_DATABASE_DATA.sql

# 3. Verify
mysql -u root -p encdb -e "SELECT COUNT(*) FROM user_details;"
```

---

### In phpMyAdmin:

1. **Backup:** Export tab → Quick → Go
2. **Delete:** SQL tab → Paste DELETE script → Go
3. **Verify:** Browse tables → Check row counts

---

## ⚠️ Safety Checklist

Before running:
- [ ] Backup created and verified
- [ ] Confirmed you want to delete ALL data
- [ ] Confirmed emoji and country tables will be preserved
- [ ] Know how to restore from backup
- [ ] Tested backup file is valid

---

## 📝 Files Created For You

1. **`DELETE_DATABASE_DATA.sql`** - Deletes all data (preserves 3 tables)
2. **`BACKUP_DATABASE_FIRST.sql`** - Backup instructions
3. **`DATABASE_CLEANUP_GUIDE.md`** - This guide

---

## 🚀 Quick Summary

**To delete all data:**

```bash
# Step 1: Backup
mysqldump -u root -p encdb > backup.sql

# Step 2: Delete
mysql -u root -p encdb < DELETE_DATABASE_DATA.sql

# Step 3: Done!
```

**Result:**
- 32 tables: Empty (0 rows)
- 3 tables: Preserved (emoji_table, emoji_tbl, country_list)

---

## 💡 Alternative: Delete Via phpMyAdmin GUI

1. Login to phpMyAdmin
2. Select `encdb` database
3. For each table (except emoji_table, emoji_tbl, country_list):
   - Click table name
   - Click **"Operations"** tab
   - Scroll down
   - Click **"Empty the table (TRUNCATE)"**
   - Click **"OK"**

**Repeat 32 times for each table!** (SQL script is faster!)

---

**Ready to proceed? Make sure to backup first!** 🛡️

**Want me to help you run the backup or deletion?**