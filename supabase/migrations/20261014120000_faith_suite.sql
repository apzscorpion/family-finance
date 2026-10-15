-- Migration for Faith & Cultural Suite:
-- 1. Zakat & Gold holdings table (family-scoped)
-- 2. Sadaqah (charity) donations log

CREATE TABLE IF NOT EXISTS public.gold_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    metal_type TEXT NOT NULL DEFAULT 'gold' CHECK (metal_type IN ('gold', 'silver')),
    weight_grams NUMERIC NOT NULL CHECK (weight_grams >= 0),
    purity_karat INTEGER NOT NULL DEFAULT 24 CHECK (purity_karat IN (18, 21, 22, 24)),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.gold_holdings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can view and manage gold holdings"
ON public.gold_holdings
FOR ALL
USING (
    family_id IN (
        SELECT family_id FROM public.profiles WHERE id = auth.uid()
    )
)
WITH CHECK (
    family_id IN (
        SELECT family_id FROM public.profiles WHERE id = auth.uid()
    )
);

-- Realtime publication for gold holdings
ALTER PUBLICATION supabase_realtime ADD TABLE public.gold_holdings;

