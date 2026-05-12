from django.db import migrations


ADD_COLUMN_SQL = """
ALTER TABLE public.attribut_config_mobile
    ADD COLUMN IF NOT EXISTS obligatoire BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN public.attribut_config_mobile.obligatoire IS
    'Pilote le flag "champ obligatoire" sur le formulaire mobile. '
    'Independant de nullable (qui controle la contrainte SQL NOT NULL).';
"""


BACKFILL_SQL = """
-- Champs auto-geres par le workflow ou le systeme (jamais demandes a l'utilisateur).
UPDATE public.attribut_config_mobile
   SET obligatoire = FALSE
 WHERE nom_champ IN (
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

-- Coordonnees auto-remplies par le GPS.
UPDATE public.attribut_config_mobile
   SET obligatoire = FALSE
 WHERE nom_metier IN ('ep', 'asst')
   AND nom_champ IN (
    'ep_coor_x', 'ep_coor_y', 'ep_coor_z',
    'ass_coor_x', 'ass_coor_y', 'ass_coor_z'
   );

-- Champs libres optionnels (commentaire / observation / remarque).
UPDATE public.attribut_config_mobile
   SET obligatoire = FALSE
 WHERE LOWER(nom_champ) LIKE '%observ%'
    OR LOWER(nom_champ) LIKE '%commentaire%'
    OR LOWER(nom_champ) LIKE '%remarque%'
    OR LOWER(nom_champ) IN ('detail', 'note');
"""


REVERSE_SQL = """
ALTER TABLE public.attribut_config_mobile
    DROP COLUMN IF EXISTS obligatoire;
"""


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0046_fix_onep_customer_link_messages"),
    ]

    operations = [
        migrations.RunSQL(ADD_COLUMN_SQL, reverse_sql=REVERSE_SQL),
        migrations.RunSQL(BACKFILL_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
