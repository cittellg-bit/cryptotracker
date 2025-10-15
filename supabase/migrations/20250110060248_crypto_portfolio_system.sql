-- Location: supabase/migrations/20250110060248_crypto_portfolio_system.sql
-- Schema Analysis: New Supabase project - creating crypto portfolio system from scratch
-- Integration Type: Complete authentication + portfolio management system
-- Dependencies: auth.users (Supabase built-in)

-- 1. Custom Types
CREATE TYPE public.transaction_type AS ENUM ('buy', 'sell');
CREATE TYPE public.user_role AS ENUM ('user', 'premium');

-- 2. Core Tables - User profiles as intermediary
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role public.user_role DEFAULT 'user'::public.user_role,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Portfolio Holdings (aggregated cryptocurrency holdings)
CREATE TABLE public.portfolio_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    crypto_id TEXT NOT NULL, -- e.g., 'bitcoin', 'ethereum'
    symbol TEXT NOT NULL, -- e.g., 'BTC', 'ETH'
    name TEXT NOT NULL, -- e.g., 'Bitcoin', 'Ethereum'
    icon_url TEXT,
    total_amount DECIMAL(20, 8) DEFAULT 0,
    total_invested DECIMAL(15, 2) DEFAULT 0,
    average_price DECIMAL(15, 8) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, crypto_id)
);

-- 4. Transactions (individual buy/sell records)
CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    holding_id UUID REFERENCES public.portfolio_holdings(id) ON DELETE CASCADE,
    crypto_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    name TEXT NOT NULL,
    transaction_type public.transaction_type DEFAULT 'buy'::public.transaction_type,
    amount DECIMAL(20, 8) NOT NULL CHECK (amount > 0),
    price DECIMAL(15, 8) NOT NULL CHECK (price > 0),
    total_value DECIMAL(15, 2) GENERATED ALWAYS AS (amount * price) STORED,
    transaction_date TIMESTAMPTZ NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Essential Indexes
CREATE INDEX idx_user_profiles_user_id ON public.user_profiles(id);
CREATE INDEX idx_portfolio_holdings_user_id ON public.portfolio_holdings(user_id);
CREATE INDEX idx_portfolio_holdings_crypto_id ON public.portfolio_holdings(crypto_id);
CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX idx_transactions_holding_id ON public.transactions(holding_id);
CREATE INDEX idx_transactions_crypto_id ON public.transactions(crypto_id);
CREATE INDEX idx_transactions_date ON public.transactions(transaction_date DESC);

-- 6. Functions for portfolio calculations
CREATE OR REPLACE FUNCTION public.update_portfolio_holding()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    holding_record public.portfolio_holdings%ROWTYPE;
    total_buy_amount DECIMAL(20, 8) := 0;
    total_sell_amount DECIMAL(20, 8) := 0;
    total_buy_value DECIMAL(15, 2) := 0;
    current_amount DECIMAL(20, 8);
    current_invested DECIMAL(15, 2);
    avg_price DECIMAL(15, 8);
BEGIN
    -- Get or create portfolio holding
    SELECT * INTO holding_record 
    FROM public.portfolio_holdings 
    WHERE user_id = NEW.user_id AND crypto_id = NEW.crypto_id;
    
    IF NOT FOUND THEN
        INSERT INTO public.portfolio_holdings (user_id, crypto_id, symbol, name, icon_url)
        VALUES (NEW.user_id, NEW.crypto_id, NEW.symbol, NEW.name, '')
        RETURNING * INTO holding_record;
    END IF;
    
    -- Calculate totals from all transactions for this holding
    SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = 'buy' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN transaction_type = 'sell' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN transaction_type = 'buy' THEN total_value ELSE 0 END), 0)
    INTO total_buy_amount, total_sell_amount, total_buy_value
    FROM public.transactions 
    WHERE holding_id = holding_record.id;
    
    -- Calculate current holdings
    current_amount := total_buy_amount - total_sell_amount;
    current_invested := total_buy_value;
    
    -- Calculate average price (avoid division by zero)
    IF current_amount > 0 AND total_buy_value > 0 THEN
        avg_price := total_buy_value / total_buy_amount;
    ELSE
        avg_price := 0;
    END IF;
    
    -- Update portfolio holding
    UPDATE public.portfolio_holdings
    SET 
        total_amount = current_amount,
        total_invested = current_invested,
        average_price = avg_price,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = holding_record.id;
    
    RETURN NEW;
END;
$$;

-- 7. Automatic profile creation function
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
END;
$$;

-- 8. Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.portfolio_holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- 9. RLS Policies - Pattern 1 for user_profiles, Pattern 2 for others
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "users_manage_own_portfolio_holdings"
ON public.portfolio_holdings
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_transactions"
ON public.transactions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 10. Triggers
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_portfolio_holding();

-- 11. Mock Data for Testing
DO $$
DECLARE
    user1_auth_id UUID := gen_random_uuid();
    user2_auth_id UUID := gen_random_uuid();
    holding1_id UUID := gen_random_uuid();
    holding2_id UUID := gen_random_uuid();
BEGIN
    -- Create test auth users with required fields
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (user1_auth_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'demo@cryptotracker.com', crypt('demo123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Demo User"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user2_auth_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'investor@cryptotracker.com', crypt('invest123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Active Investor"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Create portfolio holdings
    INSERT INTO public.portfolio_holdings (id, user_id, crypto_id, symbol, name, icon_url)
    VALUES
        (holding1_id, user1_auth_id, 'bitcoin', 'BTC', 'Bitcoin', 'https://assets.coingecko.com/coins/images/1/large/bitcoin.png'),
        (holding2_id, user1_auth_id, 'ethereum', 'ETH', 'Ethereum', 'https://assets.coingecko.com/coins/images/279/large/ethereum.png');

    -- Create sample transactions
    INSERT INTO public.transactions (user_id, holding_id, crypto_id, symbol, name, transaction_type, amount, price, transaction_date, notes)
    VALUES
        (user1_auth_id, holding1_id, 'bitcoin', 'BTC', 'Bitcoin', 'buy', 0.5, 45000.00, '2024-01-15 10:00:00+00', 'Initial Bitcoin purchase'),
        (user1_auth_id, holding1_id, 'bitcoin', 'BTC', 'Bitcoin', 'buy', 0.3, 47000.00, '2024-02-01 14:30:00+00', 'DCA strategy purchase'),
        (user1_auth_id, holding2_id, 'ethereum', 'ETH', 'Ethereum', 'buy', 2.0, 3200.00, '2024-01-20 09:15:00+00', 'Ethereum diversification'),
        (user1_auth_id, holding2_id, 'ethereum', 'ETH', 'Ethereum', 'buy', 1.5, 3400.00, '2024-02-10 16:45:00+00', 'Adding more ETH');

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;