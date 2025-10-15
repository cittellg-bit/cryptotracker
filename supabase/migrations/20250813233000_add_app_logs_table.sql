-- Location: supabase/migrations/20250813233000_add_app_logs_table.sql
-- Schema Analysis: Existing tables: transactions, user_profiles
-- Integration Type: Addition - new logs table and related functionality
-- Dependencies: user_profiles table (for foreign key reference)

-- First, add 'admin' to the existing user_role enum
ALTER TYPE public.user_role ADD VALUE 'admin';

-- Create enum type for log levels
CREATE TYPE public.log_level AS ENUM ('debug', 'info', 'warning', 'error', 'critical');

-- Create enum type for log categories
CREATE TYPE public.log_category AS ENUM (
    'api_call', 
    'database', 
    'transaction', 
    'user_action', 
    'navigation', 
    'error', 
    'authentication', 
    'system'
);

-- Create logs table
CREATE TABLE public.app_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    level public.log_level NOT NULL DEFAULT 'info'::public.log_level,
    category public.log_category NOT NULL DEFAULT 'system'::public.log_category,
    message TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    screen_name TEXT,
    function_name TEXT,
    file_path TEXT,
    error_stack TEXT,
    session_id TEXT,
    device_info JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient querying
CREATE INDEX idx_app_logs_user_id ON public.app_logs(user_id);
CREATE INDEX idx_app_logs_level ON public.app_logs(level);
CREATE INDEX idx_app_logs_category ON public.app_logs(category);
CREATE INDEX idx_app_logs_created_at ON public.app_logs(created_at);
CREATE INDEX idx_app_logs_session_id ON public.app_logs(session_id);

-- Create composite index for common queries
CREATE INDEX idx_app_logs_user_level_date ON public.app_logs(user_id, level, created_at);

-- Enable RLS
ALTER TABLE public.app_logs ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for logs - users can only see their own logs, admins can see all
CREATE POLICY "users_view_own_logs"
ON public.app_logs
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid() 
    OR user_id IS NULL 
    OR EXISTS (
        SELECT 1 FROM public.user_profiles up 
        WHERE up.id = auth.uid() 
        AND up.role = 'admin'::public.user_role
    )
);

-- Policy for inserting logs - any authenticated user can insert
CREATE POLICY "authenticated_users_insert_logs"
ON public.app_logs
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy for anonymous log insertion (system logs)
CREATE POLICY "anonymous_system_logs"
ON public.app_logs
FOR INSERT
TO anon
WITH CHECK (user_id IS NULL AND category = 'system'::public.log_category);

-- Function to clean old logs (keep last 30 days for regular users, 90 days for errors)
CREATE OR REPLACE FUNCTION public.cleanup_old_logs()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Delete old non-error logs (30 days)
    DELETE FROM public.app_logs
    WHERE created_at < NOW() - INTERVAL '30 days'
    AND level NOT IN ('error', 'critical');
    
    -- Delete old error logs (90 days)
    DELETE FROM public.app_logs
    WHERE created_at < NOW() - INTERVAL '90 days'
    AND level IN ('error', 'critical');
    
    RAISE NOTICE 'Old logs cleanup completed';
END;
$$;

-- Function to get log summary for user
CREATE OR REPLACE FUNCTION public.get_user_log_summary(user_uuid UUID)
RETURNS TABLE(
    total_logs BIGINT,
    error_count BIGINT,
    warning_count BIGINT,
    info_count BIGINT,
    debug_count BIGINT,
    last_activity TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT 
    COUNT(*) as total_logs,
    COUNT(*) FILTER (WHERE level = 'error') as error_count,
    COUNT(*) FILTER (WHERE level = 'warning') as warning_count,
    COUNT(*) FILTER (WHERE level = 'info') as info_count,
    COUNT(*) FILTER (WHERE level = 'debug') as debug_count,
    MAX(created_at) as last_activity
FROM public.app_logs
WHERE user_id = user_uuid;
$$;

-- Create user preferences table for log settings
CREATE TABLE public.user_log_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    logging_enabled BOOLEAN DEFAULT true,
    log_level public.log_level DEFAULT 'info'::public.log_level,
    categories_enabled JSONB DEFAULT '["api_call", "database", "transaction", "user_action", "navigation", "error", "authentication", "system"]'::jsonb,
    max_logs_per_session INTEGER DEFAULT 1000,
    auto_export_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Index for user preferences
CREATE INDEX idx_user_log_preferences_user_id ON public.user_log_preferences(user_id);

-- Enable RLS for preferences
ALTER TABLE public.user_log_preferences ENABLE ROW LEVEL SECURITY;

-- RLS policy for log preferences
CREATE POLICY "users_manage_own_log_preferences"
ON public.user_log_preferences
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Function to initialize user log preferences
CREATE OR REPLACE FUNCTION public.initialize_user_log_preferences()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.user_log_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Trigger to create default log preferences for new users
CREATE TRIGGER trigger_initialize_user_log_preferences
    AFTER INSERT ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_user_log_preferences();

-- Mock data for testing
DO $$
DECLARE
    existing_user_id UUID;
    sample_session_id TEXT := 'test-session-' || gen_random_uuid();
BEGIN
    -- Get existing user ID from user_profiles
    SELECT id INTO existing_user_id FROM public.user_profiles LIMIT 1;
    
    IF existing_user_id IS NOT NULL THEN
        -- Create sample log entries for testing
        INSERT INTO public.app_logs (user_id, level, category, message, details, screen_name, function_name, session_id, device_info) VALUES
            (existing_user_id, 'info', 'user_action', 'User navigated to portfolio dashboard', '{"previous_screen": "splash"}', 'Portfolio Dashboard', 'navigateToDashboard', sample_session_id, '{"platform": "android", "version": "14"}'),
            (existing_user_id, 'info', 'api_call', 'Fetching cryptocurrency prices', '{"endpoint": "/api/crypto/prices", "method": "GET"}', 'Markets Screen', 'fetchCryptoPrices', sample_session_id, '{"platform": "android", "version": "14"}'),
            (existing_user_id, 'info', 'database', 'Successfully saved transaction', '{"crypto": "BTC", "amount": 0.5, "type": "buy"}', 'Add Transaction', 'saveTransaction', sample_session_id, '{"platform": "android", "version": "14"}'),
            (existing_user_id, 'warning', 'api_call', 'API rate limit approaching', '{"requests_remaining": 10, "reset_time": "2025-08-13T23:45:00Z"}', 'Markets Screen', 'checkRateLimit', sample_session_id, '{"platform": "android", "version": "14"}'),
            (existing_user_id, 'error', 'authentication', 'Failed to refresh auth token', '{"error_code": "TOKEN_EXPIRED", "retry_count": 3}', 'Settings', 'refreshAuthToken', sample_session_id, '{"platform": "android", "version": "14"}');
            
        -- Create default log preferences for existing user
        INSERT INTO public.user_log_preferences (user_id) 
        VALUES (existing_user_id) 
        ON CONFLICT (user_id) DO NOTHING;
        
        RAISE NOTICE 'Sample logs and preferences created for existing user';
    ELSE
        RAISE NOTICE 'No existing users found. Create user profiles first.';
    END IF;
END $$;