# Deployment Guide

## Backend (Railway)

1. Connect GitHub repo to Railway at railway.app
2. Set root directory to `backend/`
3. Add environment variables in Railway dashboard:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `ANTHROPIC_API_KEY`
   - `NODE_ENV=production`
4. Railway auto-deploys on push to `main`

Build command: `npm run build`
Start command: `node dist/index.js`

## Supabase Setup

1. Create new project at supabase.com
2. Go to SQL Editor and run migrations in order:
   - `supabase/migrations/001_profiles.sql`
   - `supabase/migrations/002_pets.sql`
   - `supabase/migrations/003_medical_records.sql`
   - `supabase/migrations/004_timeline_events.sql`
   - `supabase/migrations/005_health_logs.sql`
   - `supabase/migrations/006_consult_sessions.sql`
   - `supabase/migrations/007_rls_policies.sql`
3. Enable Apple OAuth: Authentication → Providers → Apple
4. Copy Project URL and anon key for app configuration

## iOS App Build

Set environment variables as Dart defines at build time:

```bash
flutter build ios \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=API_BASE_URL=https://your-app.up.railway.app/api/v1
```

Then open `app/ios/Runner.xcworkspace` in Xcode:
1. Set Bundle Identifier (e.g., com.pethealthapp.ios)
2. Set signing certificate (requires Apple Developer account)
3. Product → Archive → Distribute App → App Store Connect

## App Store Review Notes

- **Category:** Health & Fitness (NOT Medical)
- **AI consultation:** Mandatory disclaimer shown before first use with user acknowledgment
- **Language:** All AI responses labeled as reference only (仅供参考)
- **No diagnosis claims** anywhere in app copy or metadata

## Cost Estimate

| Service | Cost |
|---|---|
| Railway (Starter) | $5/month |
| Supabase (Pro, if needed) | $25/month |
| Anthropic API | ~$0.25 per 1,000 consultations |
| Apple Developer Program | $99/year |
