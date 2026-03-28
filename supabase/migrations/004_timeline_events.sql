CREATE TABLE IF NOT EXISTS public.timeline_events (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id     UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  type       TEXT NOT NULL CHECK (type IN ('photo','weight','medical','note')),
  title      TEXT NOT NULL,
  content    TEXT,
  photo_urls TEXT[] NOT NULL DEFAULT '{}',
  event_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_timeline_pet_id_date ON public.timeline_events(pet_id, event_date DESC);
