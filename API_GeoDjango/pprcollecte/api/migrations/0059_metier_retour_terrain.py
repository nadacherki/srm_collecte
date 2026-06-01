"""
Ajoute la colonne `retour_terrain` (TEXT NULL) a toutes les tables metier
mobiles (EP / ASS).

Pourquoi : alignement avec le doc bureau (INTERVENTION_TRIGGER_NOTES_MOBILE.md
sec. 2) qui stipule qu'une intervention n'est creee QUE si l'objet metier
porte `anomalie=oui` ET `retour_terrain=oui`. Avant cette migration, seule
`ep.ep_regard_point` avait la colonne ; le mobile et le backend creaient
l'intervention des qu'anomalie=oui sur les autres tables, sans gate.

Effet : la colonne est ajoutee partout en NULLABLE. Le code backend
(`_upsert_intervention_anomalie_for_mobile_row`) et le code mobile
(`upsertLocalInterventionAnomalieSignalement`) verifient la valeur et ne
declenchent le workflow que si `retour_terrain='oui'` (ou alias truthy).

Exclusion : `ep.ep_brc_pt` (compteur abonne) reste hors workflow par regle
metier dediee. La colonne n'est pas ajoutee la pour eviter toute confusion
operationnelle (cf. MOBILE_INTERVENTION_ANOMALIE_EXCLUDED_TABLES).

Idempotent : `ADD COLUMN IF NOT EXISTS` ne touche pas les tables qui ont
deja la colonne (cas `ep.ep_regard_point`).

Tables visees : 46 (EP : 29 ponctuelles + lineaires + reference ; ASS : 17).
"""

from django.db import migrations


METIER_TABLES = [
    # EP
    ('ep', 'ep_vanne'),
    ('ep', 'ep_vidange'),
    ('ep', 'ep_ventouse'),
    ('ep', 'ep_hydrant'),
    ('ep', 'ep_bf'),
    ('ep', 'borne_onep'),
    ('ep', 'bouche_a_cles'),
    ('ep', 'ep_bouche_arro'),
    ('ep', 'ep_compteur_i'),
    ('ep', 'ep_cone_reduc'),
    ('ep', 'centre_tampon'),
    ('ep', 'ep_noeud'),
    ('ep', 'ep_obturateur'),
    ('ep', 'ep_reduc_pres'),
    ('ep', 'ep_forage'),
    ('ep', 'ep_puit'),
    ('ep', 'ep_pompe'),
    ('ep', 'ep_reservoir'),
    ('ep', 'ep_bache'),
    ('ep', 'ep_station_pompage'),
    ('ep', 'ep_regard_point'),
    ('ep', 'ep_regard'),
    ('ep', 'autre_objet'),
    ('ep', 'anomalie_conduite'),
    ('ep', 'conduite_terrain'),
    ('ep', 'ep_conduite'),
    ('ep', 'ep_branchement'),
    ('ep', 'ep_traversee'),
    ('ep', 'tn'),
    ('ep', 'voie'),
    # ASS (schema asst, table names case-sensitive)
    ('asst', 'ASS_REGARD'),
    ('asst', 'ASS_REGARD_FACADE'),
    ('asst', 'ASS_BORGNE'),
    ('asst', 'ASS_BOUCHE'),
    ('asst', 'ASS_DEVERSOIR'),
    ('asst', 'ASS__EXUTOIRE'),
    ('asst', 'ASS_STA_POMP'),
    ('asst', 'ASS_COLLECTEUR'),
    ('asst', 'ASS_REFOULEMENTR'),
    ('asst', 'ASS_BRANCHEMENT'),
    ('asst', 'ASS_CANIVEAU'),
    ('asst', 'ASS_CANIV_BRANCHE'),
    ('asst', 'ASS_COL_BOUCHE'),
    ('asst', 'ASS_BASSIN_VERSANT'),
    ('asst', 'ASS_STA_EPUR'),
    ('asst', 'ASS_OUV_TRAVERSEE'),
    ('asst', 'ASS_POMPE'),
]


def _add_column_sql(schema_name, table_name):
    # %I via format() preserve la casse et echappe les guillemets pour
    # les tables ASS en MAJUSCULES.
    return (
        f'ALTER TABLE "{schema_name}"."{table_name}" '
        f'ADD COLUMN IF NOT EXISTS retour_terrain TEXT NULL;'
    )


FORWARD_SQL = '\n'.join(
    _add_column_sql(schema_name, table_name)
    for schema_name, table_name in METIER_TABLES
)


# Rollback : on ne drop pas la colonne automatiquement pour eviter toute
# perte de donnees sur retour. Si vraiment necessaire, faire un DROP manuel.
REVERSE_SQL = migrations.RunSQL.noop


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0058_regard_miroir_fixed_square_sync"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=REVERSE_SQL),
    ]
