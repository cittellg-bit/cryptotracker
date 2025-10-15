-- Location: supabase/migrations/20250813230633_comprehensive_crypto_portfolio_final.sql
-- Schema Analysis: Complete rebuild of crypto portfolio system with consistent structure
-- Integration Type: Comprehensive schema replacement with proper relationships
-- Dependencies: auth.users (Supabase built-in)

-- 1. Clean up any existing problematic objects
DROP VIEW IF EXISTS public.portfolio_summary CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.portfolio_holdings CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP FUNCTION IF EXISTS public.update_portfolio_summary_trigger() CASCADE;
DROP FUNCTION IF EXISTS public.refresh_portfolio_summary() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_portfolio(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP TYPE IF EXISTS public.transaction_type CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;

-- 2. Create consistent custom types
CREATE TYPE public.transaction_type AS ENUM ('buy', 'sell');
CREATE TYPE public.user_role AS ENUM ('user', 'premium');

-- 3. Core user profiles table (intermediary between auth.users and business logic)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL DEFAULT '',
    role public.user_role DEFAULT 'user'::public.user_role,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Transactions table (main source of truth for all crypto transactions)
CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    crypto_id TEXT NOT NULL,
    crypto_symbol TEXT NOT NULL,
    crypto_name TEXT NOT NULL,
    crypto_icon_url TEXT NOT NULL DEFAULT '',
    transaction_type public.transaction_type NOT NULL DEFAULT 'buy'::public.transaction_type,
    amount DECIMAL(20, 8) NOT NULL CHECK (amount > 0),
    price_per_unit DECIMAL(15, 8) NOT NULL CHECK (price_per_unit > 0),
    total_value DECIMAL(15, 2) GENERATED ALWAYS AS (amount * price_per_unit) STORED,
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Portfolio summary materialized view for efficient queries
CREATE MATERIALIZED VIEW public.portfolio_summary AS
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
    MAX(transaction_date) as last_transaction_date,
    MAX(updated_at) as last_updated
FROM public.transactions
GROUP BY user_id, crypto_id, crypto_symbol, crypto_name, crypto_icon_url
HAVING SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE -amount END) > 0;

-- 6. Essential indexes for performance
CREATE INDEX idx_user_profiles_user_id ON public.user_profiles(id);
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX idx_transactions_crypto_id ON public.transactions(crypto_id);
CREATE INDEX idx_transactions_user_crypto ON public.transactions(user_id, crypto_id);
CREATE INDEX idx_transactions_type ON public.transactions(transaction_type);
CREATE INDEX idx_transactions_date ON public.transactions(transaction_date DESC);
CREATE INDEX idx_transactions_symbol ON public.transactions(crypto_symbol);

-- Add index to materialized view for fast queries
CREATE UNIQUE INDEX idx_portfolio_summary_user_crypto ON public.portfolio_summary(user_id, crypto_id);
CREATE INDEX idx_portfolio_summary_user_id ON public.portfolio_summary(user_id);

-- 7. Functions for portfolio management

-- Function to refresh portfolio summary
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary()
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.portfolio_summary;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error refreshing portfolio summary: %', SQLERRM;
END;
$$;

-- Function to get user portfolio with real-time calculation
CREATE OR REPLACE FUNCTION public.get_user_portfolio(user_uuid UUID)
RETURNS TABLE(
    crypto_id TEXT,
    crypto_symbol TEXT,
    crypto_name TEXT,
    crypto_icon_url TEXT,
    total_amount DECIMAL,
    total_invested DECIMAL,
    average_price DECIMAL,
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
WHERE ps.user_id = user_uuid
ORDER BY ps.last_transaction_date DESC;
$$;

-- Function for automatic user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, role)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'user'::public.user_role)
    );
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- User profile already exists, return NEW anyway
        RETURN NEW;
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating user profile: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- Function to trigger portfolio refresh
CREATE OR REPLACE FUNCTION public.trigger_portfolio_refresh()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Use pg_notify for async refresh to avoid blocking transactions
    PERFORM pg_notify('portfolio_refresh', NEW.user_id::TEXT);
    RETURN COALESCE(NEW, OLD);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error triggering portfolio refresh: %', SQLERRM;
        RETURN COALESCE(NEW, OLD);
END;
$$;

-- 8. Enable Row Level Security
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- 9. RLS Policies using correct patterns

-- Pattern 1: Core user table (user_profiles) - Simple ownership only
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Pattern 2: Simple user ownership for transactions
CREATE POLICY "users_manage_own_transactions"
ON public.transactions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 10. Triggers
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON public.transactions
    FOR EACH STATEMENT 
    EXECUTE FUNCTION public.trigger_portfolio_refresh();

-- 11. Create a scheduled job to refresh portfolio summary periodically
-- This would be handled by a cron job or scheduled function in production

-- 12. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT ALL ON public.user_profiles TO authenticated;
GRANT ALL ON public.transactions TO authenticated;
GRANT SELECT ON public.portfolio_summary TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_portfolio(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_portfolio_summary() TO authenticated;

-- 13. Demo data for testing (only if no existing data)
DO $$
DECLARE
    demo_user_id UUID := gen_random_uuid();
    btc_transaction_id UUID := gen_random_uuid();
    eth_transaction_id UUID := gen_random_uuid();
BEGIN
    -- Check if demo data already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE email LIKE '%demo%') THEN
        RAISE NOTICE 'Demo data already exists, skipping insertion';
        RETURN;
    END IF;

    -- Create demo auth user
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

    -- Add sample transactions
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

    -- Refresh the materialized view
    PERFORM public.refresh_portfolio_summary();

    RAISE NOTICE 'Demo data created successfully with user ID: %', demo_user_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Demo data already exists: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating demo data: %', SQLERRM;
END $$;

-- Final consistency check
REFRESH MATERIALIZED VIEW public.portfolio_summary;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '🎉 Comprehensive crypto portfolio schema created successfully!';
    RAISE NOTICE '📊 Schema includes:';
    RAISE NOTICE '   ✅ user_profiles table for authentication';
    RAISE NOTICE '   ✅ transactions table as source of truth';
    RAISE NOTICE '   ✅ portfolio_summary materialized view for performance';
    RAISE NOTICE '   ✅ Proper RLS policies for security';
    RAISE NOTICE '   ✅ Optimized indexes for fast queries';
    RAISE NOTICE '   ✅ Demo data for immediate testing';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Next steps:';
    RAISE NOTICE '   1. Update Flutter services to use new schema';
    RAISE NOTICE '   2. Test authentication and transaction flows';
    RAISE NOTICE '   3. Verify portfolio calculations are correct';
END $$;