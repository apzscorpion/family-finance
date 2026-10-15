-- ========================================================
-- FAMILY SPEND TRACKER — SUPABASE POSTGRES DATABASE SCHEMA
-- Execute this script in your Supabase SQL Editor
-- ========================================================

-- Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Families Table
CREATE TABLE IF NOT EXISTS public.families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. User Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    family_id UUID REFERENCES public.families(id) ON DELETE SET NULL,
    full_name TEXT NOT NULL,
    role TEXT DEFAULT 'Member',
    avatar_color TEXT DEFAULT '#9184D9',
    opening_balance NUMERIC DEFAULT 0,
    upi_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Transactions Table (Expenses & Income)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    member_name TEXT NOT NULL,
    title TEXT NOT NULL,
    cat_key TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    type TEXT CHECK (type IN ('expense', 'income')) NOT NULL,
    method TEXT DEFAULT 'UPI',
    origin TEXT DEFAULT 'manual',
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Budgets Table
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    cat_key TEXT NOT NULL,
    family_limit NUMERIC NOT NULL,
    personal_limit NUMERIC NOT NULL,
    UNIQUE(family_id, cat_key)
);

-- 5. Family Approvals Table
CREATE TABLE IF NOT EXISTS public.approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    from_member_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    reason TEXT NOT NULL,
    changes JSONB,
    new_txn JSONB,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Realtime for Live Sync across all Family Member Phones
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.approvals;
ALTER PUBLICATION supabase_realtime ADD TABLE public.budgets;

-- RLS (Row Level Security) Policies
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approvals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can access their family data" ON public.transactions
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = transactions.family_id));

CREATE POLICY "Users can access family member profiles" ON public.profiles
    FOR ALL USING (family_id IN (SELECT family_id FROM public.profiles WHERE id = auth.uid()));

-- 6. Gold & Silver Holdings Table (Zakat & Wealth Tracking)
CREATE TABLE IF NOT EXISTS public.gold_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    metal_type TEXT NOT NULL DEFAULT 'gold' CHECK (metal_type IN ('gold', 'silver')),
    weight_grams NUMERIC NOT NULL CHECK (weight_grams >= 0),
    purity_karat INTEGER NOT NULL DEFAULT 24 CHECK (purity_karat IN (18, 21, 22, 24)),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.gold_holdings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family gold holdings" ON public.gold_holdings
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = gold_holdings.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.gold_holdings;

-- 7. Security Alerts for Guardian Mode (Parent scam & fraud protection)
CREATE TABLE IF NOT EXISTS public.security_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    snippet TEXT,
    severity TEXT DEFAULT 'critical',
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family security alerts" ON public.security_alerts
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = security_alerts.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.security_alerts;

-- 8. Credit Cards & Cashback Optimizer
CREATE TABLE IF NOT EXISTS public.credit_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    card_name TEXT NOT NULL,
    bank TEXT NOT NULL,
    card_network TEXT DEFAULT 'Visa',
    last_four TEXT,
    owner_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reward_points_balance INTEGER DEFAULT 0,
    reward_points_expiry TIMESTAMP WITH TIME ZONE,
    cashback_rules JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.credit_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family credit cards" ON public.credit_cards
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = credit_cards.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.credit_cards;

-- 9. Refund Watchdog ("Never lose a refund again")
CREATE TABLE IF NOT EXISTS public.refund_trackers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    merchant TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    original_txn_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
    initiated_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'received', 'disputed')),
    utr_number TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.refund_trackers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family refund trackers" ON public.refund_trackers
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = refund_trackers.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.refund_trackers;

