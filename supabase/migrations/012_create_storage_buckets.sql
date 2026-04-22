INSERT INTO storage.buckets (id, name, public)
VALUES
  ('pet-avatars', 'pet-avatars', true),
  ('profile-avatars', 'profile-avatars', true),
  ('medical-records', 'medical-records', true),
  ('timeline-photos', 'timeline-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "authenticated_insert_pet_avatars" ON storage.objects;
CREATE POLICY "authenticated_insert_pet_avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'pet-avatars');

DROP POLICY IF EXISTS "authenticated_insert_profile_avatars" ON storage.objects;
CREATE POLICY "authenticated_insert_profile_avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profile-avatars');

DROP POLICY IF EXISTS "authenticated_insert_medical_records" ON storage.objects;
CREATE POLICY "authenticated_insert_medical_records"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'medical-records');

DROP POLICY IF EXISTS "authenticated_insert_timeline_photos" ON storage.objects;
CREATE POLICY "authenticated_insert_timeline_photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'timeline-photos');
