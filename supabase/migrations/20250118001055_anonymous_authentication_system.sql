-- Location: supabase/migrations/20250118001055_anonymous_authentication_system.sql
-- Schema Analysis: Existing crypto tracker with user_profiles, transactions, portfolio_summary (view)
-- Integration Type: Extension - Adding anonymous authentication to existing system
-- Dependencies: user_profiles (existing), transactions (existing), portfolio_summary (view - existing)

-- 1. Create anonymous authentication helper functions
CREATE OR REPLACE FUNCTION public.is_anonymous_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT COALESCE((auth.jwt()->>'is_anonymous')::boolean, false);
$$;

CREATE OR REPLACE FUNCTION public.delete_old_anonymous_users(days_threshold integer DEFAULT 7)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count integer;
BEGIN
  -- Set an explicit, minimal search path for security
  SET search_path TO pg_catalog, public;
  
  DELETE FROM auth.users
  WHERE is_anonymous = true 
    AND created_at < NOW() - INTERVAL '1 day' * days_threshold;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$;

-- 2. Update existing RLS policies to support anonymous users

-- Drop existing user_profiles policies and create new ones that support anonymous
DROP POLICY IF EXISTS "users_own_profiles" ON public.user_profiles;

-- Allow anonymous users to read public profiles but not create their own
CREATE POLICY "public_profiles_visible_to_all" 
ON public.user_profiles 
FOR SELECT 
TO public
USING (true);

-- Only permanent (non-anonymous) users can create profiles
CREATE POLICY "only_permanent_users_can_create_profiles"
ON public.user_profiles 
FOR INSERT 
TO authenticated
WITH CHECK (NOT public.is_anonymous_user());

-- Only permanent users can update/delete their profiles
CREATE POLICY "permanent_users_manage_own_profiles"
ON public.user_profiles
FOR UPDATE 
TO authenticated
USING (id = auth.uid() AND NOT public.is_anonymous_user())
WITH CHECK (id = auth.uid() AND NOT public.is_anonymous_user());

CREATE POLICY "permanent_users_delete_own_profiles"
ON public.user_profiles
FOR DELETE 
TO authenticated
USING (id = auth.uid() AND NOT public.is_anonymous_user());

-- Update transactions policies for anonymous users
DROP POLICY IF EXISTS "users_own_transactions" ON public.transactions;

-- Anonymous users can create transactions (for demo/trial purposes)
CREATE POLICY "anonymous_users_can_create_transactions"
ON public.transactions
FOR INSERT 
TO anon
WITH CHECK (true);

-- Authenticated users (both anonymous and permanent) can view their own transactions
CREATE POLICY "users_can_view_own_transactions"
ON public.transactions
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Authenticated users can create their own transactions
CREATE POLICY "authenticated_users_can_create_transactions"
ON public.transactions
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Only permanent (non-anonymous) users can update/delete transactions
CREATE POLICY "permanent_users_can_update_transactions"
ON public.transactions 
FOR UPDATE 
TO authenticated
USING (user_id = auth.uid() AND NOT public.is_anonymous_user())
WITH CHECK (user_id = auth.uid() AND NOT public.is_anonymous_user());

CREATE POLICY "permanent_users_can_delete_transactions"
ON public.transactions 
FOR DELETE 
TO authenticated
USING (user_id = auth.uid() AND NOT public.is_anonymous_user());

-- NOTE: portfolio_summary is a VIEW, not a TABLE
-- Views cannot have RLS enabled or policies applied
-- Access control for views is handled through the underlying tables
-- The portfolio_summary view inherits security from the transactions table
-- No RLS configuration needed for portfolio_summary view

-- 3. Create cleanup function for old anonymous data
CREATE OR REPLACE FUNCTION public.cleanup_anonymous_user_data(user_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Set an explicit, minimal search path for security
  SET search_path TO pg_catalog, public;
  
  -- Delete in dependency order (children first, then parent)
  -- Note: portfolio_summary is a view, so no direct deletion needed
  DELETE FROM public.transactions WHERE user_id = user_uuid;
  DELETE FROM public.user_profiles WHERE id = user_uuid;
  
  -- Delete auth.users record (if still exists and is anonymous)
  DELETE FROM auth.users 
  WHERE id = user_uuid AND is_anonymous = true;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Cleanup failed for user %: %', user_uuid, SQLERRM;
END;
$$;

-- 4. Create function to promote anonymous user to permanent
CREATE OR REPLACE FUNCTION public.promote_anonymous_to_permanent(
  user_uuid uuid,
  new_email text,
  full_name text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  profile_exists boolean;
BEGIN
  -- Set an explicit, minimal search path for security
  SET search_path TO pg_catalog, public;
  
  -- Check if user profile exists
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = user_uuid
  ) INTO profile_exists;
  
  -- Create or update user profile
  IF profile_exists THEN
    UPDATE public.user_profiles 
    SET email = new_email,
        created_at = COALESCE(created_at, NOW())
    WHERE id = user_uuid;
  ELSE
    INSERT INTO public.user_profiles (id, email)
    VALUES (user_uuid, new_email)
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email;
  END IF;
  
  RETURN true;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Failed to promote user %: %', user_uuid, SQLERRM;
    RETURN false;
END;
$$;

-- 5. Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.is_anonymous_user() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.delete_old_anonymous_users(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_anonymous_user_data(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.promote_anonymous_to_permanent(uuid, text, text) TO authenticated;

-- 6. Create sample anonymous transaction data for testing
DO $$
DECLARE
  anon_user_id uuid := gen_random_uuid();
BEGIN
  -- Create sample anonymous transactions (no auth.users record needed for demo)
  INSERT INTO public.transactions (
    user_id, crypto_id, crypto_name, crypto_symbol, crypto_icon_url,
    amount, price_per_unit, transaction_type, transaction_date, notes
  ) VALUES
    (anon_user_id, 'bitcoin', 'Bitcoin', 'BTC', 'https://assets.coingecko.com/coins/images/1/large/bitcoin.png', 
     0.5, 45000.00, 'buy'::transaction_type, NOW() - INTERVAL '2 days', 'Anonymous demo transaction'),
    (anon_user_id, 'ethereum', 'Ethereum', 'ETH', 'https://assets.coingecko.com/coins/images/279/large/ethereum.png', 
     2.0, 3000.00, 'buy'::transaction_type, NOW() - INTERVAL '1 day', 'Anonymous demo transaction'),
    (anon_user_id, 'cardano', 'Cardano', 'ADA', 'https://assets.coingecko.com/coins/images/975/large/cardano.png', 
     1000.0, 0.50, 'buy'::transaction_type, NOW(), 'Anonymous demo transaction');
     
  RAISE NOTICE 'Sample anonymous transactions created for demo purposes';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Failed to create sample data: %', SQLERRM;
END $$;