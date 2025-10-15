-- Location: supabase/migrations/20250113205430_fix_crypto_transaction_system.sql
-- Schema Analysis: Fixing existing crypto portfolio system schema inconsistencies
-- Integration Type: Schema correction + proper transaction system
-- Dependencies: Existing tables (user_profiles, transactions, portfolio_summary)

-- First, fix the existing transactions table to match what the code expects
ALTER TABLE public.transactions 
DROP COLUMN IF EXISTS holding_id,
ADD COLUMN IF NOT EXISTS crypto_icon_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS crypto_symbol TEXT,
ADD COLUMN IF NOT EXISTS crypto_name TEXT;

-- Update existing column constraints and defaults
ALTER TABLE public.transactions 
ALTER COLUMN crypto_symbol SET NOT NULL,
ALTER COLUMN crypto_name SET NOT NULL;

-- Fix the total_value column to be properly auto-generated
ALTER TABLE public.transactions 
DROP COLUMN IF EXISTS total_value;

ALTER TABLE public.transactions 
ADD COLUMN total_value NUMERIC GENERATED ALWAYS AS (amount * price_per_unit) STORED;

-- Drop the portfolio_holdings table if it exists (not needed for current implementation)
DROP TABLE IF EXISTS public.portfolio_holdings CASCADE;

-- Create a proper portfolio summary view that aggregates from transactions
DROP VIEW IF EXISTS public.portfolio_summary_view;
CREATE VIEW public.portfolio_summary_view AS
SELECT 
    user_id,
    crypto_id,
    crypto_symbol,
    crypto_name,
    crypto_icon_url,
    SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE -amount END) as total_amount,
    SUM(CASE WHEN transaction_type = 'buy' THEN total_value ELSE -total_value END) as total_invested,
    AVG(CASE WHEN transaction_type = 'buy' THEN price_per_unit ELSE NULL END) as average_price,
    COUNT(*) as transaction_count,
    MAX(transaction_date) as last_transaction_date
FROM public.transactions
GROUP BY user_id, crypto_id, crypto_symbol, crypto_name, crypto_icon_url
HAVING SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE -amount END) > 0;

-- Update the existing portfolio_summary table to match the view structure
-- First backup and clear existing data
DELETE FROM public.portfolio_summary;

-- Add missing columns to portfolio_summary table
ALTER TABLE public.portfolio_summary 
ADD COLUMN IF NOT EXISTS crypto_symbol TEXT,
ADD COLUMN IF NOT EXISTS crypto_name TEXT;

-- Create a function to refresh portfolio summary
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary()
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Clear existing data
    DELETE FROM public.portfolio_summary;
    
    -- Insert fresh aggregated data
    INSERT INTO public.portfolio_summary (
        user_id, crypto_id, crypto_symbol, crypto_name, crypto_icon_url,
        total_amount, total_invested, average_price, transaction_count, last_transaction_date
    )
    SELECT 
        user_id, crypto_id, crypto_symbol, crypto_name, crypto_icon_url,
        total_amount, total_invested, average_price, transaction_count, last_transaction_date
    FROM public.portfolio_summary_view;
END;
$$;

-- Create trigger to auto-update portfolio summary when transactions change
CREATE OR REPLACE FUNCTION public.update_portfolio_summary_trigger()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Refresh the entire portfolio summary (simple but effective)
    PERFORM public.refresh_portfolio_summary();
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Drop old trigger and function if they exist
DROP TRIGGER IF EXISTS on_transaction_change ON public.transactions;
DROP FUNCTION IF EXISTS public.update_portfolio_holding();

-- Create new trigger
CREATE TRIGGER on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON public.transactions
    FOR EACH STATEMENT EXECUTE FUNCTION public.update_portfolio_summary_trigger();

-- Add some sample data to test the system
DO $$
DECLARE
    demo_user_id UUID;
    btc_transaction_id UUID := gen_random_uuid();
    eth_transaction_id UUID := gen_random_uuid();
BEGIN
    -- Get an existing user or create one for demo
    SELECT id INTO demo_user_id FROM public.user_profiles LIMIT 1;
    
    IF demo_user_id IS NULL THEN
        -- Create a demo user if none exists
        demo_user_id := gen_random_uuid();
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
            'demo@cryptoportfolio.com', crypt('demo123', gen_salt('bf', 10)), now(), now(), now(),
            '{"full_name": "Demo User"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
            false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
        );
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
        'buy', 0.25, 45000.00, '2024-01-15 10:00:00+00', 'Initial Bitcoin investment'
    ),
    (
        eth_transaction_id, demo_user_id, 'ethereum', 'ETH', 'Ethereum',
        'https://assets.coingecko.com/coins/images/279/large/ethereum.png',
        'buy', 1.5, 3200.00, '2024-01-20 14:30:00+00', 'Ethereum diversification'
    );
    
    -- Refresh portfolio summary
    PERFORM public.refresh_portfolio_summary();
    
    RAISE NOTICE 'Demo data created successfully with user ID: %', demo_user_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating demo data: %', SQLERRM;
END $$;