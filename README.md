<div align="center">
  <h1>🧠 Atobits</h1>
  <p><strong>AI-Powered Habit Tracker with Voice Coach</strong></p>

  <p>
    <img src="https://img.shields.io/badge/version-1.1.0-blue?style=flat-square"/>
    <img src="https://img.shields.io/badge/platform-Android-green?style=flat-square&logo=android"/>
    <img src="https://img.shields.io/badge/Flutter-3.x-blue?style=flat-square&logo=flutter"/>
    <img src="https://img.shields.io/badge/AI-Groq%20%2B%20Llama%203.1-orange?style=flat-square"/>
    <img src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square"/>
  </p>

  <p>
    <a href="https://github.com/glorin05/atobits/releases/latest">
      <img src="https://img.shields.io/badge/⬇️%20Download%20APK-v1.1.0-brightgreen?style=for-the-badge"/>
    </a>
  </p>
</div>

---

## Overview

Atobits is a premium, offline-first Flutter habit tracker 
with an integrated AI life coach named **Atom**. Built with 
a Notion-inspired design system — warm neutrals, whisper-thin 
borders, glassmorphic navigation, and the Urbanist font family.

> No account required. No Firebase. All your data stays on 
> your device.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🤖 **Atom AI Coach** | LLM-powered coach — text chat + full Voice Mode (push-to-talk, TTS replies) |
| 📊 **Analytics** | Weekly, monthly, and yearly completion charts per habit |
| 🧘 **Meditation** | Guided TTS meditation sessions with pacing control |
| 📔 **Journal** | Daily reflection and journaling screen |
| 🔔 **Smart Reminders** | Timezone-aware notifications with battery optimization |
| 🌙 **Dark/Light Mode** | Full theme support |
| 📴 **Offline First** | No internet required — fully local storage |
| ⚡ **Quick Actions** | Home screen shortcuts for Add Habit and Voice Coach |

---

## 📱 Download

| APK | Device |
|-----|--------|
| [arm64-v8a ✅ Recommended](https://github.com/glorin05/atobits/releases/latest) | Most modern Android phones |
| [armeabi-v7a](https://github.com/glorin05/atobits/releases/latest) | Older Android devices |
| [x86_64](https://github.com/glorin05/atobits/releases/latest) | Emulators only |

**Requirements:** Android 6.0+ — Enable "Install from unknown 
sources" in your device settings before installing.

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.x (Dart ≥3.0) |
| **State** | Provider (ChangeNotifier pattern) |
| **Storage** | SharedPreferences — fully offline |
| **AI Backend** | Groq API (Llama 3.1 8B) via Cloudflare Workers proxy |
| **Voice** | speech_to_text + flutter_tts |
| **Notifications** | flutter_local_notifications + timezone |
| **UI** | Urbanist font, Glassmorphism, Notion-inspired design |
| **Backend Proxy** | Cloudflare Workers (keeps API keys server-side) |

---

## 🚀 Build From Source

### Prerequisites
- Flutter 3.x
- Dart SDK ≥3.0
- Free Groq API key — [console.groq.com](https://console.groq.com)
- Cloudflare account (for coach-proxy)

### Setup

```bash
# Clone
git clone https://github.com/glorin05/atobits.git
cd atobits

# Install dependencies
flutter pub get

# Configure environment
cp .env.example .env
# Add GROQ_API_KEY to .env

# Run
flutter run

# Build APK
flutter build apk --release --split-per-abi
```

### Coach Proxy (Cloudflare Workers)
See [coach-proxy/README.md](coach-proxy/README.md) for 
deployment instructions. This proxy keeps your Groq API 
key server-side and out of the app bundle.

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/           # App configuration (AppConfig)
│   ├── notifications/    # Timezone-aware reminders
│   ├── services/         # LLM + System services
│   └── theme/            # AppTheme, dark/light, icons
├── data/
│   ├── models/           # Habit, HabitLog
│   └── providers/        # HabitProvider, ThemeProvider
├── features/
│   ├── home/             # Dashboard with progress
│   ├── chat/             # Atom AI Coach (voice + text)
│   ├── meditation/       # Guided TTS meditation
│   ├── journal/          # Daily journaling
│   ├── stats/            # Analytics charts
│   ├── habits/           # Habit management
│   ├── onboarding/       # First-launch flow
│   └── notifications/    # Notification settings
└── coach-proxy/          # Cloudflare Workers backend
```

---

## 🔐 Security

- API keys are never stored in the app bundle
- All LLM calls go through a Cloudflare Workers proxy
- All habit data is stored locally on-device only
- No analytics, no tracking, no external data collection

---

## 📜 Built By

**Glorin P P** — CS Student, KMEA Engineering College, Kerala

[![LinkedIn](https://img.shields.io/badge/LinkedIn-glorin--pp-blue?style=flat&logo=linkedin)](https://linkedin.com/in/glorin-pp)
[![GitHub](https://img.shields.io/badge/GitHub-glorin05-black?style=flat&logo=github)](https://github.com/glorin05)

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
