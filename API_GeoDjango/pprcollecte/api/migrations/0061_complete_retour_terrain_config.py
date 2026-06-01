"""
Complete l'alignement formulaire apres l'ajout de `retour_terrain`.

La migration 0059 ajoute la colonne physique sur les tables metier mobiles.
Cette migration ajoute la ligne de configuration mobile correspondante quand
elle manque, en champ invisible et facultatif. Le champ reste gere par le bloc
anomalie de l'application, pas par le rendu generique des formulaires.
"""

from django.db import migrations


FORWARD_SQL = r"""
-- codinsee reste facultatif: supprimer aussi les contraintes nommees que
-- l'audit considere comme une obligation logique.
ALTER TABLE ep.ep_hydrant
    ALTER COLUMN codinsee DROP NOT NULL;

ALTER TABLE ep.ep_hydrant
    DROP CONSTRAINT IF EXISTS srm_nn_e1700486a3ba0451;

ALTER TABLE ep.ep_hydrant
    DROP CONSTRAINT IF EXISTS srm_req_e1700486a3ba0451;

UPDATE public.attribut_config_mobile
   SET nullable = true
 WHERE nom_metier = 'ep'
   AND nom_table = 'ep_hydrant'
   AND nom_champ = 'codinsee';

-- Toute colonne physique mobile doit avoir sa ligne attribut_config_mobile.
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
    f.nom_metier,
    f.nom_table,
    'retour_terrain',
    'text',
    false,
    false,
    COALESCE(
        (
            SELECT max(a.ordre) + 1
            FROM public.attribut_config_mobile AS a
            WHERE a.nom_metier = f.nom_metier
              AND a.nom_table = f.nom_table
        ),
        999
    ),
    'Retour terrain',
    false,
    NULL,
    '[]'::jsonb,
    true,
    NULL,
    NULL,
    NULL,
    NULL
FROM public.formulaire_config_mobile AS f
JOIN information_schema.columns AS c
  ON c.table_schema = f.nom_metier
 AND c.table_name = f.nom_table
 AND c.column_name = 'retour_terrain'
WHERE f.nom_metier IN ('ep', 'asst')
  AND NOT EXISTS (
      SELECT 1
      FROM public.attribut_config_mobile AS a
      WHERE a.nom_metier = f.nom_metier
        AND a.nom_table = f.nom_table
        AND a.nom_champ = 'retour_terrain'
  );
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0060_align_form_nullable_contract"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
