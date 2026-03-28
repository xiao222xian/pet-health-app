# Pet Health App — Design Spec
**Date:** 2026-03-28
**Status:** Approved
**Scope:** MVP v1.0 (iOS)

---

## 1. Product Overview

A production-ready iOS app for pet health management. Users can maintain health profiles for their pets, track growth/medical history on a timeline, log daily health metrics, and get AI-assisted symptom triage.

**Not in scope for MVP:** Android, multi-pet household dashboard, vet integration, social sharing.

---

## 2. Target Users

- Pet owners (cats/dogs primary, extensible to other species)
- Single owner per account for MVP
- Technically comfortable, iOS-native users

---

## 3. Core Features (MVP = P0)

### 3.1 Authentication
- Apple Sign-In (required for App Store healthcare apps)
- Email/password fallback
- JWT managed by Supabase Auth
- Profile: display name, avatar (optional)

### 3.2 Pet Profile
- Fields: name, species, breed, date of birth (age calculated), weight, gender, neutered status, avatar photo
- Medical records sub-section: vaccines, checkups, deworming, allergy history, disease history
  - Each record: type, title, date, notes, next_due_date (for recurring reminders)
- One pet per account for MVP (schema supports multiple)

### 3.3 Smart Reminders
- Local push notifications (no server-side push for MVP)
- Trigger: next_due_date on medical records
- Types: vaccine booster, annual checkup, deworming cycle
- Reminder lead time: configurable (default 7 days before)

### 3.4 Life Timeline
- Events stored chronologically
- Event types: photo milestone, weight checkpoint, medical event, custom note
- Photos: up to 5 per event, stored in Supabase Storage
- UI: vertical timeline view + grid photo gallery view

### 3.5 Daily Health Log (P1, but DB designed now)
- Per-day entry: food intake (type + amount), water (ml), weight, stool status (5-level scale), appetite (5-level scale), free notes
- Weekly trend charts (weight, appetite)

### 3.6 AI Consultation (P1, but backend scaffolded now)
- Input: symptom text + optional photos (max 3)
- Processing: Claude claude-haiku-4-5 via backend proxy
- Output: risk level (low/medium/high/emergency), structured advice, recommended actions
- Mandatory disclaimer: "仅供参考，不构成兽医诊断意见"
- Session saved to DB for history

---

## 4. Technical Architecture

### 4.1 Tech Stack

| Layer | Choice | Rationale |
|---|---|---|
| Mobile | Flutter 3.x | iOS-first, Android-ready, Cupertino components, single codebase |
| Backend | Node.js 20 + TypeScript on Railway | Simple deployment, $5/mo, AI proxy layer |
| Database | Supabase (PostgreSQL 15) | Auth + DB + Storage in one, RLS for privacy, generous free tier |
| File Storage | Supabase Storage | Pet photos, CDN-backed, permissions tied to DB rows |
| AI | Anthropic Claude API | Haiku for triage (cost), Sonnet for nutrition advice (quality) |
| CI/CD | GitHub Actions | Test + lint on PR, auto-deploy to Railway on main merge |

### 4.2 System Architecture

```
Flutter iOS App
    │
    ├──[Supabase SDK]──→ Supabase
    │                     ├── Auth (JWT)
    │                     ├── PostgreSQL (pets, records, timeline, logs)
    │                     └── Storage (photos, avatars)
    │
    └──[HTTPS]──→ Node.js API (Railway)
                    ├── POST /api/v1/consult  (Claude Haiku)
                    └── POST /api/v1/nutrition (Claude Sonnet)
                          └── Anthropic API
```

### 4.3 Security
- Supabase Row Level Security (RLS): users can only read/write their own data
- Backend API: verifies Supabase JWT before any AI call
- No raw medical data sent to Anthropic — only symptom descriptions and photos
- `.env` never committed; secrets via Railway environment variables
- HTTPS enforced everywhere

---

## 5. Database Schema

### users (managed by Supabase Auth + profiles table)
```sql
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

### pets
```sql
CREATE TABLE pets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  species     TEXT NOT NULL,  -- 'dog' | 'cat' | 'other'
  breed       TEXT,
  birth_date  DATE,
  weight_kg   DECIMAL(5,2),
  gender      TEXT,           -- 'male' | 'female'
  neutered    BOOLEAN DEFAULT false,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);
```

### medical_records
```sql
CREATE TABLE medical_records (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id       UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  type         TEXT NOT NULL,  -- 'vaccine'|'checkup'|'deworming'|'allergy'|'disease'
  title        TEXT NOT NULL,
  record_date  DATE NOT NULL,
  next_due_date DATE,
  notes        TEXT,
  created_at   TIMESTAMPTZ DEFAULT now()
);
```

### timeline_events
```sql
CREATE TABLE timeline_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id      UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,  -- 'photo'|'weight'|'medical'|'note'
  title       TEXT NOT NULL,
  content     TEXT,
  photo_urls  TEXT[],
  event_date  DATE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

### health_logs
```sql
CREATE TABLE health_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id         UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  log_date       DATE NOT NULL,
  food_type      TEXT,
  food_amount_g  INTEGER,
  water_ml       INTEGER,
  weight_kg      DECIMAL(5,2),
  stool_status   SMALLINT,    -- 1-5 scale
  appetite_level SMALLINT,    -- 1-5 scale
  notes          TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE(pet_id, log_date)
);
```

### consult_sessions
```sql
CREATE TABLE consult_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id       UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  symptoms     TEXT NOT NULL,
  photo_urls   TEXT[],
  ai_response  JSONB,         -- {risk_level, advice, actions, disclaimer}
  risk_level   TEXT,          -- 'low'|'medium'|'high'|'emergency'
  created_at   TIMESTAMPTZ DEFAULT now()
);
```

**RLS Policies:** All tables enforce `user_id = auth.uid()` via JOIN to pets.

---

## 6. API Design (Backend — Node.js)

### Base URL: `https://api.pethealthapp.com/api/v1`

### Authentication
All requests require `Authorization: Bearer <supabase_jwt>`

### Endpoints

#### POST /consult
```json
Request:
{
  "pet_id": "uuid",
  "symptoms": "string (max 1000 chars)",
  "photo_urls": ["string"] // optional, max 3
}

Response 200:
{
  "risk_level": "low|medium|high|emergency",
  "summary": "string",
  "advice": ["string"],
  "seek_vet": boolean,
  "disclaimer": "本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。"
}
```

#### POST /nutrition
```json
Request:
{
  "pet_id": "uuid"
}

Response 200:
{
  "daily_calories": number,
  "protein_ratio": number,
  "recommendations": ["string"],
  "foods_to_avoid": ["string"]
}
```

### Error Format
```json
{
  "error": {
    "code": "UNAUTHORIZED|INVALID_INPUT|AI_ERROR|NOT_FOUND",
    "message": "string"
  }
}
```

---

## 7. Flutter App Structure

```
ios/                          # Flutter iOS project
lib/
├── main.dart
├── app/
│   ├── router.dart           # go_router navigation
│   └── theme.dart            # Cupertino theme
├── features/
│   ├── auth/
│   ├── profile/              # pet profile + medical records
│   ├── timeline/
│   ├── health_log/
│   └── consult/              # AI consultation
├── shared/
│   ├── models/               # Dart data classes
│   ├── services/
│   │   ├── supabase_service.dart
│   │   └── api_service.dart
│   └── widgets/              # reusable UI components
└── l10n/                     # i18n (zh-CN primary)
```

### Navigation (Tab Bar)
1. 首页 — pet card + today's reminders
2. 档案 — profile / medical records
3. 时光轴 — timeline + gallery
4. 健康 — daily log + trends
5. 问诊 — AI consultation

---

## 8. Project Directory Structure

```
pet-health-app/
├── README.md
├── LICENSE                   # MIT
├── .gitignore
├── .env.example
├── docs/
│   ├── PRD.md
│   ├── TECH_STACK.md
│   ├── API.md
│   ├── DATABASE.md
│   ├── DEPLOYMENT.md
│   └── superpowers/specs/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml
│       └── flutter-ci.yml
├── backend/
│   ├── src/
│   │   ├── routes/
│   │   ├── services/
│   │   ├── middleware/
│   │   └── index.ts
│   ├── package.json
│   └── tsconfig.json
├── ios/                      # Flutter project root
│   └── (Flutter project)
├── supabase/
│   └── migrations/           # SQL migration files
└── shared/
    └── types/                # Shared TypeScript types
```

---

## 9. iOS App Store Compliance

- **Medical disclaimer:** Consultation feature must show disclaimer before first use (with user acknowledgment stored)
- **Privacy policy:** Required before submission — covers health data, photo storage, AI processing
- **Apple Sign-In:** Required when any third-party login is offered (App Store Review Guideline 4.8)
- **App category:** Health & Fitness (not Medical — avoids stricter review)
- **Data collection disclosure:** Health data, photos — disclose in App Store listing
- **TestFlight:** Internal testing (up to 100 testers) before external beta

---

## 10. Cost Estimate (Monthly, post-launch)

| Service | Free Tier | Paid |
|---|---|---|
| Supabase | 500MB DB, 1GB storage, 50k auth users | $25/mo (Pro) |
| Railway | $5/mo (Starter) | $5/mo |
| Anthropic API | Pay-per-use | ~$0.25/1k consultations (Haiku) |
| GitHub Actions | 2000 min/mo free | Free for this scale |

**Total MVP running cost: ~$30/mo** until significant user growth.

---

## 11. Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| App Store rejection (medical claims) | Medium | Use "仅供参考" language, category = Health & Fitness |
| Supabase free tier limits | Low | Design for migration to Pro from day 1 |
| Claude API latency in consultation | Low | Show loading state, set 30s timeout |
| Photo storage costs at scale | Medium | Compress images client-side before upload (max 1MB/photo) |
