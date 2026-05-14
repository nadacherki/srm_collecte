from django.db import migrations, models


CONFIG_SQL = """
ALTER TABLE ep.autre_objet
    ADD COLUMN IF NOT EXISTS ep_coor_x double precision;
ALTER TABLE ep.autre_objet
    ADD COLUMN IF NOT EXISTS ep_coor_y double precision;

UPDATE public.attribut_config_mobile
SET visible = false
WHERE nom_metier = 'ep'
  AND nom_table IN ('borne_onep', 'bouche_a_cles', 'autre_objet');

WITH rows(nom_table, nom_champ, type_champ, ordre, titre_app) AS (
  VALUES
    ('borne_onep', 'ep_coor_x', 'double precision', 1, 'X'),
    ('borne_onep', 'ep_coor_y', 'double precision', 2, 'Y'),
    ('borne_onep', 'ep_coor_z', 'double precision', 3, 'Z'),
    ('bouche_a_cles', 'ep_coor_x', 'double precision', 1, 'X'),
    ('bouche_a_cles', 'ep_coor_y', 'double precision', 2, 'Y'),
    ('bouche_a_cles', 'ep_coor_z', 'double precision', 3, 'Z'),
    ('autre_objet', 'ep_coor_x', 'double precision', 1, 'X'),
    ('autre_objet', 'ep_coor_y', 'double precision', 2, 'Y'),
    ('autre_objet', 'ep_coor_z', 'numeric', 3, 'Z'),
    ('autre_objet', 'observation', 'character varying', 4, 'Commentaire')
)
INSERT INTO public.attribut_config_mobile (
  nom_metier, nom_table, nom_champ, type_champ, primary_key, foreign_key,
  ordre, titre_app, visible, contraintes, nullable, valeur_par_defaut,
  valeur_min, valeur_max, reference_fk
)
SELECT
  'ep', nom_table, nom_champ, type_champ, false, false,
  ordre, titre_app, true, NULL, true, NULL, NULL, NULL, NULL
FROM rows
ON CONFLICT (nom_metier, nom_table, nom_champ) DO UPDATE
SET type_champ = EXCLUDED.type_champ,
    ordre = EXCLUDED.ordre,
    titre_app = EXCLUDED.titre_app,
    visible = true,
    nullable = true;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0013_asst_vf_table_names_state"),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
            ],
            state_operations=[
                migrations.AddField(
                    model_name="epautreobjet",
                    name="ep_coor_x",
                    field=models.FloatField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name="epautreobjet",
                    name="ep_coor_y",
                    field=models.FloatField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name="epbouchecles",
                    name="ep_coor_x",
                    field=models.FloatField(blank=True, null=True),
                ),
                migrations.AddField(
                    model_name="epbouchecles",
                    name="ep_coor_y",
                    field=models.FloatField(blank=True, null=True),
                ),
            ],
        ),
    ]
