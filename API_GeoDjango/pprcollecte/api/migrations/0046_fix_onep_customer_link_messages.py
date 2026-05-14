from django.db import migrations


FORWARD_SQL = """
CREATE OR REPLACE FUNCTION ep.srm_fill_ep_brc_pt_customer_link()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    contract_key text;
    police_key text;
    spatial_commune_key text;
    onep_commune_key text;
    onep_count integer := 0;
    matched_by_contract boolean := false;
    client_found boolean := false;
    client record;
    note text;
BEGIN
    contract_key := NULLIF(btrim(coalesce(NEW.num_contrat, '')), '');
    police_key := NULLIF(btrim(coalesce(NEW.ancienne_police, '')), '');
    spatial_commune_key := public.srm_ep_spatial_commune_key(NEW.geom);

    IF contract_key IS NOT NULL THEN
        SELECT count(*)
        INTO onep_count
        FROM ep.onep_db o
        WHERE btrim(o."numero de contrat"::text) = contract_key;

        IF onep_count = 1 THEN
            SELECT
                o."numero de contrat"::text AS numero_contrat,
                o."ancienne reference sap"::text AS ancienne_reference_sap,
                o."ancienne police"::text AS ancienne_police,
                coalesce(o."nom commune_1", o."nom commune")::text AS nom_commune,
                o."nom/raison sociale du client payeur"::text AS nom_client,
                o."prenom du client payeur"::text AS prenom_client,
                o."identifiant geographique"::text AS identifiant_geographique,
                o."libelle etat abonnement"::text AS etat_abonnement,
                o."adresse postale client payeur"::text AS adresse
            INTO client
            FROM ep.onep_db o
            WHERE btrim(o."numero de contrat"::text) = contract_key
            LIMIT 1;
            client_found := true;
            matched_by_contract := true;
        ELSIF onep_count > 1 THEN
            NEW.ep_observation := public.srm_append_compteur_abonne_observation(
                NEW.ep_observation,
                'Liaison ONEP ambiguë : numéro de contrat ' || contract_key
            );
        END IF;
    END IF;

    IF NOT client_found
       AND police_key IS NOT NULL
       AND upper(police_key) NOT IN ('NEANT', 'NÉANT', 'NULL')
       AND spatial_commune_key IS NOT NULL THEN
        SELECT count(*)
        INTO onep_count
        FROM ep.onep_db o
        WHERE btrim(o."ancienne police"::text) = police_key
          AND public.srm_onep_commune_key(coalesce(o."nom commune_1", o."nom commune")) = spatial_commune_key;

        IF onep_count = 1 THEN
            SELECT
                o."numero de contrat"::text AS numero_contrat,
                o."ancienne reference sap"::text AS ancienne_reference_sap,
                o."ancienne police"::text AS ancienne_police,
                coalesce(o."nom commune_1", o."nom commune")::text AS nom_commune,
                o."nom/raison sociale du client payeur"::text AS nom_client,
                o."prenom du client payeur"::text AS prenom_client,
                o."identifiant geographique"::text AS identifiant_geographique,
                o."libelle etat abonnement"::text AS etat_abonnement,
                o."adresse postale client payeur"::text AS adresse
            INTO client
            FROM ep.onep_db o
            WHERE btrim(o."ancienne police"::text) = police_key
              AND public.srm_onep_commune_key(coalesce(o."nom commune_1", o."nom commune")) = spatial_commune_key
            LIMIT 1;
            client_found := true;
        ELSIF onep_count > 1 THEN
            NEW.ep_observation := public.srm_append_compteur_abonne_observation(
                NEW.ep_observation,
                'Liaison ONEP ambiguë : ancienne police ' || police_key
                    || ' / commune ' || spatial_commune_key
            );
        END IF;
    END IF;

    IF client_found THEN
        NEW.num_contrat := coalesce(NULLIF(btrim(client.numero_contrat), ''), NEW.num_contrat);
        NEW.ref := coalesce(NULLIF(btrim(client.ancienne_reference_sap), ''), NEW.ref);
        NEW.ancien_ref_sap := coalesce(NULLIF(btrim(client.ancienne_reference_sap), ''), NEW.ancien_ref_sap);
        NEW.id_geo := coalesce(NULLIF(btrim(client.identifiant_geographique), ''), NEW.id_geo);
        NEW.ancienne_police := coalesce(NULLIF(btrim(client.ancienne_police), ''), NEW.ancienne_police);
        NEW.nom := coalesce(NULLIF(btrim(client.nom_client), ''), NEW.nom);
        NEW.abon := coalesce(NULLIF(btrim(client.prenom_client), ''), NEW.abon);
        NEW.adresse := coalesce(NULLIF(btrim(client.adresse), ''), NEW.adresse);
        NEW.etat_abonnement := coalesce(NULLIF(btrim(client.etat_abonnement), ''), NEW.etat_abonnement);

        IF matched_by_contract AND spatial_commune_key IS NOT NULL THEN
            onep_commune_key := public.srm_onep_commune_key(client.nom_commune);
            IF onep_commune_key IS NOT NULL AND onep_commune_key <> spatial_commune_key THEN
                note := 'Incohérence découpage client : ONEP='
                    || coalesce(client.nom_commune, '?')
                    || ', spatial=' || spatial_commune_key
                    || '. Liaison conservée par numéro de contrat.';
                NEW.ep_observation := public.srm_append_compteur_abonne_observation(
                    NEW.ep_observation,
                    note
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0045_fix_public_profile_metrics_aggregates"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
