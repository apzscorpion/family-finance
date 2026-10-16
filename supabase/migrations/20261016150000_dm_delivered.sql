-- WhatsApp-style ticks: sent (one tick), delivered to the other phone (two
-- grey ticks), read (two green ticks). The recipient's app sets
-- delivered_at as soon as the message reaches it, the same way it already
-- sets read_at.
alter table public.direct_messages
  add column if not exists delivered_at timestamptz;

notify pgrst, 'reload schema';
