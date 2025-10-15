-- Fix crypto portfolio calculation system
-- Migration to resolve incorrect crypto balance calculations causing portfolio total failures

BEGIN;

-- Drop existing function to recreate with fixed logic
DROP FUNCTION IF EXISTS public.refresh_portfolio_summary(uuid);

-- Create corrected portfolio summary function with proper crypto consolidation
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary(user_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    -- Set an explicit, minimal search path for security
    SET search_path TO pg_catalog, public;
    
    -- Delete existing portfolio summary for the user
    DELETE FROM public.portfolio_summary WHERE user_id = user_uuid;
    
    -- Recalculate and insert fresh portfolio summary with FIXED LOGIC
    -- KEY FIX: Remove exchange from GROUP BY to consolidate crypto holdings properly
    WITH transaction_summary AS (
        SELECT 
            t.crypto_id,
            t.crypto_symbol,
            t.crypto_name,
            t.crypto_icon_url,
            -- Calculate total amounts properly (buy = +, sell = -)
            SUM(CASE 
                WHEN t.transaction_type = 'buy' THEN t.amount
                WHEN t.transaction_type = 'sell' THEN -t.amount
                ELSE 0
            END) as total_amount,
            -- Calculate total invested properly (buy = +, sell = -)
            SUM(CASE 
                WHEN t.transaction_type = 'buy' THEN (t.amount * t.price_per_unit)
                WHEN t.transaction_type = 'sell' THEN -(t.amount * t.price_per_unit)
                ELSE 0
            END) as total_invested,
            COUNT(*) as transaction_count,
            MAX(t.transaction_date) as last_transaction_date,
            -- Get the most recent exchange (prioritize non-Unknown values)
            (
                SELECT t2.exchange 
                FROM public.transactions t2 
                WHERE t2.user_id = user_uuid 
                AND t2.crypto_id = t.crypto_id
                AND t2.exchange IS NOT NULL
                ORDER BY 
                    CASE WHEN t2.exchange = 'Unknown' THEN 1 ELSE 0 END,
                    t2.transaction_date DESC 
                LIMIT 1
            ) as primary_exchange
        FROM public.transactions t
        WHERE t.user_id = user_uuid
        -- KEY FIX: Group only by crypto identifiers, NOT by exchange
        GROUP BY t.crypto_id, t.crypto_symbol, t.crypto_name, t.crypto_icon_url
        -- Only include cryptos with positive holdings after all transactions
        HAVING SUM(CASE 
            WHEN t.transaction_type = 'buy' THEN t.amount
            WHEN t.transaction_type = 'sell' THEN -t.amount
            ELSE 0
        END) > 0
    )
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
        last_transaction_date,
        exchange
    )
    SELECT 
        user_uuid,
        ts.crypto_id,
        ts.crypto_symbol,
        ts.crypto_name,
        ts.crypto_icon_url,
        ts.total_amount,
        ts.total_invested,
        -- Fixed average price calculation with proper null handling
        CASE 
            WHEN ts.total_amount > 0 THEN ABS(ts.total_invested / ts.total_amount)
            ELSE 0
        END as average_price,
        ts.transaction_count,
        ts.last_transaction_date,
        COALESCE(ts.primary_exchange, 'Unknown') as exchange
    FROM transaction_summary ts
    WHERE ts.total_amount > 0;
    
    -- Log the refresh operation with details
    RAISE NOTICE 'Portfolio summary refreshed for user: % (% holdings)', 
        user_uuid, 
        (SELECT COUNT(*) FROM public.portfolio_summary WHERE user_id = user_uuid);
    
END;
$function$;

-- Add function to validate portfolio data integrity
CREATE OR REPLACE FUNCTION public.validate_portfolio_integrity(user_uuid uuid)
RETURNS TABLE(
    crypto_id text,
    expected_holdings numeric,
    portfolio_holdings numeric,
    discrepancy numeric,
    status text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    -- Set search path for security
    SET search_path TO pg_catalog, public;
    
    RETURN QUERY
    WITH transaction_totals AS (
        SELECT 
            t.crypto_id,
            SUM(CASE 
                WHEN t.transaction_type = 'buy' THEN t.amount
                WHEN t.transaction_type = 'sell' THEN -t.amount
                ELSE 0
            END) as calculated_holdings
        FROM public.transactions t
        WHERE t.user_id = user_uuid
        GROUP BY t.crypto_id
    ),
    portfolio_totals AS (
        SELECT 
            p.crypto_id,
            p.total_amount as portfolio_holdings
        FROM public.portfolio_summary p
        WHERE p.user_id = user_uuid
    )
    SELECT 
        COALESCE(tt.crypto_id, pt.crypto_id) as crypto_id,
        COALESCE(tt.calculated_holdings, 0) as expected_holdings,
        COALESCE(pt.portfolio_holdings, 0) as portfolio_holdings,
        COALESCE(tt.calculated_holdings, 0) - COALESCE(pt.portfolio_holdings, 0) as discrepancy,
        CASE 
            WHEN ABS(COALESCE(tt.calculated_holdings, 0) - COALESCE(pt.portfolio_holdings, 0)) < 0.00000001 THEN 'CORRECT'
            WHEN tt.crypto_id IS NULL THEN 'MISSING_FROM_TRANSACTIONS'
            WHEN pt.crypto_id IS NULL THEN 'MISSING_FROM_PORTFOLIO'
            ELSE 'DISCREPANCY'
        END as status
    FROM transaction_totals tt
    FULL OUTER JOIN portfolio_totals pt ON tt.crypto_id = pt.crypto_id
    ORDER BY ABS(COALESCE(tt.calculated_holdings, 0) - COALESCE(pt.portfolio_holdings, 0)) DESC;
END;
$function$;

-- Add function to force refresh all user portfolios (admin utility)
CREATE OR REPLACE FUNCTION public.refresh_all_portfolios()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    user_record RECORD;
    refresh_count integer := 0;
BEGIN
    -- Set search path for security
    SET search_path TO pg_catalog, public;
    
    -- Refresh portfolio for each user who has transactions
    FOR user_record IN 
        SELECT DISTINCT user_id 
        FROM public.transactions 
        WHERE user_id IS NOT NULL
    LOOP
        PERFORM public.refresh_portfolio_summary(user_record.user_id);
        refresh_count := refresh_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Refreshed portfolios for % users', refresh_count;
    RETURN refresh_count;
END;
$function$;

-- Execute immediate refresh for all existing users to fix current data
SELECT public.refresh_all_portfolios();

-- Add helpful comments
COMMENT ON FUNCTION public.refresh_portfolio_summary(uuid) IS 'Fixed function that properly consolidates crypto holdings across exchanges to prevent duplicate entries and incorrect portfolio totals';
COMMENT ON FUNCTION public.validate_portfolio_integrity(uuid) IS 'Diagnostic function to validate portfolio calculations match transaction data';
COMMENT ON FUNCTION public.refresh_all_portfolios() IS 'Admin utility to refresh all user portfolios - useful after schema changes';

COMMIT;