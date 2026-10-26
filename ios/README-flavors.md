# iOS flavours (production / staging)

The bundle id and display name come from xcconfig variables (`ios/Flutter/Environment*.xcconfig`),
so the same Xcode project builds both apps:

| Flavour | Bundle id | Name | Server |
|---|---|---|---|
| production (default) | `com.focalsoft.fsvalet.valetfusion` | Valet Fusion | valetfusion.focalsoft.ae |
| staging | `com.focalsoft.fsvalet.valetfusion.staging` | Valet Fusion STG | stvf.focalsoft.ae |

## One-time Xcode setup for the staging flavour (needs a Mac, ~5 minutes)
Flutter's `--flavor staging` expects a scheme called **staging** whose build configurations are
`Debug-staging`, `Release-staging`, `Profile-staging`.
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Project **Runner** → Info → Configurations: duplicate *Debug*, *Release*, *Profile* and name them
   `Debug-staging`, `Release-staging`, `Profile-staging`. For each `-staging` configuration set the
   **Runner** target's configuration file to `Flutter/Environment-staging.xcconfig`
   (and `Pods-Runner.*` to the matching pods xcconfig after `pod install`).
3. Product → Scheme → Manage Schemes → duplicate *Runner* as **staging**; in its Run/Archive/Profile
   actions pick the `-staging` configurations.
4. Firebase: add the iOS app `com.focalsoft.fsvalet.valetfusion.staging` to the **staging** Firebase
   project, download `GoogleService-Info.plist` into `ios/config/staging/`; production's into
   `ios/config/production/`. A Run Script build phase copies the right one into the bundle
   (`cp "${SRCROOT}/config/${VF_FLAVOR:-production}/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/"`).
5. Commit the `.pbxproj` and `.xcscheme` changes.

## Builds
```
flutter build ipa --flavor production --dart-define=VF_ENV=production   # App Store / TestFlight
flutter build ipa --flavor staging    --dart-define=VF_ENV=staging      # TestFlight internal (staff)
```
Until the staging scheme exists, `flutter build ipa` (no flavour) still produces the production app.
