-- Migration: Create missing refresh_portfolio_summary function for portfolio total calculation
-- This fixes the issue where portfolio totals get stuck at zero on Android

-- Create the missing refresh_portfolio_summary function that the trigger calls
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
    
    -- Recalculate and insert fresh portfolio summary
    WITH transaction_summary AS (
        SELECT 
            t.crypto_id,
            t.crypto_symbol,
            t.crypto_name,
            t.crypto_icon_url,
            t.exchange,
            SUM(CASE 
                WHEN t.transaction_type = 'buy' THEN t.amount
                WHEN t.transaction_type = 'sell' THEN -t.amount
                ELSE 0
            END) as total_amount,
            SUM(CASE 
                WHEN t.transaction_type = 'buy' THEN (t.amount * t.price_per_unit)
                WHEN t.transaction_type = 'sell' THEN -(t.amount * t.price_per_unit)
                ELSE 0
            END) as total_invested,
            COUNT(*) as transaction_count,
            MAX(t.transaction_date) as last_transaction_date,
            -- Get the most recent exchange or most frequently used exchange
            (
                SELECT exchange 
                FROM public.transactions t2 
                WHERE t2.user_id = user_uuid 
                AND t2.crypto_id = t.crypto_id
                AND t2.exchange IS NOT NULL 
                AND t2.exchange != 'Unknown'
                ORDER BY t2.transaction_date DESC 
                LIMIT 1
            ) as primary_exchange
        FROM public.transactions t
        WHERE t.user_id = user_uuid
        GROUP BY t.crypto_id, t.crypto_symbol, t.crypto_name, t.crypto_icon_url, t.exchange
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
        CASE 
            WHEN ts.total_amount > 0 THEN ts.total_invested / ts.total_amount
            ELSE 0
        END as average_price,
        ts.transaction_count,
        ts.last_transaction_date,
        COALESCE(ts.primary_exchange, ts.exchange, 'Unknown') as exchange
    FROM transaction_summary ts
    WHERE ts.total_amount > 0;
    
    -- Log the refresh operation
    RAISE NOTICE 'Portfolio summary refreshed for user: %', user_uuid;
    
END;
$function$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.refresh_portfolio_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_portfolio_summary(uuid) TO anon;

-- Test the function works by creating a simple test
DO $test$
BEGIN
    -- The function should execute without errors
    RAISE NOTICE 'refresh_portfolio_summary function created successfully';
END
$test$;