-- ============================================================================
-- Supabase Admin Policies for Clinic Card Dashboard
-- ============================================================================
-- Run this ONCE in your Supabase project's SQL Editor.
--
-- What this does:
--   1. Creates an "admin" role check: any authenticated user whose email is
--      listed in the admin_emails table (or who has the is_admin flag) can
--      INSERT / UPDATE / DELETE on doctor-related tables.
--
--   2. For simplicity we use a single admin_emails table so you can add /
--      remove admins without changing SQL policies.
--
-- Steps:
--   a) Apply this SQL in Supabase → SQL Editor
--   b) Go to Supabase → Authentication → Users → "Add User" and create your
--      admin account with any email/password.
--   c) Insert that email into admin_emails (done at the bottom of this file).
-- ============================================================================

-- ── Admin emails table ───────────────────────────────────────────────────────
create table if not exists admin_emails (
  email text primary key
);

-- Grant anon/authenticated read so the policy functions can query it
grant select on admin_emails to anon, authenticated;

-- Helper function (avoids repeating the auth check in every policy)
create or replace function is_admin()
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1 from admin_emails
    where email = auth.email()
  );
$$;

-- ── service_providers ────────────────────────────────────────────────────────
alter table service_providers enable row level security;

drop policy if exists "admin_insert_providers" on service_providers;
create policy "admin_insert_providers" on service_providers
  for insert to authenticated
  with check (is_admin());

drop policy if exists "admin_update_providers" on service_providers;
create policy "admin_update_providers" on service_providers
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "admin_delete_providers" on service_providers;
create policy "admin_delete_providers" on service_providers
  for delete to authenticated
  using (is_admin());

-- ── categories ───────────────────────────────────────────────────────────────
alter table categories enable row level security;

drop policy if exists "admin_insert_categories" on categories;
create policy "admin_insert_categories" on categories
  for insert to authenticated
  with check (is_admin());

drop policy if exists "admin_update_categories" on categories;
create policy "admin_update_categories" on categories
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "admin_delete_categories" on categories;
create policy "admin_delete_categories" on categories
  for delete to authenticated
  using (is_admin());

-- ── areas ────────────────────────────────────────────────────────────────────
alter table areas enable row level security;

drop policy if exists "admin_insert_areas" on areas;
create policy "admin_insert_areas" on areas
  for insert to authenticated
  with check (is_admin());

drop policy if exists "admin_update_areas" on areas;
create policy "admin_update_areas" on areas
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "admin_delete_areas" on areas;
create policy "admin_delete_areas" on areas
  for delete to authenticated
  using (is_admin());

-- ── provider_locations ───────────────────────────────────────────────────────
alter table provider_locations enable row level security;

drop policy if exists "admin_insert_locations" on provider_locations;
create policy "admin_insert_locations" on provider_locations
  for insert to authenticated
  with check (is_admin());

drop policy if exists "admin_update_locations" on provider_locations;
create policy "admin_update_locations" on provider_locations
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "admin_delete_locations" on provider_locations;
create policy "admin_delete_locations" on provider_locations
  for delete to authenticated
  using (is_admin());

-- ── provider_location_opening_hours ─────────────────────────────────────────
alter table provider_location_opening_hours enable row level security;

drop policy if exists "admin_insert_hours" on provider_location_opening_hours;
create policy "admin_insert_hours" on provider_location_opening_hours
  for insert to authenticated
  with check (is_admin());

drop policy if exists "admin_update_hours" on provider_location_opening_hours;
create policy "admin_update_hours" on provider_location_opening_hours
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "admin_delete_hours" on provider_location_opening_hours;
create policy "admin_delete_hours" on provider_location_opening_hours
  for delete to authenticated
  using (is_admin());

-- ── Add yourself as admin ────────────────────────────────────────────────────
-- Replace with the email you used when creating your Supabase Auth user.
insert into admin_emails (email)
values ('admin@yourapp.com')
on conflict do nothing;
