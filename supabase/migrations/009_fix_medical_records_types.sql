-- Fix medical_records type constraint to include surgery and other
ALTER TABLE public.medical_records 
  DROP CONSTRAINT IF EXISTS medical_records_type_check;
ALTER TABLE public.medical_records 
  ADD CONSTRAINT medical_records_type_check 
  CHECK (type IN ('vaccine','checkup','deworming','surgery','other'));
