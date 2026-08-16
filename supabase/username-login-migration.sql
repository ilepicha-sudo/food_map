-- Run this once for an existing project after schema.sql.
-- It records each user's Supabase Auth email behind their public username,
-- so the frontend can sign in with username + password.

alter table public.profiles
  add column if not exists auth_email text;

update public.profiles p
set auth_email = u.email,
    updated_at = now()
from auth.users u
where u.id = p.id
  and p.auth_email is null;

create unique index if not exists profiles_auth_email_idx
  on public.profiles(auth_email)
  where auth_email is not null;
