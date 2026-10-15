-- Migration: Guardian Mode (Parent scam & fraud protection) & Card Rewards Optimizer
-- Timestamp: 2026-10-15 01:00:00

-- 1. Add is_protected_member to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_protected_member boolean DEFAULT false;

-- 2. Security Alerts for Guardian Mode
CREATE TABLE IF NOT EXISTS public.security_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_type text NOT NULL, -- 'scam_sms', 'unusual_debit', 'suspicious_payee', 'phishing_link'
  title text NOT NULL,
  description text NOT NULL,
  snippet text,
  severity text DEFAULT 'critical', -- 'warning', 'critical'
  status text DEFAULT 'active', -- 'active', 'dismissed', 'resolved'
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_security_alerts_family ON public.security_alerts(family_id);
CREATE INDEX IF NOT EXISTS idx_security_alerts_status ON public.security_alerts(status);

ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "security_alerts_family_all" ON public.security_alerts;
CREATE POLICY "security_alerts_family_all" ON public.security_alerts
  FOR ALL USING (
    public.is_family_member(family_id)
  );

-- 3. Household Credit Cards & Rewards Optimizer
CREATE TABLE IF NOT EXISTS public.credit_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  card_name text NOT NULL,
  bank text NOT NULL,
  card_network text DEFAULT 'Visa',
  last_four text,
  owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reward_points_balance int DEFAULT 0,
  reward_points_expiry timestamptz,
  cashback_rules jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_credit_cards_family ON public.credit_cards(family_id);

ALTER TABLE public.credit_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "credit_cards_family_all" ON public.credit_cards;
CREATE POLICY "credit_cards_family_all" ON public.credit_cards
  FOR ALL USING (
    public.is_family_member(family_id)
  );

-- Realtime subscriptions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'security_alerts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.security_alerts;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'credit_cards'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.credit_cards;
  END IF;
END $$;

