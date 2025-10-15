-- Remove the problematic refresh_portfolio_summary functions that cause PGRST203 error
-- This fixes the function overloading conflict by removing the ambiguous function signatures

-- Drop the overloaded functions that are causing PostgrestException PGRST203
-- The application will now use direct database queries instead

DROP FUNCTION IF EXISTS public.refresh_portfolio_summary();
DROP FUNCTION IF EXISTS public.refresh_portfolio_summary(user_uuid UUID);

-- Note: The portfolio_summary table is still automatically maintained by triggers
-- on the transactions table, so manual refresh functions are not necessary.
-- The triggers handle portfolio updates when transactions are inserted/updated/deleted.

-- The application code now uses direct SQL queries to rebuild portfolio summaries
-- when needed, avoiding the function overloading conflict entirely.