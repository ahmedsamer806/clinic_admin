-- ============================================================================
-- Loan Admin: policies + approve_loan_request RPC
-- Run in Supabase → SQL Editor
-- Safe to re-run (drops old policies first)
-- ============================================================================

grant select, insert, update, delete on table public.loan_requests to authenticated;
grant select, insert, update, delete on table public.loan_wallets to authenticated;
grant select, insert, update, delete on table public.loan_wallet_transactions to authenticated;
grant select on table public.users_profile to authenticated;
grant usage, select on all sequences in schema public to authenticated;

alter table public.loan_requests enable row level security;
alter table public.loan_wallets enable row level security;
alter table public.loan_wallet_transactions enable row level security;

-- Remove is_admin()-based policies (if they exist)
drop policy if exists "admin_select_loan_requests" on public.loan_requests;
drop policy if exists "admin_update_loan_requests" on public.loan_requests;
drop policy if exists "admin_select_loan_wallets" on public.loan_wallets;
drop policy if exists "admin_upsert_loan_wallets" on public.loan_wallets;
drop policy if exists "admin_update_loan_wallets" on public.loan_wallets;
drop policy if exists "admin_select_loan_wallet_tx" on public.loan_wallet_transactions;
drop policy if exists "admin_insert_loan_wallet_tx" on public.loan_wallet_transactions;
drop policy if exists "admin_select_users_profile" on public.users_profile;

-- Simple authenticated access (same as doctors tables)
drop policy if exists "Admin full access – loan_requests" on public.loan_requests;
create policy "Admin full access – loan_requests"
  on public.loan_requests for all to authenticated
  using (true) with check (true);

drop policy if exists "Admin full access – loan_wallets" on public.loan_wallets;
create policy "Admin full access – loan_wallets"
  on public.loan_wallets for all to authenticated
  using (true) with check (true);

drop policy if exists "Admin full access – loan_wallet_transactions" on public.loan_wallet_transactions;
create policy "Admin full access – loan_wallet_transactions"
  on public.loan_wallet_transactions for all to authenticated
  using (true) with check (true);

drop policy if exists "Admin full access – users_profile" on public.users_profile;
create policy "Admin full access – users_profile"
  on public.users_profile for select to authenticated
  using (true);

-- Atomically approve a pending loan request and credit the user's wallet.
create or replace function public.approve_loan_request(
  p_request_id bigint,
  p_amount numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id bigint;
  v_status text;
  v_new_balance numeric;
  v_admin_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  select user_id, status
  into v_user_id, v_status
  from loan_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Loan request not found';
  end if;

  if v_status not in ('submitted', 'under_review') then
    raise exception 'Loan request is not awaiting approval';
  end if;

  select id into v_admin_id
  from users_profile
  where email = auth.email()
  limit 1;

  update loan_requests
  set approved_amount = p_amount,
      status = 'approved',
      approved_by = v_admin_id,
      updated_at = now()
  where id = p_request_id;

  insert into loan_wallets (user_id, balance, updated_at)
  values (v_user_id, p_amount, now())
  on conflict (user_id) do update
  set balance = loan_wallets.balance + excluded.balance,
      updated_at = now()
  returning balance into v_new_balance;

  insert into loan_wallet_transactions (
    user_id, amount, transaction_type, loan_request_id, balance_after, created_at
  )
  values (v_user_id, p_amount, 'credit', p_request_id, v_new_balance, now());
end;
$$;

grant execute on function public.approve_loan_request(bigint, numeric) to authenticated;
