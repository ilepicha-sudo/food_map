-- Row Level Security policies for the food map.
-- Run this after supabase/schema.sql.

create or replace function public.is_admin(user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = user_id
      and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.restaurant_categories enable row level security;
alter table public.restaurants enable row level security;
alter table public.reviews enable row level security;
alter table public.review_images enable row level security;
alter table public.review_reactions enable row level security;
alter table public.favorites enable row level security;

drop policy if exists "profiles are readable by everyone" on public.profiles;
drop policy if exists "users can create their own user profile" on public.profiles;
drop policy if exists "users can update their own user profile" on public.profiles;
drop policy if exists "admins can manage profiles" on public.profiles;

create policy "profiles are readable by everyone"
on public.profiles
for select
using (true);

create policy "users can create their own user profile"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and role = 'user'
);

create policy "users can update their own user profile"
on public.profiles
for update
to authenticated
using (
  id = auth.uid()
  and role = 'user'
)
with check (
  id = auth.uid()
  and role = 'user'
);

create policy "admins can manage profiles"
on public.profiles
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "categories are readable by everyone" on public.restaurant_categories;
drop policy if exists "admins can manage categories" on public.restaurant_categories;

create policy "categories are readable by everyone"
on public.restaurant_categories
for select
using (is_active = true or public.is_admin());

create policy "admins can manage categories"
on public.restaurant_categories
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "active restaurants are readable by everyone" on public.restaurants;
drop policy if exists "users can create restaurants as themselves" on public.restaurants;
drop policy if exists "admins can manage restaurants" on public.restaurants;

create policy "active restaurants are readable by everyone"
on public.restaurants
for select
using (status = 'active' or public.is_admin());

create policy "users can create restaurants as themselves"
on public.restaurants
for insert
to authenticated
with check (
  created_by = auth.uid()
  and status = 'active'
);

create policy "admins can manage restaurants"
on public.restaurants
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "active reviews are readable by everyone" on public.reviews;
drop policy if exists "users can create reviews as themselves" on public.reviews;
drop policy if exists "users can update their own reviews" on public.reviews;
drop policy if exists "users can delete their own reviews" on public.reviews;
drop policy if exists "admins can manage reviews" on public.reviews;

create policy "active reviews are readable by everyone"
on public.reviews
for select
using (status = 'active' or public.is_admin());

create policy "users can create reviews as themselves"
on public.reviews
for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'active'
);

create policy "users can update their own reviews"
on public.reviews
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "users can delete their own reviews"
on public.reviews
for delete
to authenticated
using (user_id = auth.uid());

create policy "admins can manage reviews"
on public.reviews
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "active review images are readable by everyone" on public.review_images;
drop policy if exists "users can create images for their own reviews" on public.review_images;
drop policy if exists "users can update images for their own reviews" on public.review_images;
drop policy if exists "users can delete images for their own reviews" on public.review_images;
drop policy if exists "admins can manage review images" on public.review_images;

create policy "active review images are readable by everyone"
on public.review_images
for select
using (
  public.is_admin()
  or exists (
    select 1
    from public.reviews
    where reviews.id = review_images.review_id
      and reviews.status = 'active'
  )
);

create policy "users can create images for their own reviews"
on public.review_images
for insert
to authenticated
with check (
  exists (
    select 1
    from public.reviews
    where reviews.id = review_images.review_id
      and reviews.user_id = auth.uid()
  )
);

create policy "users can update images for their own reviews"
on public.review_images
for update
to authenticated
using (
  exists (
    select 1
    from public.reviews
    where reviews.id = review_images.review_id
      and reviews.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.reviews
    where reviews.id = review_images.review_id
      and reviews.user_id = auth.uid()
  )
);

create policy "users can delete images for their own reviews"
on public.review_images
for delete
to authenticated
using (
  exists (
    select 1
    from public.reviews
    where reviews.id = review_images.review_id
      and reviews.user_id = auth.uid()
  )
);

create policy "admins can manage review images"
on public.review_images
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "review reactions are readable by everyone" on public.review_reactions;
drop policy if exists "users can create their own review reactions" on public.review_reactions;
drop policy if exists "users can update their own review reactions" on public.review_reactions;
drop policy if exists "users can delete their own review reactions" on public.review_reactions;
drop policy if exists "admins can manage review reactions" on public.review_reactions;

create policy "review reactions are readable by everyone"
on public.review_reactions
for select
using (true);

create policy "users can create their own review reactions"
on public.review_reactions
for insert
to authenticated
with check (user_id = auth.uid());

create policy "users can update their own review reactions"
on public.review_reactions
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "users can delete their own review reactions"
on public.review_reactions
for delete
to authenticated
using (user_id = auth.uid());

create policy "admins can manage review reactions"
on public.review_reactions
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "users can read their own favorites" on public.favorites;
drop policy if exists "users can create their own favorites" on public.favorites;
drop policy if exists "users can delete their own favorites" on public.favorites;
drop policy if exists "admins can manage favorites" on public.favorites;

create policy "users can read their own favorites"
on public.favorites
for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy "users can create their own favorites"
on public.favorites
for insert
to authenticated
with check (user_id = auth.uid());

create policy "users can delete their own favorites"
on public.favorites
for delete
to authenticated
using (user_id = auth.uid());

create policy "admins can manage favorites"
on public.favorites
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Admin bootstrap:
-- After the real "兜兜" account signs up, run this manually with that user's UUID:
--
-- update public.profiles
-- set role = 'admin'
-- where id = '00000000-0000-0000-0000-000000000000'
--   and display_name = '兜兜';

