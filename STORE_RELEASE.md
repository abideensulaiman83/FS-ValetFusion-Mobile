# Publishing Valet Fusion to Google Play and the App Store

Checklist for whoever builds and uploads a store release. The app is one Flutter codebase
(`mobile/`); Android builds on Windows, iOS needs a Mac.

## Identity (permanent once published)

| | Android | iOS |
|---|---|---|
| App ID | `com.focalsoft.fsvalet.fs_valetfusion` | `com.focalsoft.fsvalet.valetfusion` (iOS forbids `_`) |
| Name | Valet Fusion | Valet Fusion |
| Firebase project | `limousine-service-3f79c` (Android app registered) | same project, **iOS app not registered yet** |

Never change either ID after the first upload - it becomes a different app.

## Before every release

1. Bump `version:` in `pubspec.yaml` - `1.0.0+1` → `1.0.1+2`. The number after `+` must go up for
   every Play / App Store upload.
2. Replace the placeholder icon if the official logo is ready: put a 1024×1024 PNG (no
   transparency) at `assets/icon/app_icon.png` (and a transparent version at
   `assets/icon/app_icon_foreground.png`), then run `dart run flutter_launcher_icons`.
3. Check `AuthenticationService.apiBaseUrl` points at the production server.

## Android (Google Play)

Build (on the machine that has the upload key):

```
flutter build appbundle --release      # -> build/app/outputs/bundle/release/app-release.aab (upload this)
flutter build apk --release            # -> test APK for sideloading
```

**Upload key.** `android/key.properties` (git-ignored) points at
`C:\Users\abide\keystores\valetfusion-upload.jks`. Without that file, release builds are signed
with the debug key and Play rejects them. **Back up the .jks and key.properties** (password
manager / secure drive). With Play App Signing, a lost upload key can be reset through Play
support, but it takes days.

**Play Console, first time:**

- Create app → name "Valet Fusion", free, app.
- Release → Production (or Internal testing first) → upload the `.aab`. Accept **Play App Signing**.
- Store listing: icon 512×512 (`assets/icon/play_store_512.png`), feature graphic 1024×500,
  at least 2 phone screenshots, short and full description.
- App content:
  - Privacy policy: `https://valetfusion.focalsoft.ae/privacy`
  - Account deletion: `https://valetfusion.focalsoft.ae/account-deletion` (in-app: My Valet → ⋮ →
    Delete my account)
  - App access: give reviewers a **test customer and a test driver login** - the app is
    login-only and review fails without them.
  - Data safety (collected, not shared, not sold, encrypted in transit):
    name, phone number, email (account management); precise location (app functionality -
    driver's position during delivery, customer's nearest property); photos (vehicle photo for
    plate recognition); device or other IDs (push token).
  - **Foreground service declaration**: type *location* - "Driver's position is shared with the
    guest while a car is being delivered, so the guest can follow it on a map." Play asks for a
    short video of the flow.
  - Content rating questionnaire, target audience (18+ / business), ads: none.
- The app deliberately has **no** `USE_FULL_SCREEN_INTENT` or `ACCESS_BACKGROUND_LOCATION`;
  both would need extra Play declarations it doesn't qualify for.

## iOS (App Store) - needs a Mac with Xcode

One-time:

1. Apple Developer Program account (paid, yearly). Register the bundle ID
   `com.focalsoft.fsvalet.valetfusion` with **Push Notifications** capability.
2. Firebase console (`limousine-service-3f79c`) → Add app → iOS, bundle ID as above → download
   `GoogleService-Info.plist` → drag it into `ios/Runner` in Xcode (target Runner).
3. Apple Developer → Keys → create an **APNs key** (.p8) → upload it in Firebase → Project
   settings → Cloud Messaging → Apple app configuration. Without it iPhones get no pushes.
4. Xcode → Runner → Signing & Capabilities: select the team; add **Push Notifications** and
   **Background Modes** (Location updates, Remote notifications - already in Info.plist).

Build and upload:

```
flutter build ipa --release           # then upload build/ios/ipa/*.ipa with Transporter or Xcode
```

App Store Connect: privacy policy URL as above, App Privacy answers matching the Play data-safety
list, a reviewer demo account, and in the review notes explain the background location ("shared
only while a driver is delivering a car to the guest, blue indicator shown").

Without `GoogleService-Info.plist` the iOS app still runs - it just has no push.
