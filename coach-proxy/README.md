# Atobits Coach Proxy (Cloudflare Worker)

This proxy keeps your Groq key on the server and returns only coach replies to the app.

## 1) Install and login

```bash
cd coach-proxy
npm install
npx wrangler login
```

## 2) Set required secrets

```bash
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put COACH_API_TOKEN
```

Optional model override:

```bash
npx wrangler secret put GROQ_MODEL
```

Recommended value for `GROQ_MODEL`:
- `llama-3.1-8b-instant`

## 3) Deploy

```bash
npm run deploy
```

Wrangler prints your URL, usually:
- `https://atobits-coach-proxy.<subdomain>.workers.dev`

## 4) Connect app (no Groq key in app)

Run with:

```bash
flutter run --dart-define=COACH_API_URL=https://YOUR_WORKER_URL --dart-define=COACH_API_TOKEN=YOUR_COACH_API_TOKEN
```

Or use the VS Code launch profile:
- `Flutter (Coach API Proxy)`

## Request/response contract

Request body:

```json
{
  "systemPrompt": "string",
  "conversation": [
    { "role": "user", "content": "..." },
    { "role": "assistant", "content": "..." }
  ]
}
```

Response body:

```json
{
  "reply": "string"
}
```
