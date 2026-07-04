-- 1. Recreate the old products table structure so frontend queries don't break
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  subcategory TEXT,
  price DECIMAL(10, 2) NOT NULL,
  compare_price DECIMAL(10, 2),
  cost_price DECIMAL(10, 2),
  main_image_url TEXT,
  gallery_images TEXT[] DEFAULT ARRAY[]::TEXT[],
  total_quantity INT DEFAULT 0,
  reserved_quantity INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  meta_title TEXT,
  meta_description TEXT,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  embeddings VECTOR(1536),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  deleted_at TIMESTAMP
);

-- 2. Create a dummy shop if one doesn't exist
DO $$
DECLARE
    v_shop_id UUID;
    v_owner_id UUID;
BEGIN
    SELECT id INTO v_shop_id FROM public.shops LIMIT 1;
    
    IF v_shop_id IS NULL THEN
        -- Need a customer for owner_id
        SELECT id INTO v_owner_id FROM public.customers LIMIT 1;
        IF v_owner_id IS NULL THEN
            INSERT INTO public.customers (id, email, phone, full_name, account_type) 
            VALUES (gen_random_uuid(), 'admin@fufaji.com', '+919999999999', 'Admin', 'shop_owner') 
            RETURNING id INTO v_owner_id;
        END IF;

        INSERT INTO public.shops (owner_id, name, address_line, latitude, longitude)
        VALUES (v_owner_id, 'Fufaji MVP Store', 'Delhi', 28.6, 77.2)
        RETURNING id INTO v_shop_id;
    END IF;

    -- 3. Copy all data from catalog_products to products
    INSERT INTO public.products (shop_id, name, description, category, price, compare_price, total_quantity, is_active, main_image_url)
    SELECT 
        v_shop_id,
        cp.name,
        COALESCE(cp.hindi_name, cp.product_code),
        'other', -- default category if categories are not fully mapped yet
        COALESCE((SELECT default_selling_price FROM public.catalog_variants cv WHERE cv.product_id = cp.id LIMIT 1), 0),
        (SELECT mrp FROM public.catalog_variants cv WHERE cv.product_id = cp.id LIMIT 1),
        (SELECT quantity FROM public.catalog_variants cv WHERE cv.product_id = cp.id LIMIT 1),
        cp.is_active,
        'https://via.placeholder.com/300?text=' || cp.product_code
    FROM public.catalog_products cp;
END $$;
