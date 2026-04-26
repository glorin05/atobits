# How to Run Atobits with AI Coach Enabled

## Quick Start (Easiest)

In VS Code, select the launch configuration **"Flutter (Coach API Proxy from CLI)"** and press F5. This uses pre-configured credentials.

## Even Easier (Debug/Profile)

In debug/profile runs, the app uses the pre-configured coach proxy by default, so `flutter run` works without extra setup.

For release builds (or if you want to use your own provider), use one of the explicit methods below.

## Method 1: VS Code Launch Configuration with Prompts

1. In VS Code, go to **Run → Debug** (or press F5)
2. Select **"Flutter (Coach API Proxy)"**
3. Enter when prompted:
   - **Coach API URL**: `https://atobits-coach-proxy.atobits.workers.dev`
   - **Coach API Token**: `d510bdf0ea2149148c625157fd9c9a6abf513ebe7301493182d61b45d152aea2`
4. App will build and launch with AI Coach enabled

## Method 2: Command-Line with --dart-define

```bash
cd "c:\Users\glori_za0wp11\Desktop\Emora Mental APP\havbits"

flutter run -d PBEELZQWBAM7FAKZ \
  --dart-define=COACH_API_URL="https://atobits-coach-proxy.atobits.workers.dev" \
  --dart-define=COACH_API_TOKEN="d510bdf0ea2149148c625157fd9c9a6abf513ebe7301493182d61b45d152aea2"
```

## Method 3: Hardcoded Launch Configuration (Pre-configured)

In VS Code, select **"Flutter (Coach API Proxy from CLI)"** and press F5. This launches with embedded credentials.

## Without AI Coach (Local-Only Mode)

Just run:
```bash
flutter run -d PBEELZQWBAM7FAKZ
```

The app works completely offline without AI features.

## Troubleshooting

**Error: "AI configuration is missing"**
- Make sure you're using one of the methods above (Method 1, 2, or 3)
- Don't just run `flutter run` without specifying Coach API credentials
- Check that the URLs and tokens are copied correctly (no extra spaces)

**App builds but AI Coach doesn't respond**
- Verify the proxy URL is reachable: `https://atobits-coach-proxy.atobits.workers.dev`
- Check the bearer token is correct
- Make sure Groq account has available credits

**Proxy returns 401 Unauthorized**
- The proxy requires a valid `COACH_API_TOKEN`.
- Use the VS Code launch config “Flutter (Coach API Proxy from CLI)”, or pass the token via `--dart-define`.

**"Invalid or missing COACH_API_URL"**
- The URL must be a full URL (starting with `https://`)
- Don't add extra quotes or spaces
