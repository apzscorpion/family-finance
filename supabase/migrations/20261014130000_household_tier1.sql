-- ========================================================
-- TIER 1 INDIAN HOUSEHOLD SUITE
-- 1. Pending Refunds & Failed UPI Watchdog
-- 2. Daily Deliveries Diary (Milk, Newspaper, Water Cans)
-- 3. Domestic Staff & Helper Ledger (Maid, Driver, Cook)
-- ========================================================

-- 1. Pending Refunds Watchdog
CREATE TABLE IF NOT EXISTS public.pending_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    merchant TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    utr_ref TEXT,
    source_app TEXT, -- 'GPay', 'PhonePe', 'Paytm', 'Amazon', etc.
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'received', 'disputed')),
    initiated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expected_by TIMESTAMP WITH TIME ZONE,
    received_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.pending_refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family pending refunds" ON public.pending_refunds
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = pending_refunds.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.pending_refunds;

-- 2. Daily Deliveries Diary (Milk, Newspaper, Water Cans, etc.)
CREATE TABLE IF NOT EXISTS public.delivery_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- e.g. 'Cow Milk 1L', 'Times of India', 'Bisleri 20L Can'
    item_type TEXT NOT NULL DEFAULT 'milk' CHECK (item_type IN ('milk', 'newspaper', 'water', 'other')),
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0),
    vendor_name TEXT,
    vendor_phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.delivery_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family delivery subscriptions" ON public.delivery_subscriptions
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = delivery_subscriptions.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_subscriptions;

-- Skipped delivery dates log per subscription
CREATE TABLE IF NOT EXISTS public.delivery_skips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID REFERENCES public.delivery_subscriptions(id) ON DELETE CASCADE,
    skip_date DATE NOT NULL,
    quantity_skipped NUMERIC DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(subscription_id, skip_date)
);

ALTER TABLE public.delivery_skips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access family delivery skips" ON public.delivery_skips
    FOR ALL USING (
        subscription_id IN (
            SELECT id FROM public.delivery_subscriptions WHERE family_id IN (
                SELECT family_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_skips;

-- 3. Domestic Staff & Helper Ledger (Maid, Driver, Cook, Nanny)
CREATE TABLE IF NOT EXISTS public.domestic_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'Maid', -- 'Maid', 'Cook', 'Driver', 'Nanny', 'Gardener', etc.
    phone TEXT,
    monthly_salary NUMERIC NOT NULL CHECK (monthly_salary >= 0),
    salary_day INTEGER NOT NULL DEFAULT 1 CHECK (salary_day BETWEEN 1 AND 31),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.domestic_staff ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access their family domestic staff" ON public.domestic_staff
    FOR ALL USING (auth.uid() IN (SELECT id FROM public.profiles WHERE family_id = domestic_staff.family_id));
ALTER PUBLICATION supabase_realtime ADD TABLE public.domestic_staff;

-- Staff Ledger Events: salary payments, cash advances, leave days, bonus
CREATE TABLE IF NOT EXISTS public.staff_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.domestic_staff(id) ON DELETE CASCADE,
    entry_type TEXT NOT NULL CHECK (entry_type IN ('salary_paid', 'advance', 'leave', 'bonus')),
    amount NUMERIC DEFAULT 0,
    entry_date DATE NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.staff_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can access staff ledger" ON public.staff_ledger
    FOR ALL USING (
        staff_id IN (
            SELECT id FROM public.domestic_staff WHERE family_id IN (
                SELECT family_id FROM public.profiles WHERE id = auth.uid()
            )
        )
    );
ALTER PUBLICATION supabase_realtime ADD TABLE public.staff_ledger;

