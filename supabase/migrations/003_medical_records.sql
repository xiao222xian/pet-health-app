CREATE TABLE IF NOT EXISTS public.medical_records (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id        UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  type          TEXT NOT NULL CHECK (type IN ('vaccine','checkup','deworming','allergy','disease')),
  title         TEXT NOT NULL,
  record_date   DATE NOT NULL,
  next_due_date DATE,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_medical_records_pet_id ON public.medical_records(pet_id);
CREATE INDEX idx_medical_records_next_due ON public.medical_records(next_due_date) WHERE next_due_date IS NOT NULL;
