# Pet Health App

A production-ready iOS app for pet health management with AI-assisted consultation.

## Features
- Pet health profiles and medical records
- Life timeline with photo milestones
- Daily health logging and trend charts
- AI symptom triage (powered by Claude)
- Smart reminders for vaccines and checkups

## Tech Stack
- **Mobile:** Flutter 3.x (iOS)
- **Backend:** Node.js + TypeScript on Railway
- **Database:** Supabase (PostgreSQL + Auth + Storage)
- **AI:** Anthropic Claude API

## Quick Start

### Backend
```bash
cd backend
cp ../.env.example .env  # fill in your values
npm install
npm run dev
```

### Flutter App
```bash
cd app
flutter pub get
flutter run
```

## Project Structure
See `docs/` for full documentation.

## License
MIT
