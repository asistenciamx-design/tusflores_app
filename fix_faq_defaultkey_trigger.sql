-- VULN-20: Validate FAQ defaultKey values server-side
-- Run in Supabase SQL Editor

-- 1. Trigger function: rejects any defaultKey that is not in the allowed list
CREATE OR REPLACE FUNCTION validate_faq_default_keys()
RETURNS TRIGGER AS $$
DECLARE
  allowed_keys TEXT[] := ARRAY[
    'flowers_offered',
    'custom_arrangements',
    'advance_order',
    'photo_before_delivery',
    'delivery_cost',
    'same_day_delivery',
    'delivery_schedule',
    'order_tracking',
    'no_one_home',
    'delivery_notification',
    'damaged_guarantee',
    'payment_methods',
    'cash_on_delivery',
    'invoice',
    'cancellation',
    'claim_period'
  ];
  faq_item  JSONB;
  dk        TEXT;
  idx       INT;
  total     INT;
BEGIN
  -- Only validate when the settings column is present
  IF NEW.settings IS NULL OR NEW.settings -> 'faqs' IS NULL THEN
    RETURN NEW;
  END IF;

  total := jsonb_array_length(NEW.settings -> 'faqs');

  FOR idx IN 0 .. total - 1 LOOP
    faq_item := NEW.settings -> 'faqs' -> idx;
    dk := faq_item ->> 'default_key';

    IF dk IS NOT NULL AND NOT (dk = ANY(allowed_keys)) THEN
      RAISE EXCEPTION 'Invalid FAQ default_key: "%". Allowed values: %',
        dk, array_to_string(allowed_keys, ', ');
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Attach trigger to shop_settings table
DROP TRIGGER IF EXISTS trg_validate_faq_default_keys ON shop_settings;

CREATE TRIGGER trg_validate_faq_default_keys
  BEFORE INSERT OR UPDATE ON shop_settings
  FOR EACH ROW
  EXECUTE FUNCTION validate_faq_default_keys();
