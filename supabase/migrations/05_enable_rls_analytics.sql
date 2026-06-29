-- ============================================================================
-- Enable RLS and add basic policies for analytics/advanced schema tables
-- ============================================================================

-- 2. product_embeddings
ALTER TABLE public.product_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read embeddings"
ON public.product_embeddings
FOR SELECT
TO anon, authenticated
USING (true);


-- 3. user_interactions
ALTER TABLE public.user_interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own interactions"
ON public.user_interactions
FOR SELECT
TO authenticated
USING (customer_id = auth.uid());

CREATE POLICY "Users can insert own interactions"
ON public.user_interactions
FOR INSERT
TO authenticated
WITH CHECK (customer_id = auth.uid());


-- 4. recommendation_cache
ALTER TABLE public.recommendation_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own recommendations"
ON public.recommendation_cache
FOR SELECT
TO authenticated
USING (customer_id = auth.uid());


-- 5. user_sessions
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own sessions"
ON public.user_sessions
FOR SELECT
TO authenticated
USING (customer_id = auth.uid());

CREATE POLICY "Users can insert own sessions"
ON public.user_sessions
FOR INSERT
TO authenticated
WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Users can update own sessions"
ON public.user_sessions
FOR UPDATE
TO authenticated
USING (customer_id = auth.uid());


-- 6. page_views
ALTER TABLE public.page_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own page views"
ON public.page_views
FOR SELECT
TO authenticated
USING (customer_id = auth.uid());

CREATE POLICY "Users can insert own page views"
ON public.page_views
FOR INSERT
TO authenticated
WITH CHECK (customer_id = auth.uid());


-- 7. order_metrics
ALTER TABLE public.order_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read metrics for own orders"
ON public.order_metrics
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders 
    WHERE orders.id = order_metrics.order_id 
    AND orders.customer_id = auth.uid()
  )
);


-- 8. product_search_metadata
ALTER TABLE public.product_search_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read product search metadata"
ON public.product_search_metadata
FOR SELECT
TO anon, authenticated
USING (true);
