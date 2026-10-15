-- Migration: Refund Watchdog ("Never lose a refund again")
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
    FOR ALL USING (public.is_family_member(family_id));

ALTER PUBLICATION supabase_realtime ADD TABLE public.refund_trackers;

