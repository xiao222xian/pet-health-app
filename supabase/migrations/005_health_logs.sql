CREATE TABLE IF NOT EXISTS public.health_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id         UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  log_date       DATE NOT NULL,
  food_type      TEXT,
  food_amount_g  INTEGER,
  water_ml       INTEGER,
  weight_kg      DECIMAL(5,2),
  stool_status   SMALLINT CHECK (stool_status BETWEEN 1 AND 5),
  appetite_level SMALLINT CHECK (appetite_level BETWEEN 1 AND 5),
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(pet_id, log_date)
);

CREATE INDEX idx_health_logs_pet_id_date ON public.health_logs(pet_id, log_date DESC);
