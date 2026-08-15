-- Supabase Storage setup for review images.
-- Run this after supabase/schema.sql and supabase/rls.sql.

insert into storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'review-images',
    'review-images',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "review images are publicly readable" on storage.objects;
drop policy if exists "users can upload review images to their own folder" on storage.objects;
drop policy if exists "users can update their own review image files" on storage.objects;
drop policy if exists "users can delete their own review image files" on storage.objects;
drop policy if exists "admins can manage all review image files" on storage.objects;

create policy "review images are publicly readable"
on storage.objects
for select
using (bucket_id = 'review-images');

create policy "users can upload review images to their own folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'review-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "users can update their own review image files"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'review-images'
  and owner = auth.uid()
)
with check (
  bucket_id = 'review-images'
  and owner = auth.uid()
);

create policy "users can delete their own review image files"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'review-images'
  and owner = auth.uid()
);

create policy "admins can manage all review image files"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'review-images'
  and public.is_admin()
)
with check (
  bucket_id = 'review-images'
  and public.is_admin()
);

