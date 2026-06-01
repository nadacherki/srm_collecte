"""
Configure `retour_terrain` as an anomaly-only Oui/Non field everywhere.

The physical column is added by migration 0059. This migration only aligns the
mobile configuration:
- every mobile EP/ASST table that physically has `retour_terrain` gets an
  attribut_config_mobile row;
- the field is hidden from the generic form renderer because the mobile renders
  it inside the anomaly block only;
- public.liste_choix exposes exactly the active Oui/Non choices expected by the
  mobile dropdown.
"""

from django.db import migrations


FORWARD_SQL = r"""
WITH target_tables AS (
    SELECT DISTINCT
        c.table_schema AS nom_metier,
        c.table_name AS nom_table
    FROM information_schema.columns AS c
    WHERE c.table_schema IN ('ep', 'asst')
      AND c.column_name = 'retour_terrain'
      AND (
          EXISTS (
              SELECT 1
              FROM public.formulaire_config_mobile AS f
              WHERE f.nom_metier = c.table_schema
                AND f.nom_table = c.table_name
          )
          OR EXISTS (
              SELECT 1
              FROM public.attribut_config_mobile AS a
              WHERE a.nom_metier = c.table_schema
                AND a.nom_table = c.table_name
          )
      )
),
target_with_order AS (
    SELECT
        t.nom_metier,
        t.nom_table,
        COALESCE(
            (
                SELECT max(a.ordre) + 1
                FROM public.attribut_config_mobile AS a
                WHERE a.nom_metier = t.nom_metier
                  AND a.nom_table = t.nom_table
                  AND lower(a.nom_champ) IN (
                      'anomalie',
                      'ep_anomalie',
                      'ass_anomalie',
                      'type_anomalie'
                  )
            ),
            (
                SELECT max(a.ordre) + 1
                FROM public.attribut_config_mobile AS a
                WHERE a.nom_metier = t.nom_metier
                  AND a.nom_table = t.nom_table
            ),
            999
        ) AS ordre
    FROM target_tables AS t
)
INSERT INTO public.attribut_config_mobile (
    nom_metier,
    nom_table,
    nom_champ,
    type_champ,
    primary_key,
    foreign_key,
    ordre,
    titre_app,
    visible,
    contraintes_doc,
    contraintes_regles,
    nullable,
    valeur_par_defaut,
    valeur_min,
    valeur_max,
    reference_fk
)
SELECT
    nom_metier,
    nom_table,
    'retour_terrain',
    'text',
    false,
    false,
    ordre,
    'Retour terrain',
    false,
    'Champ du bloc anomalie. Visible uniquement lorsque anomalie = oui. Choix Oui/Non.',
    '[]'::jsonb,
    true,
    NULL,
    NULL,
    NULL,
    NULL
FROM target_with_order
ON CONFLICT (nom_metier, nom_table, nom_champ) DO UPDATE
SET type_champ = 'text',
    primary_key = false,
    foreign_key = false,
    ordre = EXCLUDED.ordre,
    titre_app = 'Retour terrain',
    visible = false,
    contraintes_doc = 'Champ du bloc anomalie. Visible uniquement lorsque anomalie = oui. Choix Oui/Non.',
    contraintes_regles = '[]'::jsonb,
    nullable = true,
    valeur_par_defaut = NULL,
    valeur_min = NULL,
    valeur_max = NULL,
    reference_fk = NULL;

WITH retour_attrs AS (
    SELECT a.id, a.nom_metier, a.nom_table, a.nom_champ
    FROM public.attribut_config_mobile AS a
    JOIN information_schema.columns AS c
      ON c.table_schema = a.nom_metier
     AND c.table_name = a.nom_table
     AND c.column_name = a.nom_champ
    WHERE a.nom_metier IN ('ep', 'asst')
      AND a.nom_champ = 'retour_terrain'
)
UPDATE public.liste_choix AS lc
   SET liste_choix_actif = false
  FROM retour_attrs AS a
 WHERE lc.nom_metier = a.nom_metier
   AND lc.nom_table = a.nom_table
   AND lc.nom_champ = a.nom_champ;

WITH retour_attrs AS (
    SELECT a.id, a.nom_metier, a.nom_table, a.nom_champ
    FROM public.attribut_config_mobile AS a
    JOIN information_schema.columns AS c
      ON c.table_schema = a.nom_metier
     AND c.table_name = a.nom_table
     AND c.column_name = a.nom_champ
    WHERE a.nom_metier IN ('ep', 'asst')
      AND a.nom_champ = 'retour_terrain'
),
choices(code, label, display_order) AS (
    VALUES ('oui', 'Oui', 1), ('non', 'Non', 2)
)
INSERT INTO public.liste_choix (
    attribut_config_mobile_id,
    nom_metier,
    nom_table,
    nom_champ,
    liste_choix_alias,
    liste_choix_valeur,
    liste_choix_ordre,
    liste_choix_actif
)
SELECT
    a.id,
    a.nom_metier,
    a.nom_table,
    a.nom_champ,
    c.label,
    c.code,
    c.display_order,
    true
FROM retour_attrs AS a
CROSS JOIN choices AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM public.liste_choix AS lc
    WHERE lc.nom_metier = a.nom_metier
      AND lc.nom_table = a.nom_table
      AND lc.nom_champ = a.nom_champ
      AND lower(btrim(COALESCE(lc.liste_choix_valeur, ''))) = c.code
);

WITH retour_attrs AS (
    SELECT a.id, a.nom_metier, a.nom_table, a.nom_champ
    FROM public.attribut_config_mobile AS a
    JOIN information_schema.columns AS c
      ON c.table_schema = a.nom_metier
     AND c.table_name = a.nom_table
     AND c.column_name = a.nom_champ
    WHERE a.nom_metier IN ('ep', 'asst')
      AND a.nom_champ = 'retour_terrain'
),
canonical AS (
    SELECT DISTINCT ON (
        lc.nom_metier,
        lc.nom_table,
        lc.nom_champ,
        lower(btrim(COALESCE(lc.liste_choix_valeur, '')))
    )
        lc.id,
        a.id AS attribut_config_mobile_id,
        lower(btrim(COALESCE(lc.liste_choix_valeur, ''))) AS code
    FROM public.liste_choix AS lc
    JOIN retour_attrs AS a
      ON lc.nom_metier = a.nom_metier
     AND lc.nom_table = a.nom_table
     AND lc.nom_champ = a.nom_champ
    WHERE lower(btrim(COALESCE(lc.liste_choix_valeur, ''))) IN ('oui', 'non')
    ORDER BY
        lc.nom_metier,
        lc.nom_table,
        lc.nom_champ,
        lower(btrim(COALESCE(lc.liste_choix_valeur, ''))),
        lc.id
)
UPDATE public.liste_choix AS lc
   SET attribut_config_mobile_id = c.attribut_config_mobile_id,
       liste_choix_alias = CASE c.code WHEN 'oui' THEN 'Oui' ELSE 'Non' END,
       liste_choix_valeur = c.code,
       liste_choix_ordre = CASE c.code WHEN 'oui' THEN 1 ELSE 2 END,
       liste_choix_actif = true
  FROM canonical AS c
 WHERE lc.id = c.id;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0061_complete_retour_terrain_config"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
