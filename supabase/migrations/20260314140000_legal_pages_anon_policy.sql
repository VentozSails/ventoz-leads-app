DROP POLICY IF EXISTS ventoz_app_settings_anon_select ON app_settings;
CREATE POLICY ventoz_app_settings_anon_select ON app_settings
    FOR SELECT TO anon
    USING (key IN (
        'review_platforms', 'about_text', 'webshop_hero', 'webshop_usp',
        'legal_terms', 'legal_privacy', 'legal_warranty',
        'legal_complaints', 'legal_returns'
    ));
