-- Allow authenticated users to SELECT (needed for upload verification)
DROP POLICY IF EXISTS "authenticated_select_storage" ON storage.objects;
CREATE POLICY "authenticated_select_storage"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id IN ('pet-avatars', 'profile-avatars', 'medical-records', 'timeline-photos'));

-- Allow public to SELECT (buckets are public)
DROP POLICY IF EXISTS "public_select_storage" ON storage.objects;
CREATE POLICY "public_select_storage"
ON storage.objects FOR SELECT
TO anon
USING (bucket_id IN ('pet-avatars', 'profile-avatars', 'medical-records', 'timeline-photos'));

-- Allow authenticated users to INSERT
DROP POLICY IF EXISTS "authenticated_insert_storage" ON storage.objects;
CREATE POLICY "authenticated_insert_storage"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id IN ('pet-avatars', 'profile-avatars', 'medical-records', 'timeline-photos'));

-- Allow authenticated users to UPDATE their own objects
DROP POLICY IF EXISTS "authenticated_update_storage" ON storage.objects;
CREATE POLICY "authenticated_update_storage"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id IN ('pet-avatars', 'profile-avatars', 'medical-records', 'timeline-photos'));

-- Allow authenticated users to DELETE their own objects
DROP POLICY IF EXISTS "authenticated_delete_storage" ON storage.objects;
CREATE POLICY "authenticated_delete_storage"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id IN ('pet-avatars', 'profile-avatars', 'medical-records', 'timeline-photos'));
