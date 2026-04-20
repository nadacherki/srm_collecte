from django.db import migrations


ADD_COLUMN_SQL = [
    'ALTER TABLE "ep"."vanne_de_vidange" ADD COLUMN IF NOT EXISTS "etage_aqua" varchar(254)',
    'ALTER TABLE "ep"."vanne_de_vidange" ADD COLUMN IF NOT EXISTS "secteur_aqua" varchar(254)',
    'ALTER TABLE "ep"."vanne_de_vidange" ADD COLUMN IF NOT EXISTS "id_conduite" integer',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "ep_num" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "emplacement" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "ep_statut" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "observation" varchar(254)',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "photo_1" text',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "photo_2" text',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "photo_3" text',
    'ALTER TABLE "ep"."centre_tampon" ADD COLUMN IF NOT EXISTS "photo_4" text',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ep_num" varchar(254)',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "emplacement" varchar(254)',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ep_statut" varchar(254)',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "observation" varchar(254)',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ep_coor_x" double precision',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ep_coor_y" double precision',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "ep_coor_z" double precision',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "photo_1" text',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "photo_2" text',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "photo_3" text',
    'ALTER TABLE "ep"."noeud" ADD COLUMN IF NOT EXISTS "photo_4" text',
    'ALTER TABLE "ep"."obturateur" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."obturateur" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."obturateur" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."obturateur" ADD COLUMN IF NOT EXISTS "id_conduite" integer',
    'ALTER TABLE "ep"."reducteur_de_pression" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."reducteur_de_pression" ADD COLUMN IF NOT EXISTS "ep_statut" varchar(254)',
    'ALTER TABLE "ep"."forage" ADD COLUMN IF NOT EXISTS "ep_profondeur" double precision',
    'ALTER TABLE "ep"."forage" ADD COLUMN IF NOT EXISTS "ep_debit" double precision',
    'ALTER TABLE "ep"."forage" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."forage" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."puit" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."puit" ADD COLUMN IF NOT EXISTS "ep_profondeur" double precision',
    'ALTER TABLE "ep"."puit" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."puit" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."pompe" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."pompe" ADD COLUMN IF NOT EXISTS "ep_puissance" double precision',
    'ALTER TABLE "ep"."pompe" ADD COLUMN IF NOT EXISTS "ep_debit" double precision',
    'ALTER TABLE "ep"."pompe" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."pompe" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."reservoir" ADD COLUMN IF NOT EXISTS "ep_cote_radier" double precision',
    'ALTER TABLE "ep"."reservoir" ADD COLUMN IF NOT EXISTS "ep_cote_trop_plein" double precision',
    'ALTER TABLE "ep"."reservoir" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."station_de_pompage" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."station_de_pompage" ADD COLUMN IF NOT EXISTS "ep_nb_pompes" integer',
    'ALTER TABLE "ep"."station_de_pompage" ADD COLUMN IF NOT EXISTS "ep_capacite" double precision',
    'ALTER TABLE "ep"."station_de_pompage" ADD COLUMN IF NOT EXISTS "ep_etat" varchar(254)',
    'ALTER TABLE "ep"."station_de_pompage" ADD COLUMN IF NOT EXISTS "ref_rue" varchar(254)',
    'ALTER TABLE "ep"."branchement" ADD COLUMN IF NOT EXISTS "observation" varchar(254)',
    'ALTER TABLE "ep"."traverse" ADD COLUMN IF NOT EXISTS "ep_type" varchar(254)',
    'ALTER TABLE "ep"."traverse" ADD COLUMN IF NOT EXISTS "ep_longueur" double precision',
    'ALTER TABLE "ep"."traverse" ADD COLUMN IF NOT EXISTS "emplacement" varchar(254)',
    'ALTER TABLE "ep"."traverse" ADD COLUMN IF NOT EXISTS "observation" varchar(254)',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "nom" varchar(254)',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "code" varchar(254)',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "observation" varchar(254)',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "id_agent_crea" integer',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "id_planche" integer',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "anomalie" boolean DEFAULT false',
    'ALTER TABLE "ep"."planche" ADD COLUMN IF NOT EXISTS "type_anomalie" text',
]


BACKFILL_SQL = [
    'UPDATE "ep"."forage" SET "ep_profondeur" = "ep_profond" WHERE "ep_profondeur" IS NULL AND "ep_profond" IS NOT NULL',
    'UPDATE "ep"."forage" SET "ep_debit" = "ep_debit_fo"::double precision WHERE "ep_debit" IS NULL AND "ep_debit_fo" IS NOT NULL',
    'UPDATE "ep"."forage" SET "ep_etat" = "ep_etat_s" WHERE "ep_etat" IS NULL AND "ep_etat_s" IS NOT NULL',
    "UPDATE \"ep\".\"pompe\" SET \"ep_puissance\" = NULLIF(regexp_replace(COALESCE(\"ep_pompe_puissance\", ''), '[^0-9\\.-]', '', 'g'), '')::double precision WHERE \"ep_puissance\" IS NULL AND COALESCE(\"ep_pompe_puissance\", '') <> ''",
    "UPDATE \"ep\".\"pompe\" SET \"ep_debit\" = NULLIF(regexp_replace(COALESCE(\"ep_pompe_debit_fo\", ''), '[^0-9\\.-]', '', 'g'), '')::double precision WHERE \"ep_debit\" IS NULL AND COALESCE(\"ep_pompe_debit_fo\", '') <> ''",
    'UPDATE "ep"."pompe" SET "ep_etat" = "ep_etat_s" WHERE "ep_etat" IS NULL AND "ep_etat_s" IS NOT NULL',
    'UPDATE "ep"."reservoir" SET "ep_cote_radier" = "ep_cote_rad" WHERE "ep_cote_radier" IS NULL AND "ep_cote_rad" IS NOT NULL',
    'UPDATE "ep"."reservoir" SET "ep_cote_trop_plein" = "ep_cote_tp" WHERE "ep_cote_trop_plein" IS NULL AND "ep_cote_tp" IS NOT NULL',
    'UPDATE "ep"."reservoir" SET "ep_etat" = "ep_etat_s" WHERE "ep_etat" IS NULL AND "ep_etat_s" IS NOT NULL',
    "UPDATE \"ep\".\"station_de_pompage\" SET \"ep_nb_pompes\" = NULLIF(regexp_replace(COALESCE(\"ep_nombre_de_groupe\", ''), '[^0-9-]', '', 'g'), '')::integer WHERE \"ep_nb_pompes\" IS NULL AND COALESCE(\"ep_nombre_de_groupe\", '') <> ''",
    "UPDATE \"ep\".\"station_de_pompage\" SET \"ep_capacite\" = NULLIF(regexp_replace(COALESCE(\"ep_debit_global\", ''), '[^0-9\\.-]', '', 'g'), '')::double precision WHERE \"ep_capacite\" IS NULL AND COALESCE(\"ep_debit_global\", '') <> ''",
    'UPDATE "ep"."station_de_pompage" SET "ep_etat" = "ep_etat_s" WHERE "ep_etat" IS NULL AND "ep_etat_s" IS NOT NULL',
    'UPDATE "ep"."traverse" SET "ep_type" = "type_traver" WHERE "ep_type" IS NULL AND "type_traver" IS NOT NULL',
    'UPDATE "ep"."traverse" SET "ep_longueur" = COALESCE("ep_long_r", "ep_long_c") WHERE "ep_longueur" IS NULL',
    'UPDATE "ep"."planche" SET "code" = "numero"::text WHERE "code" IS NULL AND "numero" IS NOT NULL',
    'UPDATE "ep"."planche" SET "nom" = CONCAT(\'Planche \', "numero"::text) WHERE "nom" IS NULL AND "numero" IS NOT NULL',
    'UPDATE "ep"."planche" SET "id_planche" = "numero"::integer WHERE "id_planche" IS NULL AND "numero" IS NOT NULL AND "numero" BETWEEN -2147483648 AND 2147483647',
    'UPDATE "ep"."planche" SET "anomalie" = false WHERE "anomalie" IS NULL',
]


def sync_ep_columns(apps, schema_editor):
    with schema_editor.connection.cursor() as cursor:
        for sql in ADD_COLUMN_SQL:
            cursor.execute(sql)
        for sql in BACKFILL_SQL:
            cursor.execute(sql)


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0004_piste_communes_rurales_id_piste_cout_investissement_and_more"),
    ]

    operations = [
        migrations.RunPython(sync_ep_columns, reverse_code=migrations.RunPython.noop),
    ]
