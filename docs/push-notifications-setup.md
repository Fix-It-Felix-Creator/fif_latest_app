# Push Notifications — Native Setup

Complete the platform-level setup below **before** testing pushes. The
Flutter/backend code is already wired; what remains is Apple + Google
console configuration.

---

## 1. Android

The repo already includes:
- `firebase_messaging: ^16.0.3` in `pubspec.yaml`
- `POST_NOTIFICATIONS` permission in `AndroidManifest.xml`
- Default FCM notification channel + icon meta-data in the manifest
- `google-services.json` in `android/app/` (from the fifcloud Firebase
  project)

No further Android console action is needed. Fresh installs on Android 13+
will prompt the user for notification permission on first launch via
`PushNotificationsService.initialise()`.

### Custom notification icon (optional)

Android only uses the alpha channel of the notification icon. The current
fallback is `@mipmap/ic_launcher` which will render as a white square on
the status bar. To fix:

1. Generate a white, transparent-background icon at
   `android/app/src/main/res/drawable-xxhdpi/ic_stat_notification.png`
   (and other DPIs).
2. Change the manifest meta-data:
   ```xml
   android:name="com.google.firebase.messaging.default_notification_icon"
   android:resource="@drawable/ic_stat_notification"
   ```

---

## 2. iOS

iOS push requires four things. Do them in order.

### 2a. APNs auth key (Apple Developer Portal)

1. [developer.apple.com](https://developer.apple.com) → Certificates,
   Identifiers & Profiles → **Keys**.
2. **+** → name it "Fix It Felix Pro APNs" → tick **Apple Push Notifications
   service (APNs)** → Continue → Register.
3. **Download** the `.p8` file — you only get one chance.
4. Note the **Key ID** (10-char alphanumeric) and your **Team ID** (top
   right on the portal).

### 2b. Upload to Firebase Console

1. Firebase Console → `fifcloud` → ⚙ Project Settings → **Cloud Messaging**.
2. Under **Apple app configuration** for the iOS bundle
   (`com.techkushx.fixitfelixpro`) → **Upload** the APNs auth key.
3. Enter Key ID and Team ID.

### 2c. Xcode capabilities

Open `ios/Runner.xcworkspace`. Select the **Runner** target:

1. **Signing & Capabilities** → **+ Capability**:
   - **Push Notifications**
   - **Background Modes** → tick **Remote notifications**
2. Verify `Runner.entitlements` now contains
   `aps-environment = development` (Debug) / `production` (Release).
3. Keep automatic signing on; Xcode will regenerate the provisioning
   profile with push entitlement attached.

### 2d. Rebuild

```bash
cd fixitfelixpro
flutter clean
cd ios && pod install && cd ..
flutter run   # iOS physical device — simulator cannot receive pushes
```

On first run the user sees the permission prompt. Accept → the app
persists the token under `/users/{uid}/fcmTokens/{key}` in RTDB.

---

## 3. Verifying the full flow

1. On a signed-in device, open **Firebase Console → Realtime Database →
   `/users/{uid}/fcmTokens/`** — you should see one record per device
   with `{ token, platform, createdAt, lastSeenAt }`.
2. Send a test notification via admin endpoint or direct CLI (see
   `admin-panel-notifications.md`).
3. Response should include `{ pushSent: N, pushFailed: 0 }`.
4. Physical device — if app is **backgrounded** or **closed**, the OS
   banner appears. If **foregrounded**, the bell badge updates and
   (iOS only) a small banner appears due to
   `setForegroundNotificationPresentationOptions`.
5. Tapping a background/closed push opens the app → navigates to
   `/notifications` (or a deep-link route if `payload.route` is set).

---

## 4. Troubleshooting

| Symptom                                   | Fix                                                                                      |
| ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| `pushFailed: N` matches `pushSent + N`    | Token rows exist but APNs / Play Services can't deliver. Check steps 2a–2c.             |
| iOS device never shows token in RTDB      | Permission dialog dismissed. Settings → Notifications → Fix It Felix Pro → enable.      |
| Android notifications silent              | App has been denied notification permission. Settings → Apps → Fix It Felix Pro → Notifications → enable. |
| Foreground push not shown on Android      | Default Android behaviour — rely on the in-app bell badge. Use `flutter_local_notifications` if a banner is needed. |
| `registration-token-not-registered`       | Expected — backend auto-removes stale tokens from RTDB on next send.                    |
| Simulator never receives a push           | iOS simulator cannot — use a physical device. Android emulator works if Play Services is up to date. |

## 5. What the backend sends

`functions/src/notifications/send.ts` attaches the following payload to
every FCM message:

```ts
{
  notification: { title, body, imageUrl? },
  data: { type, ...payload (stringified) },
  android: { priority: "high", notification: { channelId: "default", imageUrl? } },
  apns:    { payload: { aps: { sound: "default", badge: 1, "mutable-content": 1 } }, fcmOptions: { imageUrl? } }
}
```

The same record that powers the in-app list is also pushed natively, so
users see the alert immediately AND find it archived in the Notifications
screen when they open the app.
