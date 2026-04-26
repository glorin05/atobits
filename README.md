# 🧠 Atobits — AI Habit Tracker

> A premium Flutter habit tracker with an AI voice coach 
> (Atom), guided meditation, journaling, and rich analytics.
> Built with a Notion-inspired design system.

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Atom AI Coach** | LLM-powered coach — text chat + Voice Mode |
| **Habit Tracking** | Streaks, scheduling, flexible reminders |
| **Analytics** | Weekly/monthly/yearly completion charts |
| **Meditation** | Guided TTS meditation sessions |
| **Journal** | Daily reflection and journaling |
| **Dark/Light Mode** | Full theme support |
| **Offline First** | No Firebase — SharedPreferences only |

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart ≥3.0) |
| State | Provider (ChangeNotifier) |
| Storage | SharedPreferences — fully offline |
| AI | Groq API (Llama 3.1 8B) via Cloudflare Workers |
| Voice | speech_to_text + flutter_tts |
| Notifications | flutter_local_notifications + timezone |
| UI | Urbanist font, Glassmorphism, Notion-inspired |

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x installed
- Free Groq API key from console.groq.com
- Cloudflare account (for coach-proxy deployment)

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/glorin05/atobits.git
cd atobits

# 2. Install dependencies
flutter pub get

# 3. Set up environment
cp .env.example .env
# Add your GROQ_API_KEY to .env

# 4. Deploy coach-proxy to Cloudflare Workers
cd coach-proxy
# Follow coach-proxy/README.md

# 5. Run the app
flutter run
```

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/           # App configuration
│   ├── notifications/    # Smart reminders
│   ├── services/         # LLM + System services
│   └── theme/            # AppTheme, dark/light
├── data/
│   ├── models/           # Habit, HabitLog
│   └── providers/        # HabitProvider, ThemeProvider
├── features/
│   ├── home/             # Dashboard
│   ├── chat/             # Atom AI Coach
│   ├── meditation/       # Guided TTS meditation
│   ├── journal/          # Daily journaling
│   ├── stats/            # Analytics charts
│   └── habits/           # Habit management
└── coach-proxy/          # Cloudflare Workers backend
```

## ⚙️ Environment Variables

Copy .env.example to .env and fill in your values:
- GROQ_API_KEY — from console.groq.com (free tier available)

## 📜 Built By
Glorin P P — CS Student, KMEA Engineering College
[LinkedIn](https://linkedin.com/in/glorin-pp) | 
[GitHub](https://github.com/glorin05)
