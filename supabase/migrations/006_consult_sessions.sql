CREATE TABLE IF NOT EXISTS public.consult_sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id      UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  symptoms    TEXT NOT NULL,
  photo_urls  TEXT[] NOT NULL DEFAULT '{}',
  ai_response JSONB,
  risk_level  TEXT CHECK (risk_level IN ('low','medium','high','emergency')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_consult_pet_id ON public.consult_sessions(pet_id, created_at DESC);
