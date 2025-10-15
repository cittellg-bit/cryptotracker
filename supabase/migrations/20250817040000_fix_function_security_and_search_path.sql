-- Location: supabase/migrations/20250817040000_fix_function_security_and_search_path.sql
-- Schema Analysis: Existing crypto portfolio system with functions needing security updates
-- Integration Type: modificative - updating existing functions for security compliance
-- Dependencies: All existing functions require explicit search path for security

-- Fix handle_new_user function with explicit search path
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
    INSERT INTO public.user_profiles (id, email)
    VALUES (NEW.id, COALESCE(NEW.email, 'user@cryptotracker.app'))
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

-- Fix refresh_portfolio_summary function (with parameters) with explicit search path
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary(user_uuid uuid DEFAULT NULL::uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_user_id UUID;
BEGIN
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
    -- If user_uuid is provided, use it; otherwise use current authenticated user
    IF user_uuid IS NOT NULL THEN
        target_user_id := user_uuid;
    ELSE
        target_user_id := auth.uid();
    END IF;

    -- Exit if no valid user ID
    IF target_user_id IS NULL THEN
        RETURN;
    END IF;

    -- Delete existing portfolio summary for the user
    DELETE FROM public.portfolio_summary 
    WHERE user_id = target_user_id;

    -- Recalculate and insert fresh portfolio summary
    INSERT INTO public.portfolio_summary (
        user_id,
        crypto_id,
        crypto_symbol,
        crypto_name,
        crypto_icon_url,
        total_amount,
        total_invested,
        average_price,
        transaction_count,
        last_transaction_date
    )
    SELECT 
        t.user_id,
        t.crypto_id,
        t.crypto_symbol,
        t.crypto_name,
        t.crypto_icon_url,
        SUM(
            CASE 
                WHEN t.transaction_type = 'buy' THEN t.amount
                WHEN t.transaction_type = 'sell' THEN -t.amount
                ELSE 0
            END
        ) as total_amount,
        SUM(
            CASE 
                WHEN t.transaction_type = 'buy' THEN (t.amount * t.price_per_unit)
                WHEN t.transaction_type = 'sell' THEN -(t.amount * t.price_per_unit)
                ELSE 0
            END
        ) as total_invested,
        CASE 
            WHEN SUM(
                CASE 
                    WHEN t.transaction_type = 'buy' THEN t.amount
                    WHEN t.transaction_type = 'sell' THEN -t.amount
                    ELSE 0
                END
            ) > 0 THEN
                SUM(
                    CASE 
                        WHEN t.transaction_type = 'buy' THEN (t.amount * t.price_per_unit)
                        WHEN t.transaction_type = 'sell' THEN -(t.amount * t.price_per_unit)
                        ELSE 0
                    END
                ) / SUM(
                    CASE 
                        WHEN t.transaction_type = 'buy' THEN t.amount
                        WHEN t.transaction_type = 'sell' THEN -t.amount
                        ELSE 0
                    END
                )
            ELSE 0
        END as average_price,
        COUNT(*) as transaction_count,
        MAX(t.transaction_date) as last_transaction_date
    FROM public.transactions t
    WHERE t.user_id = target_user_id
    GROUP BY t.user_id, t.crypto_id, t.crypto_symbol, t.crypto_name, t.crypto_icon_url
    HAVING SUM(
        CASE 
            WHEN t.transaction_type = 'buy' THEN t.amount
            WHEN t.transaction_type = 'sell' THEN -t.amount
            ELSE 0
        END
    ) > 0; -- Only include cryptos with positive holdings

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error refreshing portfolio summary: %', SQLERRM;
END;
$$;

-- Fix refresh_portfolio_summary function (parameterless version) with explicit search path
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
    -- Call the main function with current user
    PERFORM public.refresh_portfolio_summary(auth.uid());
END;
$$;

-- Fix refresh_user_portfolio_on_transaction function with explicit search path
CREATE OR REPLACE FUNCTION public.refresh_user_portfolio_on_transaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
    -- Refresh portfolio for the affected user
    IF TG_OP = 'DELETE' THEN
        PERFORM public.refresh_portfolio_summary(OLD.user_id);
        RETURN OLD;
    ELSE
        PERFORM public.refresh_portfolio_summary(NEW.user_id);
        RETURN NEW;
    END IF;
END;
$$;

-- Fix get_user_portfolio function with explicit search path
CREATE OR REPLACE FUNCTION public.get_user_portfolio(user_uuid uuid)
RETURNS TABLE(crypto_id text, crypto_symbol text, crypto_name text, crypto_icon_url text, total_amount numeric, total_invested numeric, average_price numeric, transaction_count bigint, last_transaction_date timestamp with time zone)
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
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

-- Fix get_sample_rows function with explicit search path
CREATE OR REPLACE FUNCTION public.get_sample_rows(table_schema text, table_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sample_json jsonb;
BEGIN
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
    EXECUTE format('SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb) FROM (SELECT * FROM %I.%I LIMIT 2) t', table_schema, table_name) INTO sample_json;
    RETURN sample_json;
END;
$$;