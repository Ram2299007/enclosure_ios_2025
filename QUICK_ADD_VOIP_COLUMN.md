# ⚡ Quick Command - Add VoIP Token Column

## 🚀 Copy and Paste This:

```sql
ALTER TABLE user_details 
ADD COLUMN voip_token VARCHAR(255) NULL 
COMMENT 'iOS VoIP Push token for instant CallKit';
```

---

## ✅ Verify It Was Added:

```sql
DESCRIBE user_details;
```

**Look for:**
```
+-------------+--------------+------+-----+---------+-------+
| Field       | Type         | Null | Key | Default | Extra |
+-------------+--------------+------+-----+---------+-------+
| ...         | ...          | ...  | ... | ...     | ...   |
| voip_token  | varchar(255) | YES  |     | NULL    |       | ← Should see this!
+-------------+--------------+------+-----+---------+-------+
```

---

## 📊 Now Your Table Has Both Tokens:

```
user_details:
┌─────┬────────┬─────────────────┬─────────────────────────────┐
│ uid │ name   │ fcm_token       │ voip_token                  │
├─────┼────────┼─────────────────┼─────────────────────────────┤
│ 2   │ Ram    │ cWXCYutVCE...  │ 416951db5bb2d8dd...         │
│     │        │ ↑ Chat साठी    │ ↑ Calls साठी               │
└─────┴────────┴─────────────────┴─────────────────────────────┘
```

---

## 🎯 Next Steps After Adding Column:

### 1. Test Insert (Optional):
```sql
INSERT INTO user_details (uid, name, fcm_token, voip_token) 
VALUES (
    '2',
    'Ram',
    'cWXCYutVCEItm9JpJbkVF1:APA91bGaFHMHBxp0ZFnlyWvza1-Lzt_rmX0YaiGEOFctOt8tFjsk1go38OfdCYaMI0GBLjxf9D8s3V0MBJM-6K75gEPKJ1bA543c7fmyZJDNGPlzoge0LFE',
    '416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6'
);
```

### 2. Verify:
```sql
SELECT uid, name, fcm_token, voip_token FROM user_details;
```

### 3. Update Backend Code:

Replace hardcoded token with database lookup:

**Before:**
```java
String voipToken = "416951db5bb2d8dd..."; // ❌ Hardcoded
```

**After:**
```java
String voipToken = getVoIPTokenFromDatabase(receiverId); // ✅ Dynamic
```

---

**Run the ALTER TABLE command now!** 🚀
