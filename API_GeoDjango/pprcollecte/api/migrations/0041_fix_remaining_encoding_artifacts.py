from django.db import migrations


FORWARD_SQL = r"""
CREATE OR REPLACE FUNCTION public.srm_normalize_commune_name(raw_value text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    normalized text;
BEGIN
    normalized := upper(coalesce(raw_value, ''));
    normalized := translate(
        normalized,
        U&'\00C0\00C1\00C2\00C3\00C4\00C5\0100\0102\0104\00C7\0106\010C\00C8\00C9\00CA\00CB\0112\0116\0118\00CC\00CD\00CE\00CF\012A\012E\00D1\00D2\00D3\00D4\00D5\00D6\014C\00D9\00DA\00DB\00DC\016A\00DD\0178\017D\00E0\00E1\00E2\00E3\00E4\00E5\0101\0103\0105\00E7\0107\010D\00E8\00E9\00EA\00EB\0113\0117\0119\00EC\00ED\00EE\00EF\012B\012F\00F1\00F2\00F3\00F4\00F5\00F6\014D\00F9\00FA\00FB\00FC\016B\00FD\00FF\017E\2019`',
        'AAAAAAAAACCCEEEEEEEIIIIIINOOOOOOUUUUUYYZaaaaaaaaaccceeeeeeeiiiiiinoooooouuuuuyyz  '
    );
    normalized := regexp_replace(normalized, '^COMMUNE\s+', '', 'i');
    normalized := regexp_replace(normalized, '^(D''|DE\s+|DU\s+|DES\s+)', '', 'i');
    normalized := regexp_replace(normalized, '[^A-Z0-9]+', ' ', 'g');
    normalized := btrim(regexp_replace(normalized, '\s+', ' ', 'g'));
    RETURN NULLIF(normalized, '');
END;
$$;

UPDATE ep.ep_regard
SET ep_observation = U&'Puisard construit c\00F4t\00E9 haut'
WHERE fid = 463
  AND uuid::text = '4f983599-2ac4-4f27-8b02-81abd597995f'
  AND ep_observation IS DISTINCT FROM U&'Puisard construit c\00F4t\00E9 haut';

UPDATE ep.ep_regard_point
SET ep_observation = U&'Puisard construit c\00F4t\00E9 haut'
WHERE fid = 463
  AND uuid::text = '4f983599-2ac4-4f27-8b02-81abd597995f'
  AND ep_observation IS DISTINCT FROM U&'Puisard construit c\00F4t\00E9 haut';
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0040_remove_unused_srm_entity_model_state'),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, migrations.RunSQL.noop),
    ]
