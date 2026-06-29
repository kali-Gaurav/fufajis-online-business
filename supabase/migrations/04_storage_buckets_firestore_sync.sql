-- ============================================================================
-- STORAGE BUCKETS + FIRESTORE REFERENCE SYNC
-- ============================================================================
-- Purpose: Setup Supabase Storage buckets for product images, documents, and
--          receipts. Track storage URLs in Firestore for mobile app access.
-- ============================================================================

-- ============================================================================
-- CREATE STORAGE BUCKETS
-- ============================================================================

-- Product Images (public read, shop owner write)
INSERT INTO storage.buckets (id, name, public, file_size_limit, avif_autodetection)
VALUES (
  'product-images',
  'product-images',
  true,  -- Public read for customers
  52428800,  -- 50MB per file
  true
);

-- Customer KYC Documents (private, customer & admin only)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
  'customer-documents',
  'customer-documents',
  false,  -- Private
  10485760  -- 10MB per file
);

-- Order Receipts (private, customer & shop owner only)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
  'order-receipts',
  'order-receipts',
  false,  -- Private
  5242880  -- 5MB per file
);

-- Delivery Proofs (private, delivery & shop owner only)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES (
  'delivery-proofs',
  'delivery-proofs',
  false,  -- Private
  10485760  -- 10MB per file
);

-- ============================================================================
-- STORAGE ACCESS POLICIES
-- ============================================================================

-- PUBLIC: Anyone can read product images
CREATE POLICY "Public can read product images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

-- PRODUCT IMAGES: Shop owners can upload to their shop folder
CREATE POLICY "Shop owners upload product images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- CUSTOMER DOCUMENTS: Users can upload to their own folder
CREATE POLICY "Customers upload own KYC documents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'customer-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- CUSTOMER DOCUMENTS: Users can read their own
CREATE POLICY "Customers read own KYC documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'customer-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ORDER RECEIPTS: Customers can read their own receipts
CREATE POLICY "Customers read own receipts"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'order-receipts'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELIVERY PROOFS: Riders can upload proof for assigned delivery
CREATE POLICY "Riders upload delivery proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'delivery-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================================
-- FIRESTORE REFERENCE TABLE
-- ============================================================================
-- Store references to storage URLs in PostgreSQL so we can sync to Firestore
-- This avoids repeated calls to generate signed URLs

CREATE TABLE IF NOT EXISTS storage_references (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  storage_bucket TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  storage_url TEXT NOT NULL,
  public_url TEXT,  -- For public objects
  signed_url TEXT,  -- Signed URL (if private)
  signed_url_expires_at TIMESTAMP,  -- When signed URL expires

  -- Metadata
  entity_type TEXT,  -- 'product', 'customer', 'receipt', 'delivery'
  entity_id UUID,  -- Reference to product_id, customer_id, order_id, delivery_id
  file_size INT,
  mime_type TEXT,

  created_at TIMESTAMP DEFAULT now(),
  expires_at TIMESTAMP  -- For cleanup of old files
);

CREATE INDEX idx_storage_references_entity ON storage_references(entity_type, entity_id);
CREATE INDEX idx_storage_references_bucket ON storage_references(storage_bucket);
CREATE INDEX idx_storage_references_created ON storage_references(created_at DESC);

-- ============================================================================
-- FUNCTION: Generate and cache signed URL
-- ============================================================================

CREATE OR REPLACE FUNCTION get_storage_signed_url(
  p_bucket TEXT,
  p_path TEXT,
  p_expires_in_hours INT DEFAULT 24
)
RETURNS TABLE(
  signed_url TEXT,
  expires_at TIMESTAMP
) AS $$
DECLARE
  v_expires_at TIMESTAMP := now() + (p_expires_in_hours || ' hours')::INTERVAL;
  v_cached_url TEXT;
BEGIN
  -- Check if cached URL still valid
  SELECT signed_url INTO v_cached_url
  FROM storage_references
  WHERE storage_bucket = p_bucket
  AND storage_path = p_path
  AND signed_url_expires_at > now()
  LIMIT 1;

  IF v_cached_url IS NOT NULL THEN
    RETURN QUERY SELECT v_cached_url, signed_url_expires_at
    FROM storage_references
    WHERE storage_bucket = p_bucket
    AND storage_path = p_path;
  ELSE
    -- Return NULL - Edge Function will generate new signed URL and cache it
    RETURN QUERY SELECT NULL::TEXT, v_expires_at;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTION: Cache storage reference for Firestore sync
-- ============================================================================

CREATE OR REPLACE FUNCTION cache_storage_reference(
  p_bucket TEXT,
  p_path TEXT,
  p_url TEXT,
  p_public_url TEXT,
  p_entity_type TEXT,
  p_entity_id UUID,
  p_file_size INT,
  p_mime_type TEXT
)
RETURNS UUID AS $$
DECLARE
  v_reference_id UUID;
BEGIN
  INSERT INTO storage_references (
    storage_bucket,
    storage_path,
    storage_url,
    public_url,
    entity_type,
    entity_id,
    file_size,
    mime_type
  )
  VALUES (
    p_bucket,
    p_path,
    p_url,
    p_public_url,
    p_entity_type,
    p_entity_id,
    p_file_size,
    p_mime_type
  )
  ON CONFLICT (storage_bucket, storage_path)
  DO UPDATE SET
    storage_url = EXCLUDED.storage_url,
    public_url = EXCLUDED.public_url,
    updated_at = now()
  RETURNING id INTO v_reference_id;

  RETURN v_reference_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CLEANUP: Delete old storage references (daily job)
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_expired_storage_references()
RETURNS INT AS $$
DECLARE
  v_deleted_count INT;
BEGIN
  DELETE FROM storage_references
  WHERE expires_at < now();

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MATERIALIZED VIEW: Storage usage by bucket (for monitoring)
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS storage_usage_by_bucket AS
SELECT
  storage_bucket,
  COUNT(*) as file_count,
  SUM(file_size) as total_size_bytes,
  SUM(file_size) / 1024.0 / 1024.0 as total_size_mb,
  MAX(created_at) as latest_upload
FROM storage_references
WHERE expires_at IS NULL OR expires_at > now()
GROUP BY storage_bucket;

CREATE UNIQUE INDEX idx_storage_usage_bucket ON storage_usage_by_bucket(storage_bucket);

-- ============================================================================
-- SUCCESS INDICATORS
-- ============================================================================
/*
After this migration, verify:

✅ 4 storage buckets created:
   SELECT * FROM storage.buckets;

✅ Storage policies active:
   SELECT * FROM storage.policies;

✅ Storage references table created:
   SELECT * FROM storage_references;

✅ Functions available:
   - get_storage_signed_url()
   - cache_storage_reference()
   - cleanup_expired_storage_references()

✅ Materialized view created:
   SELECT * FROM storage_usage_by_bucket;

Next: Use Edge Function to upload files and sync URLs to Firestore
*/
