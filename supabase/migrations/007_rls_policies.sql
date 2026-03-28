-- Enable RLS on all tables
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consult_sessions ENABLE ROW LEVEL SECURITY;

-- profiles: users access only their own profile
CREATE POLICY "profiles_self" ON public.profiles
  FOR ALL USING (id = auth.uid());

-- pets: users access only their own pets
CREATE POLICY "pets_owner" ON public.pets
  FOR ALL USING (user_id = auth.uid());

-- All pet-linked tables: access only via owned pets
CREATE POLICY "medical_records_via_pet" ON public.medical_records
  FOR ALL USING (
    pet_id IN (SELECT id FROM public.pets WHERE user_id = auth.uid())
  );

CREATE POLICY "timeline_events_via_pet" ON public.timeline_events
  FOR ALL USING (
    pet_id IN (SELECT id FROM public.pets WHERE user_id = auth.uid())
  );

CREATE POLICY "health_logs_via_pet" ON public.health_logs
  FOR ALL USING (
    pet_id IN (SELECT id FROM public.pets WHERE user_id = auth.uid())
  );

CREATE POLICY "consult_sessions_via_pet" ON public.consult_sessions
  FOR ALL USING (
    pet_id IN (SELECT id FROM public.pets WHERE user_id = auth.uid())
  );
