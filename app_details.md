# Atobits — App Details

This file tracks notable reliability, UX, and product improvements made to the app.

## Improvements

### Notifications reliability (Android)
- Made habit reminder scheduling more robust (timezone-aware scheduling + safer fallback behavior when exact alarms are restricted).
- Ensured reminders can be restored after device reboot / app updates (rescheduling support).
- Added a battery-optimization exemption flow to reduce dropped/late reminders on aggressive Android devices.

### Notifications settings UX
- Simplified the Notifications screen to user-facing actions only (enable notifications + allow unrestricted battery), removing diagnostic/troubleshooting sections from the main UI.

### Meditation voice (TTS)
- Improved meditation pacing (punctuation-aware pauses for more natural speech).
- Simplified voice selection to a small set of named voice options (instead of many controls).

### Home → Analytics
- Home “Today’s Progress” now opens Analytics.

### Atom (AI head coach)
- Renamed the in-app AI head coach to “Atom”.
- Added push-to-talk voice input inside the Atom chat.
- Atom now talks back for voice interactions (TTS): talk → Atom replies out loud.
- Voice input no longer fills the text box (so it feels like an assistant, not dictation).
- Typed messages remain text-only.
- Added a dedicated Voice Mode interface in Atom:
  - Voice-only interaction layout with live transcript bubbles for both user and Atom.
  - Gemini-Live inspired dark blue flowing glow background (linear-based layers; no radial turn effect).
  - Turn-taking now changes glow intensity/motion instead of switching to radial gradient.
  - Voice Mode can be toggled from the Atom app bar and can auto-start listening when opened from Home.
- Removed the mic button from the normal typed chat composer; voice controls are now in Voice Mode.
- Refined Voice Mode to be immersive and cleaner:
  - Full-screen voice UI (app bar hidden while in Voice Mode).
  - Minimal top status and clearer transcript glass panel.
  - Dedicated bottom live controls (pause/resume mic + end voice mode) similar to assistant-call UX.
- Voice transcript panel now auto-collapses when idle and auto-expands during active speaking/thinking turns.
- Opening Atom chat no longer auto-turns on the microphone.
- Improved voice input reliability: voice text is submitted when you stop listening.
- Fixed microphone permission handling: now properly requests runtime microphone permission on Android.
- Expanded Atom automation to support reminder updates (via `update_habit`) and opening Analytics.
- Removed the fixed “How I feel / Suggest a habit / Plan my day” chips (they felt repetitive/pointless when AI wasn’t configured).
- Improved the “AI configuration missing” experience: Atom now switches to a usable offline mode for basic habit tasks instead of repeatedly failing.
- Removed the in-chat “AI isn’t connected” messaging (keeps the experience clean).
- Made AI work out-of-the-box in debug/profile runs (uses the pre-configured coach proxy by default).
- Reduced the amount of chat history sent to the LLM (uses recent context only) to improve response speed.

### Analytics (overall + per-habit)
- Refreshed the Analytics UI to match the app theme.
- Added graphs:
  - Overall completion chart (weekly/monthly/yearly).
  - Per-habit progress chart (weekly/monthly/yearly).

### Account
- Improved scroll smoothness (consistent scroll physics + enough bottom padding so content isn’t constrained by the floating bottom nav overlay).

## Notes / Follow-ups
- If you want the in-app version label to match `pubspec.yaml`, we can sync the displayed version text in the Account/About section.
