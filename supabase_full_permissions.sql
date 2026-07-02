-- ============================================================================
-- Clinic Admin – FULL read/write permissions for authenticated users
-- Run this ONCE in Supabase → SQL Editor  (safe to re-run)
-- ============================================================================

-- ── 1. Table grants ─────────────────────────────────────────────────────────
grant select, insert, update, delete on public.service_providers        to authenticated;
grant select, insert, update, delete on public.doctor_accounts          to authenticated;
grant select, insert, update, delete on public.categories               to authenticated;
grant select, insert, update, delete on public.areas                    to authenticated;
grant select, insert, update, delete on public.provider_locations       to authenticated;
grant select, insert, update, delete on public.provider_location_opening_hours to authenticated;
grant select, insert, update, delete on public.bookings                 to authenticated;
grant select, insert, update, delete on public.invoices                 to authenticated;
grant select, insert, update, delete on public.invoice_installments     to authenticated;
grant select, insert, update, delete on public.installment_procedure_categories to authenticated;
grant select, insert, update, delete on public.payment_requests         to authenticated;
grant select, insert, update, delete on public.provider_reviews         to authenticated;
grant select, insert, update, delete on public.loan_requests            to authenticated;
grant select, insert, update, delete on public.loan_wallets             to authenticated;
grant select, insert, update, delete on public.loan_wallet_transactions to authenticated;
grant select, insert, update, delete on public.users_profile            to authenticated;
grant select, insert, update, delete on public.app_settings             to authenticated;
grant usage, select on all sequences in schema public                   to authenticated;

-- ── 2. Enable RLS on all tables ──────────────────────────────────────────────
alter table public.service_providers               enable row level security;
alter table public.doctor_accounts                 enable row level security;
alter table public.categories                      enable row level security;
alter table public.areas                           enable row level security;
alter table public.provider_locations              enable row level security;
alter table public.provider_location_opening_hours enable row level security;
alter table public.bookings                        enable row level security;
alter table public.invoices                        enable row level security;
alter table public.invoice_installments            enable row level security;
alter table public.installment_procedure_categories enable row level security;
alter table public.payment_requests                enable row level security;
alter table public.provider_reviews                enable row level security;
alter table public.loan_requests                   enable row level security;
alter table public.loan_wallets                    enable row level security;
alter table public.loan_wallet_transactions        enable row level security;
alter table public.users_profile                   enable row level security;
alter table public.app_settings                    enable row level security;

-- ── 3. Drop ALL old policies safely ─────────────────────────────────────────
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public' and tablename in (
      'service_providers','doctor_accounts','categories','areas',
      'provider_locations','provider_location_opening_hours',
      'bookings','invoices','invoice_installments',
      'installment_procedure_categories','payment_requests',
      'provider_reviews','loan_requests','loan_wallets',
      'loan_wallet_transactions','users_profile','app_settings'
    )
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- ── 4. Create simple allow-all policies for authenticated admins ─────────────
create policy "admin_all" on public.service_providers               for all to authenticated using (true) with check (true);
create policy "admin_all" on public.doctor_accounts                 for all to authenticated using (true) with check (true);
create policy "admin_all" on public.categories                      for all to authenticated using (true) with check (true);
create policy "admin_all" on public.areas                           for all to authenticated using (true) with check (true);
create policy "admin_all" on public.provider_locations              for all to authenticated using (true) with check (true);
create policy "admin_all" on public.provider_location_opening_hours for all to authenticated using (true) with check (true);
create policy "admin_all" on public.bookings                        for all to authenticated using (true) with check (true);
create policy "admin_all" on public.invoices                        for all to authenticated using (true) with check (true);
create policy "admin_all" on public.invoice_installments            for all to authenticated using (true) with check (true);
create policy "admin_all" on public.installment_procedure_categories for all to authenticated using (true) with check (true);
create policy "admin_all" on public.payment_requests                for all to authenticated using (true) with check (true);
create policy "admin_all" on public.provider_reviews                for all to authenticated using (true) with check (true);
create policy "admin_all" on public.loan_requests                   for all to authenticated using (true) with check (true);
create policy "admin_all" on public.loan_wallets                    for all to authenticated using (true) with check (true);
create policy "admin_all" on public.loan_wallet_transactions        for all to authenticated using (true) with check (true);
create policy "admin_all" on public.users_profile                   for all to authenticated using (true) with check (true);
create policy "admin_all" on public.app_settings                    for all to authenticated using (true) with check (true);

-- ── 5. approve_loan_request RPC ─────────────────────────────────────────────
create or replace function public.approve_loan_request(p_request_id bigint, p_amount numeric)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint; v_status text; v_new_balance numeric; v_admin_id bigint;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Amount must be greater than zero'; end if;
  select user_id, status into v_user_id, v_status from loan_requests where id = p_request_id for update;
  if not found then raise exception 'Loan request not found'; end if;
  if v_status not in ('submitted','under_review') then raise exception 'Loan request is not awaiting approval'; end if;
  select id into v_admin_id from users_profile where email = auth.email() limit 1;
  update loan_requests set approved_amount=p_amount, status='approved', approved_by=v_admin_id, updated_at=now() where id=p_request_id;
  insert into loan_wallets (user_id, balance, updated_at) values (v_user_id, p_amount, now())
  on conflict (user_id) do update set balance=loan_wallets.balance+excluded.balance, updated_at=now()
  returning balance into v_new_balance;
  insert into loan_wallet_transactions(user_id,amount,transaction_type,loan_request_id,balance_after,created_at)
  values (v_user_id,p_amount,'credit',p_request_id,v_new_balance,now());
end; $$;
grant execute on function public.approve_loan_request(bigint,numeric) to authenticated;
