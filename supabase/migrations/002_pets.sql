CREATE TABLE IF NOT EXISTS public.pets (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  species    TEXT NOT NULL CHECK (species IN ('dog', 'cat', 'other')),
  breed      TEXT,
  birth_date DATE,
  weight_kg  DECIMAL(5,2),
  gender     TEXT CHECK (gender IN ('male', 'female', 'unknown')),
  neutered   BOOLEAN NOT NULL DEFAULT false,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pets_user_id ON public.pets(user_id);
