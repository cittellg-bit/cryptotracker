-- Location: supabase/migrations/20250113210000_fix_crypto_transaction_dependencies.sql
-- Schema Analysis: Fixing dependency issues with portfolio_summary view and transactions table
-- Integration Type: Schema correction with proper dependency handling
-- Dependencies: Existing tables (user_profiles, transactions, portfolio_summary)

-- First, handle the dependency issue by dropping the dependent view
DROP VIEW IF EXISTS public.portfolio_summary;

-- Now we can safely modify the transactions table
-- Remove the problematic total_value column that was causing issues
ALTER TABLE public.transactions 
DROP COLUMN IF EXISTS total_value;

-- Add the total_value column back as a properly generated column
ALTER TABLE public.transactions 
ADD COLUMN total_value NUMERIC GENERATED ALWAYS AS (amount * price_per_unit) STORED;

-- Ensure all required columns exist with proper constraints
ALTER TABLE public.transactions 
ALTER COLUMN crypto_symbol SET NOT NULL,
ALTER COLUMN crypto_name SET NOT NULL,
ALTER COLUMN crypto_id SET NOT NULL;

-- Add missing columns if they don't exist
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS crypto_icon_url TEXT DEFAULT '';

-- Update the crypto_icon_url to NOT NULL with default
ALTER TABLE public.transactions 
ALTER COLUMN crypto_icon_url SET NOT NULL,
ALTER COLUMN crypto_icon_url SET DEFAULT '';

-- Create a proper portfolio summary view that aggregates from transactions
CREATE VIEW public.portfolio_summary AS
SELECT 
    user_id,
    crypto_id,
    crypto_symbol,
    crypto_name,
    crypto_icon_url,
    SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE -amount END) as total_amount,
    SUM(CASE WHEN transaction_type = 'buy' THEN total_value ELSE -total_value END) as total_invested,
    CASE 
        WHEN SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE 0 END) > 0
        THEN SUM(CASE WHEN transaction_type = 'buy' THEN total_value ELSE 0 END) / SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE 0 END)
        ELSE 0
    END as average_price,
    COUNT(*) as transaction_count,
    MAX(transaction_date) as last_transaction_date
FROM public.transactions
GROUP BY user_id, crypto_id, crypto_symbol, crypto_name, crypto_icon_url
HAVING SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE -amount END) > 0;

-- Add proper indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_user_crypto ON public.transactions(user_id, crypto_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(transaction_type);

-- Ensure RLS is enabled on transactions table
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Update RLS policy to ensure users can only access their own transactions
DROP POLICY IF EXISTS "users_own_transactions" ON public.transactions;
CREATE POLICY "users_own_transactions"
ON public.transactions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Add some corrected sample data to test the system
DO $$
DECLARE
    demo_user_id UUID;
    btc_transaction_id UUID := gen_random_uuid();
    eth_transaction_id UUID := gen_random_uuid();
BEGIN
    -- Get an existing user or create one for demo
    SELECT id INTO demo_user_id FROM public.user_profiles LIMIT 1;
    
    -- If no user exists, create demo auth user and profile
    IF demo_user_id IS NULL THEN
        demo_user_id := gen_random_uuid();
        
        -- Create auth user
        INSERT INTO auth.users (
            id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
            created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
            is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
            recovery_token, recovery_sent_at, email_change_token_new, email_change,
            email_change_sent_at, email_change_token_current, email_change_confirm_status,
            reauthentication_token, reauthentication_sent_at, phone, phone_change,
            phone_change_token, phone_change_sent_at
        ) VALUES (
            demo_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'demo@cryptotracker.com', crypt('demo123', gen_salt('bf', 10)), now(), now(), now(),
            '{"full_name": "Demo User"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
            false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
        );
        
        -- Create user profile
        INSERT INTO public.user_profiles (id, email)
        VALUES (demo_user_id, 'demo@cryptotracker.com');
    END IF;
    
    -- Clear any existing transactions for clean demo
    DELETE FROM public.transactions WHERE user_id = demo_user_id;
    
    -- Add sample transactions with proper structure
    INSERT INTO public.transactions (
        id, user_id, crypto_id, crypto_symbol, crypto_name, crypto_icon_url,
        transaction_type, amount, price_per_unit, transaction_date, notes
    ) VALUES
    (
        btc_transaction_id, demo_user_id, 'bitcoin', 'BTC', 'Bitcoin',
        'https://assets.coingecko.com/coins/images/1/large/bitcoin.png',
        'buy'::public.transaction_type, 0.25, 45000.00, '2024-01-15 10:00:00+00', 'Initial Bitcoin investment'
    ),
    (
        eth_transaction_id, demo_user_id, 'ethereum', 'ETH', 'Ethereum',
        'https://assets.coingecko.com/coins/images/279/large/ethereum.png',
        'buy'::public.transaction_type, 1.5, 3200.00, '2024-01-20 14:30:00+00', 'Ethereum diversification'
    );
    
    RAISE NOTICE 'Demo data created successfully with user ID: %', demo_user_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating demo data: %', SQLERRM;
END $$;

-- Create a function to refresh portfolio data if needed
CREATE OR REPLACE FUNCTION public.get_user_portfolio(user_uuid UUID)
RETURNS TABLE(
    crypto_id TEXT,
    crypto_symbol TEXT,
    crypto_name TEXT,
    crypto_icon_url TEXT,
    total_amount NUMERIC,
    total_invested NUMERIC,
    average_price NUMERIC,
    transaction_count BIGINT,
    last_transaction_date TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    ps.crypto_id,
    ps.crypto_symbol,
    ps.crypto_name,
    ps.crypto_icon_url,
    ps.total_amount,
    ps.total_invested,
    ps.average_price,
    ps.transaction_count,
    ps.last_transaction_date
FROM public.portfolio_summary ps
WHERE ps.user_id = user_uuid;
$$;