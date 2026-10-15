-- ============================================================================
-- Add UPI ID support to user profiles
-- ============================================================================
-- Allows each user to save their UPI VPA (e.g., user@okhdfcbank) so family
-- members can settle balances with 1-tap via GPay, PhonePe, Paytm, etc.
-- ============================================================================

alter table public.profiles
  add column if not exists upi_id text;

create or replace function public.set_my_upi_id(p_upi text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_upi text := nullif(btrim(p_upi), '');
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  if v_upi is not null and length(v_upi) > 100 then
    raise exception 'UPI ID is too long' using errcode = '22023';
  end if;

  update public.profiles
     set upi_id = v_upi
   where id = auth.uid();
end;
$$;

revoke all on function public.set_my_upi_id(text) from public;
grant execute on function public.set_my_upi_id(text) to authenticated;

