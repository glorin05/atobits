# Atobits Habit Tracker – Release & Distribution Guide

**Version:** 1.1.0+2  
**Release Date:** April 13, 2026

---

## Quick Start

### Prerequisites
- Flutter SDK (3.0+) installed and configured
- Android SDK / Java Development Kit (JDK 17+)
- Release keystore: `android/release.keystore` (already generated)

### Build Release APK

```bash
# From project root
cd c:\Users\glori_za0wp11\Desktop\Emora Mental APP\havbits

# Clean build artifacts
flutter clean

# Fetch dependencies
flutter pub get

# Build release APK (unsigned)
flutter build apk --release

# Or build release APK bundle for Play Store
flutter build appbundle --release
```

**Output:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle (AAB): `build/app/outputs/bundle/release/app-release.aab`

### Signing Configuration

The app is already configured with signing credentials in `android/app/build.gradle.kts`:

```
signingConfigs {
  create("release") {
    keyAlias = "atobits"
    keyPassword = "atobits2024!"
    storeFile = file("../release.keystore")
    storePassword = "atobits2024!"
  }
}
```

**Important**: This is suitable for beta testing and direct distribution. For production Play Store releases, consider:
- Using a password manager to store credentials
- Rotating the keystore password every 6 months
- Using Play Console's internal app signing for additional security

---

## Distribution Methods

### Method 1: Direct APK Share (Fastest for Friends)

1. **Build the APK:**
   ```bash
   flutter build apk --release
   ```

2. **Locate the APK:**
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Share via:**
   - Email attachment
   - Cloud storage (Google Drive, OneDrive)
   - Messaging app (WhatsApp, Telegram)
   - QR code (encode APK download URL)

4. **Friend Installation:**
   - Download APK to Android device
   - Enable "Install from Unknown Sources" in Settings → Security
   - Tap APK file to install

### Method 2: Firebase App Distribution (Recommended)

1. **Set up Firebase:**
   ```bash
   flutter pub add firebase_core
   ```

2. **Configure in Firebase Console** (https://console.firebase.google.com):
   - Create project → Android app
   - Download `google-services.json` → place in `android/app/`

3. **Build & distribute:**
   ```bash
   flutter build apk --release
   # Upload via Firebase CLI or Console
   ```

### Method 3: Google Play Store (Official Release)

1. **Prepare metadata** (for Play Console):
   - App title: "Atobits Habit Tracker"
   - Description: "Build better habits, one day at a time"
   - App icon: `android/app/src/main/res/`
   - Screenshots: Minimum 2 per language
   - Privacy Policy: Link to `PRIVACY_POLICY.md`
   - Terms of Service: Link to `TERMS_OF_SERVICE.md`

2. **Create App Bundle:**
   ```bash
   flutter build appbundle --release
   ```

3. **Upload to Play Console:**
   - Sign in to [Google Play Console](https://play.google.com/console)
   - Create app → Upload bundle
   - Configure pricing, categorization, target content rating
   - Submit for review (review takes ~24-48 hours)

---

## Pre-Release Checklist

### Code & Functionality
- [ ] All AI automation actions tested (add, complete, delete, update, plan)
- [ ] AI Coach Proxy responds gracefully when Groq is unavailable
- [ ] Habit scroll fix validated (no stuck scrolling)
- [ ] Chat history loads without errors
- [ ] Theme toggle works (light/dark mode)
- [ ] All icon keys render correctly

### Security
- [ ] `android/release.keystore` exists and is secured
- [ ] No hardcoded API keys in source code
- [ ] Coach API URL and token passed via environment variables
- [ ] Privacy Policy readable in-app or via link
- [ ] Terms of Service accessible to users

### Metadata
- [ ] Version bumped to 1.1.0+2 in `pubspec.yaml`
- [ ] `PRIVACY_POLICY.md` created and reviewed
- [ ] `TERMS_OF_SERVICE.md` created and reviewed
- [ ] `README.md` includes deployment instructions
- [ ] Coach proxy README.md documents API contract

### Device Testing
- [ ] Tested on at least one physical Android device
- [ ] Tested on Android emulator with API level 24+
- [ ] Low-storage scenario tested (< 50MB free)
- [ ] Network failure scenario tested (offline mode)
- [ ] Habit creation, completion, and deletion tested

### API & Proxy
- [ ] Cloudflare Worker deployed and live
- [ ] Worker endpoint accessible: `https://atobits-coach-proxy.atobits.workers.dev`
- [ ] Bearer token validated in worker code
- [ ] Fallback coaching triggered when Groq fails
- [ ] Groq API key rotated (not exposed in git history)

---

## Friend Distribution Instructions

Share this with friends when distributing the APK:

### Installation

1. **Download Atobits APK file** (send them the APK or share the download link)
2. **Enable unknown sources** (Android 12 and below):
   - Settings → Security → Unknown Sources → Enable
3. **Install the APK**:
   - Open your file manager → Navigate to downloaded APK
   - Tap to install → Grant permissions
4. **Launch the app** and start creating habits!

### Using AI Coach (Optional)

To unlock AI-powered habit suggestions:

1. **Notify the app admin** that you'd like to use the AI Coach feature
2. **Receive these credentials** (via secure channel):
   - Coach API URL: `https://atobits-coach-proxy.atobits.workers.dev`
   - Bearer Token: (unique per user or shared group key)
3. **Launch the app** with environment variables:
   ```bash
   # PowerShell example
   $env:COACH_API_URL="https://atobits-coach-proxy.atobits.workers.dev"
   $env:COACH_API_TOKEN="<your-token-here>"
   flutter run -d <device-id>
   ```
4. **Open the AI Coach** (chat tab) and start chatting!

### Without AI Coach

The app works **fully offline** and locally:
- Create, edit, and complete habits
- Track daily progress and streaks
- Switch between light and dark themes
- No internet required
- No account needed

---

## Troubleshooting

### Build Fails with "Module not found"
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### APK Installation Fails on Device
- Ensure Android API level 24+ (Android 7.0+)
- Check device storage (needs ~50MB)
- Uninstall previous versions first

### AI Coach Not Responding
- Verify Coach API URL is reachable: `curl https://atobits-coach-proxy.atobits.workers.dev`
- Confirm bearer token is correct in launch environment
- Check Groq account has available credits
- (Fallback coaching will still work if Groq is unreachable)

### Habit Data Not Syncing (Multi-Device)
**Note:** Atobits stores data **locally on each device** only. To sync habits across devices:
- Manually export/import via backup mechanism (planned for v2.0)
- OR maintain separate habit lists per device

---

## Version History

### v1.1.0 (Apr 13, 2026)
- ✅ Added extended AI automation actions (complete, delete, update, plan_day)
- ✅ Fixed home screen scroll lock
- ✅ Released Privacy Policy and Terms of Service
- ✅ Generated release keystore for APK signing
- ✅ Validated proxy-based architecture for secure API deployment

### v1.0.0 (Initial Release)
- Habit creation, tracking, and statistics
- AI Coach with Groq integration
- Light and dark theme support
- Local habit persistence

---

## Security Notes for Self-Hosting Proxy

If you maintain the `coach-proxy` Cloudflare Worker:

1. **Rotate Groq API Key** every 6 months:
   - Generate new key in Groq dashboard
   - Update secret in Cloudflare: `wrangler secret put GROQ_API_KEY`

2. **Rotate Bearer Token** if compromised:
   - Generate new random token (min 32 bytes)
   - Update in worker: `wrangler secret put COACH_API_TOKEN`
   - Notify users to use new credentials

3. **Monitor Usage**:
   - Check Groq dashboard for unusual API calls
   - Set spending limits in Groq account → Billing

4. **Backup Config**:
   - Keep `wrangler.toml` in secure git repo (secrets not stored there)
   - Document all deployed secrets in a password manager

---

## FAQ

**Q: Can I share the APK without modifying it?**  
A: Yes! The APK works **offline** without any API keys embedded. Share it freely.

**Q: Do users need to create accounts?**  
A: No. Atobits is fully local; no accounts or sign-in required.

**Q: Can the app sync habits across multiple devices?**  
A: Not yet. Each device maintains its own local habit database. Cross-device sync is planned for v2.0.

**Q: Is the app open-source?**  
A: Check the repository README.md for licensing information.

**Q: What happens if I forget my Groq API key?**  
A: The app still works in **local offline mode**. AI Coach just won't be available until you reconfigure the proxy.

---

**For additional support**, refer to:
- [coach-proxy/README.md](coach-proxy/README.md) – Proxy backend documentation
- [PRIVACY_POLICY.md](PRIVACY_POLICY.md) – Privacy and data handling
- [TERMS_OF_SERVICE.md](TERMS_OF_SERVICE.md) – Legal terms
- Main [README.md](README.md) – Project overview
