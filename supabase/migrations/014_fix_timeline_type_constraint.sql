ALTER TABLE public.timeline_events
  DROP CONSTRAINT IF EXISTS timeline_events_type_check;
ALTER TABLE public.timeline_events
  ADD CONSTRAINT timeline_events_type_check
  CHECK (type IN ('photo','weight','medical','note','growth','milestone'));
