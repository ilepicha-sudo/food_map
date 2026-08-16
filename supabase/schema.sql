-- Supabase / Postgres schema draft for the food map.
-- This file defines the data model only. Frontend integration comes later.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null unique,
  auth_email text unique,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.restaurant_categories (
  id text primary key,
  label text not null,
  icon text,
  wall_color text,
  wall_dark_color text,
  roof_color text,
  accent_color text,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

insert into public.restaurant_categories
  (id, label, icon, wall_color, wall_dark_color, roof_color, accent_color, sort_order)
values
  ('zixuan', '自选菜', '🍱', '#e2703a', '#c85a28', '#8c3a2b', '#f4d27a', 10),
  ('noodle', '面/粉', '🍜', '#7fae5a', '#5f9a4a', '#3c6b32', '#fdf3d0', 20),
  ('gaijiao', '盖浇饭', '🍚', '#e6c169', '#dab04a', '#a5762e', '#8c3a2b', 30),
  ('western', '西餐', '🍝', '#7ea3c9', '#5c86ae', '#33547a', '#fce9c2', 40),
  ('drink', '饮品', '🧋', '#6fc4bb', '#4fb6ac', '#2f7c74', '#ffffff', 50),
  ('snack', '小吃其他', '🥟', '#c49bdb', '#b587cf', '#7a4d92', '#fdeeff', 60)
on conflict (id) do update set
  label = excluded.label,
  icon = excluded.icon,
  wall_color = excluded.wall_color,
  wall_dark_color = excluded.wall_dark_color,
  roof_color = excluded.roof_color,
  accent_color = excluded.accent_color,
  sort_order = excluded.sort_order;

create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  name text not null,
  category_id text not null references public.restaurant_categories(id),
  x numeric(5, 2) not null check (x >= 0 and x <= 100),
  y numeric(5, 2) not null check (y >= 0 and y <= 100),
  avg_price numeric(8, 2) check (avg_price is null or avg_price >= 0),
  description text,
  status text not null default 'active' check (status in ('active', 'hidden', 'deleted')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  rating numeric(2, 1) not null check (rating >= 1 and rating <= 5),
  recommend boolean not null,
  dish_name text,
  comment text not null,
  visit_date date not null,
  status text not null default 'active' check (status in ('active', 'hidden', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.review_images (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  storage_path text not null,
  public_url text,
  alt_text text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.review_reactions (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction_type text not null check (reaction_type in ('like', 'disagree')),
  created_at timestamptz not null default now(),
  unique (review_id, user_id)
);

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (restaurant_id, user_id)
);

create index if not exists restaurants_category_idx on public.restaurants(category_id);
create index if not exists restaurants_status_idx on public.restaurants(status);
create index if not exists restaurants_created_by_idx on public.restaurants(created_by);
create index if not exists reviews_restaurant_id_idx on public.reviews(restaurant_id);
create index if not exists reviews_user_id_idx on public.reviews(user_id);
create index if not exists reviews_status_idx on public.reviews(status);
create index if not exists review_images_review_id_idx on public.review_images(review_id);
create index if not exists review_reactions_review_id_idx on public.review_reactions(review_id);
create index if not exists review_reactions_user_id_idx on public.review_reactions(user_id);
create index if not exists favorites_restaurant_id_idx on public.favorites(restaurant_id);
create index if not exists favorites_user_id_idx on public.favorites(user_id);

create or replace view public.restaurant_stats as
select
  r.id as restaurant_id,
  count(rv.id) filter (where rv.status = 'active') as review_count,
  count(rv.id) filter (where rv.status = 'active' and rv.recommend = true) as recommend_count,
  round(avg(rv.rating) filter (where rv.status = 'active'), 2) as avg_rating
from public.restaurants r
left join public.reviews rv on rv.restaurant_id = r.id
group by r.id;

create or replace view public.restaurant_levels as
select
  restaurant_id,
  review_count,
  recommend_count,
  avg_rating,
  case
    when recommend_count >= 10 and avg_rating >= 4.3 then 4
    when recommend_count >= 5 and avg_rating >= 4.0 then 3
    when recommend_count >= 2 and avg_rating >= 3.5 then 2
    else 1
  end as level,
  case
    when recommend_count >= 10 and avg_rating >= 4.3 then '老字号地标'
    when recommend_count >= 5 and avg_rating >= 4.0 then '人气餐馆'
    when recommend_count >= 2 and avg_rating >= 3.5 then '路边小店'
    else '小吃摊'
  end as level_name
from public.restaurant_stats;

-- RLS policies should be added when frontend auth is implemented.
-- Draft rules:
-- 1. Everyone can read active restaurants, categories, active reviews, images, and reaction summaries.
-- 2. Logged-in users can create restaurants and reviews as themselves.
-- 3. Users can update/delete their own reviews.
-- 4. Logged-in users can create/delete their own favorites and review reactions.
-- 5. Admins can update/hide/delete any restaurant, review, image, or reaction.
