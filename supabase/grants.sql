-- API grants for Supabase anon/authenticated roles.
-- Run this after supabase/schema.sql, supabase/rls.sql, and supabase/storage.sql.
-- RLS policies still decide which rows each role can access.

grant usage on schema public to anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant insert, update, delete on public.profiles to authenticated;

grant select on public.restaurant_categories to anon, authenticated;
grant insert, update, delete on public.restaurant_categories to authenticated;

grant select on public.restaurants to anon, authenticated;
grant insert, update, delete on public.restaurants to authenticated;

grant select on public.reviews to anon, authenticated;
grant insert, update, delete on public.reviews to authenticated;

grant select on public.review_images to anon, authenticated;
grant insert, update, delete on public.review_images to authenticated;

grant select on public.review_reactions to anon, authenticated;
grant insert, update, delete on public.review_reactions to authenticated;

grant select, insert, update, delete on public.favorites to authenticated;

grant select on public.restaurant_stats to anon, authenticated;
grant select on public.restaurant_levels to anon, authenticated;

