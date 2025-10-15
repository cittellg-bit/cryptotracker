-- Location: supabase/migrations/20250817035704_add_refresh_portfolio_summary_function.sql
-- Schema Analysis: Existing crypto portfolio system with transactions and portfolio_summary tables
-- Integration Type: addition - adding missing database function
-- Dependencies: transactions, portfolio_summary, user_profiles tables

-- Create the missing refresh_portfolio_summary function
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary(user_uuid UUID DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_user_id UUID;
BEGIN
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

-- Create overloaded version that works without parameters (for the current error)
CREATE OR REPLACE FUNCTION public.refresh_portfolio_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Call the main function with current user
    PERFORM public.refresh_portfolio_summary(auth.uid());
END;
$$;

-- Create trigger function to auto-refresh portfolio when transactions change
CREATE OR REPLACE FUNCTION public.refresh_user_portfolio_on_transaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
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

-- Create triggers on transactions table to auto-refresh portfolio
DROP TRIGGER IF EXISTS trigger_refresh_portfolio_on_insert ON public.transactions;
CREATE TRIGGER trigger_refresh_portfolio_on_insert
    AFTER INSERT ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.refresh_user_portfolio_on_transaction();

DROP TRIGGER IF EXISTS trigger_refresh_portfolio_on_update ON public.transactions;
CREATE TRIGGER trigger_refresh_portfolio_on_update
    AFTER UPDATE ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.refresh_user_portfolio_on_transaction();

DROP TRIGGER IF EXISTS trigger_refresh_portfolio_on_delete ON public.transactions;
CREATE TRIGGER trigger_refresh_portfolio_on_delete
    AFTER DELETE ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.refresh_user_portfolio_on_transaction();

-- Refresh existing portfolio data for all users (one-time update)
DO $$
DECLARE
    user_record RECORD;
BEGIN
    -- Refresh portfolio summary for all users who have transactions
    FOR user_record IN 
        SELECT DISTINCT user_id FROM public.transactions
    LOOP
        PERFORM public.refresh_portfolio_summary(user_record.user_id);
    END LOOP;
END $$;