-- ============================================================================
-- Fix: generate_invite_code() could not find gen_random_bytes().
-- ============================================================================
-- Supabase installs pgcrypto into the `extensions` schema, not `public`. The
-- SECURITY DEFINER callers pin `search_path = public`, so the unqualified call
-- resolved against public only and failed with:
--
--   function gen_random_bytes(integer) does not exist  (SQLSTATE 42883)
--
-- Because this function is the DEFAULT for families.invite_code, every attempt
-- to create a family failed. PostgREST reported it as a 404 on the RPC, which
-- hid the real cause.
--
-- The call is now schema-qualified and the function's own search_path pins both
-- schemas, so it resolves no matter who calls it.
-- ============================================================================

create or replace function public.generate_invite_code()
returns text
language plpgsql
set search_path = public, extensions
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate text;
  i int;
begin
  loop
    candidate := '';
    for i in 1..8 loop
      -- Schema-qualified: pgcrypto lives in `extensions` on Supabase.
      -- Each character is an independent random byte. 256 is an exact multiple
      -- of 32, so `% 32` stays uniform and the full 32^8 space is reachable.
      candidate := candidate
        || substr(alphabet, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32), 1);
    end loop;
    exit when not exists (
      select 1 from public.families where upper(invite_code) = candidate
    );
  end loop;
  return candidate;
end;
$$;

notify pgrst, 'reload schema';
