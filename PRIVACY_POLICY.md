# Privacy Policy for Atobits Habit Tracker

**Effective Date:** April 13, 2026

## Introduction

Atobits ("the App") is a personal habit tracker application. Your privacy is important to us. This document explains how we handle your data when you use our App.

## 1. Data Collection & Storage

### Local Data
- **Habit Information**: Habits you create (titles, descriptions, categories, icons, time-of-day schedules) are stored **locally on your device** using encrypted SharedPreferences.
- **Habit Logs**: Completion records for each habit are stored **locally on your device**.
- **Theme Preference**: Your light/dark mode selection is stored locally.
- **No Network Transmission**: By default, your habit data is never transmitted to our servers or any third party.

### AI Coach Data (Proxy Mode Only)
- When you enable the optional **AI Coach Proxy** feature, your chat messages and system context (habit count, completed count, streak info) are transmitted to a Cloudflare Worker backend.
- The Worker forwards requests to the Groq API for AI-powered coaching suggestions.
- **Groq's Privacy Terms Apply**: Messages sent to Groq are subject to [Groq's Privacy Policy](https://groq.com/privacy/).
- The Cloudflare Worker **does not persist** conversation history; responses are returned immediately.
- Coaching conversations are **not stored locally** in the app by default.

### No Direct Groq API Keys
- Your Groq API key is never embedded in the app binary.
- Keys are held **exclusively on your secure backend** (via environment variables in the Cloudflare Worker).
- The App communicates with the Worker using a bearer token, not a raw API key.

## 2. Third-Party Services

### Cloudflare Workers
- Used as a reverse proxy for AI coaching requests (proxy mode only).
- Your data is subject to [Cloudflare's Privacy Policy](https://www.cloudflare.com/privacypolicy/).

### Groq API
- Processes chat messages for AI-powered recommendations.
- Subject to [Groq's Privacy Policy](https://groq.com/privacy/).

### Google Fonts
- The app uses Google Fonts for typography.
- Font downloads are subject to [Google's Privacy Policy](https://policies.google.com/privacy).

## 3. Data Retention & Deletion

- **Local Habits & Logs**: Remain on your device indefinitely until you manually delete them via the app UI.
- **Proxy Conversations**: Cloudflare Workers do not persist conversation history; data is discarded after the response is sent.
- **Groq API Logs**: Subject to Groq's data retention policies (typically 30 days).

### How to Delete Your Local Data
1. Uninstall the app, or
2. Use your device's app settings to clear the app's local storage.

## 4. Permissions

The App **does not request** the following permissions:
- Camera
- Microphone
- Location
- Contact List
- Calendar
- Photo Library

The App is fully functional without internet access (using local-only mode). Internet permission is only used when you explicitly enable the AI Coach Proxy.

## 5. Data Security

- Habit data is encrypted at rest using Android's SecureSharedPreferences (or equivalent on iOS).
- Communication with the Proxy backend uses HTTPS and bearer token authentication.
- No personal identifiers (name, email, phone) are collected or required.
- You remain fully anonymous unless you choose to share data manually.

## 6. User Responsibility for Proxy Backend

If you self-host or manage your own backend proxy:
- You are responsible for securing your Groq API key.
- Use strong passwords for bearer tokens.
- Rotate credentials regularly (recommended: every 6 months).
- Monitor your Groq account for unauthorized usage.

## 7. Children's Privacy

This App is not intended for children under 13. We do not knowingly collect data from children. If you believe a child has provided personal information, please contact us immediately.

## 8. Changes to This Policy

We may update this Privacy Policy periodically. Changes will be reflected with an updated "Effective Date" at the top of this document. Continued use of the App implies acceptance of the updated policy.

## 9. Contact & Support

For privacy-related questions or concerns, please reach out through the in-app support or by visiting the project repository.

---

**Key Principle**: Your habit data is yours. It stays on your device by default. The optional AI Coach feature is transparent about what data is shared and with whom.
