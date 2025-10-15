-- Location: supabase/migrations/20250822024900_add_exchange_field.sql
-- Schema Analysis: Existing crypto portfolio system with transactions table and portfolio_summary view
-- Integration Type: modificative - adding exchange field to transactions table only
-- Dependencies: transactions table exists, portfolio_summary is a view

-- Add exchange field to transactions table only
ALTER TABLE public.transactions
ADD COLUMN exchange TEXT DEFAULT 'Unknown';

-- Create index for exchange field in transactions for better performance
CREATE INDEX idx_transactions_exchange ON public.transactions(exchange);

-- Drop the existing portfolio_summary view if it exists as a view
DROP VIEW IF EXISTS public.portfolio_summary;

-- Recreate portfolio_summary as a view that includes the exchange field
CREATE VIEW public.portfolio_summary AS
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
    MAX(t.transaction_date) as last_transaction_date,
    -- For exchange, we take the most recent transaction's exchange
    -- If there are multiple exchanges, this approach takes the latest one
    (SELECT exchange FROM public.transactions t2 
     WHERE t2.user_id = t.user_id 
     AND t2.crypto_id = t.crypto_id 
     ORDER BY t2.transaction_date DESC 
     LIMIT 1) as exchange
FROM public.transactions t
GROUP BY t.user_id, t.crypto_id, t.crypto_symbol, t.crypto_name, t.crypto_icon_url
HAVING SUM(
    CASE 
        WHEN t.transaction_type = 'buy' THEN t.amount
        WHEN t.transaction_type = 'sell' THEN -t.amount
        ELSE 0
    END
) > 0; -- Only include cryptos with positive holdings

-- Update existing transactions with default exchange value
UPDATE public.transactions 
SET exchange = 'Binance' 
WHERE exchange IS NULL OR exchange = 'Unknown';

-- Enable RLS on the view (if needed)
-- Note: Views inherit RLS from underlying tables, so this might not be necessary
-- ALTER VIEW public.portfolio_summary ENABLE ROW LEVEL SECURITY;