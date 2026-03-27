-- Add product_image_url to orders table
-- Used to display the product thumbnail in the albarán (packing slip)
-- for both Shopify orders (Shopify CDN URL) and manual orders (Supabase Storage URL)

ALTER TABLE orders ADD COLUMN IF NOT EXISTS product_image_url TEXT;
