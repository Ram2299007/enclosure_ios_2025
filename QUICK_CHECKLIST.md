# CallKit Fix - Quick Checklist

## Phase 1: iOS Code (DONE ✅)

- [x] Remove `RemoteNotificationSceneDelegate` class
- [x] Remove custom scene configuration
- [x] Use default SwiftUI scene management
- [x] Create documentation files

## Phase 2: Build & Test iOS (DO THIS NOW)

### Build:
- [ ] Clean Derived Data: `rm -rf ~/Library/Developer/Xcode/DerivedData/Enclosure-*`
- [ ] Xcode: Product > Clean Build Folder (Cmd+Shift+K)
- [ ] Xcode: Product > Build (Cmd+B)
- [ ] Install on **physical device** (CallKit doesn't work in simulator)

### Test 1: Foreground (Should Work NOW)
- [ ] Open app and keep in foreground
- [ ] Send voice call notification from backend
- [ ] ✅ PASS: CallKit full-screen UI appears immediately
- [ ] ✅ PASS: No notification banner
- [ ] ❌ FAIL: If banner appears, check Console logs for errors

### Test 2: Background + Tap (Should Work NOW)
- [ ] Minimize app (press Home button)
- [ ] Send voice call notification from backend
- [ ] Notification banner appears (expected)
- [ ] Tap the notification banner
- [ ] ✅ PASS: CallKit full-screen UI appears
- [ ] ❌ FAIL: If app just opens without CallKit, check Console logs

### Test 3: Killed App (WILL FAIL - Needs Backend Fix)
- [ ] Swipe away app completely
- [ ] Send voice call notification from backend
- [ ] ⚠️ EXPECTED: Regular banner appears (NOT CallKit)
- [ ] **This is expected** - Backend needs to send silent push

### Check Console Logs:
- [ ] Open Console.app on Mac
- [ ] Window > Devices
- [ ] Select iPhone
- [ ] Click "Open Console"
- [ ] Filter: "Enclosure"
- [ ] Look for 🚨 📞 ✅ markers
- [ ] Verify no ❌ errors

## Phase 3: Backend Team (TODO)

- [ ] Share `BACKEND_FIX_REQUIRED.md` with backend team
- [ ] Backend team removes `notification.title` and `notification.body`
- [ ] Backend team removes `aps.alert`, `aps.sound`, `aps.category`
- [ ] Backend team keeps only `aps.content-available = 1`
- [ ] Backend team keeps all `data` fields
- [ ] Backend deploys changes to test environment

## Phase 4: Full Integration Test (AFTER Backend Fix)

### Test ALL THREE States:
- [ ] **Foreground**: Send notification → CallKit appears ✅
- [ ] **Background**: Send notification → CallKit appears ✅  
- [ ] **Killed**: Send notification → CallKit appears ✅

### Verify:
- [ ] No notification banners appear
- [ ] CallKit UI shows caller name correctly
- [ ] "Accept" button answers call
- [ ] "Decline" button rejects call
- [ ] No default notification sound
- [ ] App navigates to voice call screen on accept

## Phase 5: Production Checklist

- [ ] All test scenarios pass
- [ ] QA sign-off received
- [ ] No regressions in chat notifications
- [ ] Backend changes deployed to production
- [ ] iOS app submitted to App Store (if needed)
- [ ] Monitor crash logs for 24 hours
- [ ] Monitor user feedback

## Quick Issue Resolution

### If Foreground Test Fails:
1. Check Console for `🚨 [NotificationDelegate] willPresent`
2. If not present, delegate not set properly
3. Verify `UNUserNotificationCenter.current().delegate = NotificationDelegate.shared`
4. Rebuild and retry

### If Background Tap Fails:
1. Check Console for `📱 [NotificationDelegate] User tapped notification`
2. If not present, UNNotificationResponse not being received
3. Check notification category is "VOICE_CALL"
4. Rebuild and retry

### If Killed App Doesn't Work:
1. **This is expected** until backend sends silent push
2. Check with backend team on timeline for fix
3. Can proceed with foreground/background testing

## Documentation Reference

| Question | See File |
|----------|----------|
| What changed in the code? | `CALLKIT_FIX_SUMMARY.md` |
| How to test? | `TEST_CALLKIT_NOW.md` |
| What backend needs to change? | `BACKEND_FIX_REQUIRED.md` |
| Technical details? | `NOTIFICATION_DELIVERY_DIAGNOSIS.md` |
| Quick overview? | This file |

## Status Dashboard

| Component | Status | Notes |
|-----------|--------|-------|
| iOS Code | ✅ DONE | Scene delegate removed |
| iOS Build | ⏳ TODO | Need to test |
| Foreground | ⏳ TODO | Should work now |
| Background | ⏳ TODO | Should work now |
| Killed App | ⏳ BLOCKED | Waiting for backend |
| Backend Code | ⏳ TODO | Needs silent push |
| QA Testing | ⏳ TODO | After backend fix |
| Production | ⏳ TODO | After all tests pass |

## Next Actions (Right Now)

1. **Clean build the project** (see Phase 2 above)
2. **Install on physical device**
3. **Test foreground scenario**
4. **Test background + tap scenario**
5. **Share results** (take screenshots of Console logs)
6. **Contact backend team** with `BACKEND_FIX_REQUIRED.md`

## Expected Timeline

- ✅ **Today**: iOS code complete, initial testing (foreground, background)
- ⏳ **This Week**: Backend implements silent push
- ⏳ **Next Week**: Full integration testing
- ⏳ **Following Week**: Production deployment

---

**Last Updated**: 2026-02-09  
**iOS Code Status**: ✅ Complete  
**Backend Status**: ⏳ Pending  
**Overall Status**: 🔄 In Progress (60% complete)
