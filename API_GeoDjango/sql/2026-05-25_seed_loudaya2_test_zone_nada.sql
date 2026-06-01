-- Zone test LOUDAYA2 pour validation ortho EPSG:26191 sur mobile.
-- La zone prend seulement une partie de LOUDAYA2.tif afin de tester
-- l'affectation, le telechargement et le pointage sur ortho.

BEGIN;

WITH nada AS (
    SELECT id_user
    FROM public.utilisateur
    WHERE login = 'nada'
    LIMIT 1
),
upsert_zone AS (
    INSERT INTO public.zone (
        nom_zone,
        etat,
        date_debut,
        id_user_creat,
        geom
    )
    SELECT
        'TEST_LOUDAYA2_ORTHO_NADA',
        'active',
        NOW(),
        nada.id_user,
        ST_GeomFromText(
            'POLYGON((
                228460.000 118540.000,
                228700.000 118540.000,
                228700.000 118800.000,
                228460.000 118800.000,
                228460.000 118540.000
            ))',
            26191
        )
    FROM nada
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.zone
        WHERE nom_zone = 'TEST_LOUDAYA2_ORTHO_NADA'
    )
    RETURNING id_zone
),
target_zone AS (
    SELECT id_zone
    FROM upsert_zone
    UNION ALL
    SELECT id_zone
    FROM public.zone
    WHERE nom_zone = 'TEST_LOUDAYA2_ORTHO_NADA'
    LIMIT 1
)
INSERT INTO public.zone_utilisateur (
    id_zone,
    id_user,
    date_affectation,
    actif
)
SELECT
    target_zone.id_zone,
    nada.id_user,
    NOW(),
    TRUE
FROM target_zone
CROSS JOIN nada
ON CONFLICT (id_zone, id_user)
DO UPDATE SET
    date_affectation = EXCLUDED.date_affectation,
    actif = TRUE;

COMMIT;
