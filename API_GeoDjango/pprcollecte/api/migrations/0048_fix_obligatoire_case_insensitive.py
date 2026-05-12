from django.db import migrations


# La migration 0047 utilisait des comparaisons sensibles a la casse
# (`nom_champ IN ('ass_date_pose', ...)`), mais une partie de la
# config legacy (schemas ASS_*) stocke nom_champ et nom_table en
# MAJUSCULES. Resultat : ces lignes sont restees `obligatoire = TRUE`
# meme apres le backfill. On rejoue le backfill avec `LOWER(nom_champ)`.
FIX_SQL = """
UPDATE public.attribut_config_mobile
   SET obligatoire = FALSE
 WHERE LOWER(nom_champ) IN (
    'mode_localisation',
    'anomalie',
    'ep_anomalie',
    'ass_anomalie',
    'type_anomalie',
    'anomalie_regard',
    'anomalie_tamp',
    'objet_incomplet',
    'raison_incomplet',
    'detail_raison_incomplet',
    'photo_1',
    'photo_2',
    'photo_3',
    'photo_4',
    'created_at',
    'updated_at',
    'date_creation',
    'date_modif',
    'id_user_creat',
    'id_user_modif',
    'is_deleted',
    'is_validated',
    'date_pose',
    'ep_date_pose',
    'ass_date_pose'
   );

UPDATE public.attribut_config_mobile
   SET obligatoire = FALSE
 WHERE LOWER(nom_metier) IN ('ep', 'asst')
   AND LOWER(nom_champ) IN (
    'ep_coor_x', 'ep_coor_y', 'ep_coor_z',
    'ass_coor_x', 'ass_coor_y', 'ass_coor_z'
   );
"""


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0047_attribut_config_mobile_obligatoire"),
    ]

    operations = [
        migrations.RunSQL(FIX_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
