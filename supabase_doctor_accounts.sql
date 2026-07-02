-- ============================================================================
-- Doctor login accounts – separate table linked to service_providers
-- Run in Supabase → SQL Editor (safe to re-run)
-- ============================================================================

-- 1. Create doctor_accounts table
create table if not exists public.doctor_accounts (
  id                    bigint generated always as identity primary key,
  service_provider_id   bigint not null
                        references public.service_providers (id) on delete cascade,
  auth_user_id          uuid   not null,
  login_email           text   not null,
  login_password        text   not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint doctor_accounts_service_provider_id_key unique (service_provider_id),
  constraint doctor_accounts_auth_user_id_key unique (auth_user_id),
  constraint doctor_accounts_login_email_key unique (login_email)
);

-- 2. Migrate existing columns from service_providers (if present)
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_providers'
      and column_name = 'auth_user_id'
  ) then
    insert into public.doctor_accounts (
      service_provider_id, auth_user_id, login_email, login_password
    )
    select id, auth_user_id, login_email, login_password
    from public.service_providers
    where auth_user_id is not null
      and login_email is not null
    on conflict (service_provider_id) do nothing;
  end if;
end $$;

-- 3. Remove credential columns from service_providers
alter table public.service_providers
  drop column if exists login_email,
  drop column if exists login_password,
  drop column if exists auth_user_id;

drop index if exists public.service_providers_login_email_key;
drop index if exists public.service_providers_auth_user_id_key;

-- 4. Permissions
grant select, insert, update, delete on public.doctor_accounts to authenticated;
alter table public.doctor_accounts enable row level security;

drop policy if exists "admin_all" on public.doctor_accounts;
create policy "admin_all" on public.doctor_accounts
  for all to authenticated using (true) with check (true);

comment on table public.doctor_accounts is
  'Supabase Auth login credentials for doctors, linked 1:1 to service_providers';
