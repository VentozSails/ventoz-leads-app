-- Extract spec data embedded in descriptions and move to proper spec columns.
-- Then strip those spec lines from all description columns (NL + 26 languages).

-- Helper function to extract a spec value from a text block
CREATE OR REPLACE FUNCTION _extract_spec(
  txt TEXT,
  patterns TEXT[]
) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  p TEXT;
  m TEXT[];
BEGIN
  FOREACH p IN ARRAY patterns LOOP
    m := regexp_match(txt, p, 'im');
    IF m IS NOT NULL AND m[1] IS NOT NULL THEN
      RETURN trim(m[1]);
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$;

-- Step 1: Extract specs from beschrijving into spec columns (only if spec column is empty)
UPDATE product_catalogus SET
  luff = COALESCE(luff, _extract_spec(
    COALESCE(beschrijving_override, beschrijving, ''),
    ARRAY[
      '(?:voorlijk|luff|vorliek)\s*[:：]\s*(.+)',
      '(?:voorlijk|luff|vorliek)\s*\(?[^)]*\)?\s*[:：]\s*(.+)'
    ]
  )),
  foot = COALESCE(foot, _extract_spec(
    COALESCE(beschrijving_override, beschrijving, ''),
    ARRAY[
      '(?:onderlijk|foot|boom|unterliek)\s*[:：]\s*(.+)',
      '(?:onderlijk|foot|boom|unterliek)\s*\(?[^)]*\)?\s*[:：]\s*(.+)'
    ]
  )),
  sail_area = COALESCE(sail_area, _extract_spec(
    COALESCE(beschrijving_override, beschrijving, ''),
    ARRAY[
      '(?:oppervlakte|sail\s*area|fläche|surface|superficie)\s*[:：]\s*(.+)',
      '(?:oppervlakte|sail\s*area|fläche|surface)\s*\(?[^)]*\)?\s*[:：]\s*(.+)'
    ]
  )),
  materiaal = COALESCE(materiaal, _extract_spec(
    COALESCE(beschrijving_override, beschrijving, ''),
    ARRAY[
      '(?:materiaal|material|matériau)\s*[:：]\s*(.+)'
    ]
  )),
  inclusief = COALESCE(inclusief, _extract_spec(
    COALESCE(beschrijving_override, beschrijving, ''),
    ARRAY[
      '(?:inclusief|includes?|inclus|inklusive|einschließlich)\s*[:：]\s*(.+)'
    ]
  ))
WHERE beschrijving IS NOT NULL OR beschrijving_override IS NOT NULL;

-- Step 2: Strip spec lines from all description columns.
-- This regex removes lines starting with spec labels followed by a colon.
CREATE OR REPLACE FUNCTION _strip_spec_lines(txt TEXT) RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  result TEXT;
BEGIN
  IF txt IS NULL OR txt = '' THEN RETURN txt; END IF;

  result := regexp_replace(
    txt,
    '^\s*(?:voorlijk|luff|vorliek|achterlijk|leech|achterliek|onderlijk|foot|boom|unterliek|oppervlakte|sail\s*area|fläche|surface|superficie|materiaal|material|matériau|gewicht|weight|poids|inclusief|includes?|inclus|inklusive|einschließlich|mast\s*(?:delen|sections?|teile)|mastdelen|zeillatten|battens?|lattes?|segellatten|mast(?:hoogte|lengte)|mast\s*(?:height|length))\s*(?:\([^)]*\)\s*)?[:：]\s*[^\n]*',
    '',
    'gim'
  );

  -- Clean up resulting multiple blank lines
  result := regexp_replace(result, E'\n{3,}', E'\n\n', 'g');
  result := trim(both E'\n ' from result);

  RETURN result;
END;
$$;

-- Apply to all description columns
UPDATE product_catalogus SET
  beschrijving = _strip_spec_lines(beschrijving),
  beschrijving_override = _strip_spec_lines(beschrijving_override),
  beschrijving_en = _strip_spec_lines(beschrijving_en),
  beschrijving_de = _strip_spec_lines(beschrijving_de),
  beschrijving_fr = _strip_spec_lines(beschrijving_fr),
  beschrijving_es = _strip_spec_lines(beschrijving_es),
  beschrijving_it = _strip_spec_lines(beschrijving_it),
  beschrijving_ar = _strip_spec_lines(beschrijving_ar),
  beschrijving_bg = _strip_spec_lines(beschrijving_bg),
  beschrijving_cs = _strip_spec_lines(beschrijving_cs),
  beschrijving_da = _strip_spec_lines(beschrijving_da),
  beschrijving_el = _strip_spec_lines(beschrijving_el),
  beschrijving_et = _strip_spec_lines(beschrijving_et),
  beschrijving_fi = _strip_spec_lines(beschrijving_fi),
  beschrijving_ga = _strip_spec_lines(beschrijving_ga),
  beschrijving_hr = _strip_spec_lines(beschrijving_hr),
  beschrijving_hu = _strip_spec_lines(beschrijving_hu),
  beschrijving_lt = _strip_spec_lines(beschrijving_lt),
  beschrijving_lv = _strip_spec_lines(beschrijving_lv),
  beschrijving_mt = _strip_spec_lines(beschrijving_mt),
  beschrijving_pl = _strip_spec_lines(beschrijving_pl),
  beschrijving_pt = _strip_spec_lines(beschrijving_pt),
  beschrijving_ro = _strip_spec_lines(beschrijving_ro),
  beschrijving_sk = _strip_spec_lines(beschrijving_sk),
  beschrijving_sl = _strip_spec_lines(beschrijving_sl),
  beschrijving_sv = _strip_spec_lines(beschrijving_sv),
  beschrijving_tr = _strip_spec_lines(beschrijving_tr),
  beschrijving_zh = _strip_spec_lines(beschrijving_zh)
WHERE beschrijving IS NOT NULL
   OR beschrijving_override IS NOT NULL
   OR beschrijving_en IS NOT NULL;

-- Clean up helper functions
DROP FUNCTION IF EXISTS _extract_spec(TEXT, TEXT[]);
DROP FUNCTION IF EXISTS _strip_spec_lines(TEXT);
