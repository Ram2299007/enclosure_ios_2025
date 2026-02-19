-- ===================================================
-- ADD VOIP_TOKEN COLUMN TO user_details TABLE
-- ===================================================

-- Add voip_token column to store iOS VoIP Push tokens
ALTER TABLE user_details 
ADD COLUMN voip_token VARCHAR(255) NULL 
COMMENT 'iOS VoIP Push token for instant CallKit notifications';

-- Optional: Add index for faster lookups
CREATE INDEX idx_voip_token ON user_details(voip_token);

-- ===================================================
-- VERIFY COLUMN ADDED
-- ===================================================

-- Show table structure
DESCRIBE user_details;

-- Or use this:
SHOW COLUMNS FROM user_details LIKE 'voip_token';

-- ===================================================
-- SAMPLE DATA (for testing)
-- ===================================================

-- Example: Insert test user with both FCM and VoIP tokens
/*
INSERT INTO user_details (uid, name, fcm_token, voip_token) 
VALUES (
    '2',
    'Ram',
    'cWXCYutVCEItm9JpJbkVF1:APA91bGaFHMHBxp0ZFnlyWvza1-Lzt_rmX0YaiGEOFctOt8tFjsk1go38OfdCYaMI0GBLjxf9D8s3V0MBJM-6K75gEPKJ1bA543c7fmyZJDNGPlzoge0LFE',
    '416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6'
);
*/

-- ===================================================
-- USAGE EXAMPLES
-- ===================================================

-- Update VoIP token for specific user
-- UPDATE user_details SET voip_token = '416951db5bb2d8dd836060f8deb6725e049e048c1f41669b9f8fc94500b689e6' WHERE uid = '2';

-- Get VoIP token for a user
-- SELECT voip_token FROM user_details WHERE uid = '2';

-- Check which users have VoIP tokens registered
-- SELECT uid, name, voip_token FROM user_details WHERE voip_token IS NOT NULL;

-- ===================================================
-- NOTES
-- ===================================================

/*
VoIP Token vs FCM Token:

FCM Token (for chat messages):
- Format: cWXCYutVCE:APA91bGaF... (has colons and special chars)
- Used for: Chat messages, regular notifications
- Works for: Both Android and iOS
- Stored in: fcm_token column

VoIP Token (for voice/video calls):
- Format: 416951db5bb2d8dd836060f8deb6725e... (64 hex characters)
- Used for: Voice calls, Video calls - Instant CallKit
- Works for: iOS only
- Stored in: voip_token column (NEW)

Both tokens are needed for iOS users!
*/
