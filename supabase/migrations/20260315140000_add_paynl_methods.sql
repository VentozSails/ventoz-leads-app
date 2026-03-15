INSERT INTO payment_method_preferences (method_id, display_name, preferred_gateway, countries, enabled, sort_order)
VALUES
  ('wero', 'Wero', 'pay_nl', '{}', true, 10),
  ('vipps', 'Vipps', 'pay_nl', '{NO}', true, 11),
  ('swish', 'Swish', 'pay_nl', '{SE}', true, 12),
  ('mobilepay', 'MobilePay', 'pay_nl', '{DK,FI}', true, 13),
  ('bizum', 'Bizum', 'pay_nl', '{ES}', true, 14),
  ('mbway', 'MB Way', 'pay_nl', '{PT}', true, 15),
  ('satispay', 'Satispay', 'pay_nl', '{IT}', true, 16),
  ('blik', 'BLIK', 'pay_nl', '{PL}', true, 17),
  ('paybybank', 'Pay by Bank', 'pay_nl', '{}', true, 18)
ON CONFLICT (method_id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  preferred_gateway = EXCLUDED.preferred_gateway,
  countries = EXCLUDED.countries,
  sort_order = EXCLUDED.sort_order;
