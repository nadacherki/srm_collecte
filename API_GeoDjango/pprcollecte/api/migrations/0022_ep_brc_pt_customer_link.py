from django.db import migrations


FORWARD_SQL = """
ALTER TABLE ep.ep_brc_pt
    ALTER COLUMN ancien_ref_sap TYPE character varying(400)
        USING ancien_ref_sap::character varying(400),
    ALTER COLUMN id_geo TYPE character varying(400)
        USING id_geo::character varying(400),
    ALTER COLUMN ancienne_police TYPE character varying(400)
        USING ancienne_police::character varying(400);

CREATE TABLE IF NOT EXISTS public.onep_commune_alias (
    id bigserial PRIMARY KEY,
    onep_nom_commune character varying(400) NOT NULL UNIQUE,
    decoupage_nom_commune character varying(400) NOT NULL,
    actif boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

INSERT INTO public.onep_commune_alias (
    onep_nom_commune,
    decoupage_nom_commune,
    actif
)
VALUES ('LABSARA', 'BSARA', true)
ON CONFLICT (onep_nom_commune) DO UPDATE
SET decoupage_nom_commune = EXCLUDED.decoupage_nom_commune,
    actif = EXCLUDED.actif,
    updated_at = now();

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
        'ÀÁÂÃÄÅĀĂĄÇĆČÈÉÊËĒĖĘÌÍÎÏĪĮÑÒÓÔÕÖŌÙÚÛÜŪÝŸŽàáâãäåāăąçćčèéêëēėęìíîïīįñòóôõöōùúûüūýÿž’`',
        'AAAAAAAAACCCEEEEEEEIIIIIINOOOOOOUUUUUYYZaaaaaaaaaccceeeeeeeiiiiiinoooooouuuuuyyz  '
    );
    normalized := regexp_replace(normalized, '^COMMUNE\\s+', '', 'i');
    normalized := regexp_replace(normalized, '^(D''|DE\\s+|DU\\s+|DES\\s+)', '', 'i');
    normalized := regexp_replace(normalized, '[^A-Z0-9]+', ' ', 'g');
    normalized := btrim(regexp_replace(normalized, '\\s+', ' ', 'g'));
    RETURN NULLIF(normalized, '');
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_onep_commune_key(raw_value text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    normalized text;
    mapped text;
BEGIN
    normalized := public.srm_normalize_commune_name(raw_value);
    IF normalized IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT public.srm_normalize_commune_name(alias.decoupage_nom_commune)
    INTO mapped
    FROM public.onep_commune_alias alias
    WHERE alias.actif
      AND public.srm_normalize_commune_name(alias.onep_nom_commune) = normalized
    LIMIT 1;

    RETURN coalesce(mapped, normalized);
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_ep_spatial_commune_key(point_geom geometry)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    commune_key text;
BEGIN
    IF point_geom IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT public.srm_normalize_commune_name(c.nom)
    INTO commune_key
    FROM public.commune_oriental c
    WHERE ST_Covers(c.geom, point_geom)
    ORDER BY ST_Area(c.geom) ASC NULLS LAST
    LIMIT 1;

    RETURN commune_key;
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_append_compteur_abonne_observation(
    current_value character varying,
    note text
)
RETURNS character varying
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    clean_current text;
    clean_note text;
    combined text;
BEGIN
    clean_current := NULLIF(btrim(coalesce(current_value, '')), '');
    clean_note := NULLIF(btrim(coalesce(note, '')), '');
    IF clean_note IS NULL THEN
        RETURN current_value;
    END IF;
    IF clean_current IS NOT NULL AND position(clean_note in clean_current) > 0 THEN
        RETURN left(clean_current, 400)::character varying;
    END IF;

    combined := CASE
        WHEN clean_current IS NULL THEN clean_note
        ELSE clean_current || ' | ' || clean_note
    END;
    RETURN left(combined, 400)::character varying;
END;
$$;

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
            matched_by_contract := true;
        ELSIF onep_count > 1 THEN
            NEW.ep_observation := public.srm_append_compteur_abonne_observation(
                NEW.ep_observation,
                'Liaison ONEP ambigue: numero de contrat ' || contract_key
            );
        END IF;
    END IF;

    IF client IS NULL
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
        ELSIF onep_count > 1 THEN
            NEW.ep_observation := public.srm_append_compteur_abonne_observation(
                NEW.ep_observation,
                'Liaison ONEP ambigue: ancienne police ' || police_key
                    || ' / commune ' || spatial_commune_key
            );
        END IF;
    END IF;

    IF client IS NOT NULL THEN
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
                note := 'Incoherence decoupage client: ONEP='
                    || coalesce(client.nom_commune, '?')
                    || ', spatial=' || spatial_commune_key
                    || '. Liaison conservee par numero de contrat.';
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

DROP TRIGGER IF EXISTS trg_srm_fill_ep_brc_pt_customer_link ON ep.ep_brc_pt;
CREATE TRIGGER trg_srm_fill_ep_brc_pt_customer_link
BEFORE INSERT OR UPDATE OF num_contrat, ancienne_police, geom
ON ep.ep_brc_pt
FOR EACH ROW
EXECUTE FUNCTION ep.srm_fill_ep_brc_pt_customer_link();

WITH desired(nom_champ, type_champ, ordre, titre_app, visible) AS (
    VALUES
        ('type_cpt', 'character varying(400)', 1, 'Type de compteur', true),
        ('diametre', 'character varying(400)', 2, 'Diamètre', true),
        ('ep_observation', 'character varying(400)', 3, 'Observation', true),
        ('ep_anomalie', 'character varying(400)', 4, 'Anomalie', true),
        ('type_anomalie', 'text', 5, 'Type d''anomalie', true),
        ('num_contrat', 'character varying(400)', 10, 'Numéro de contrat', true),
        ('ancienne_police', 'character varying(400)', 11, 'Ancienne police', true),
        ('abon', 'character varying(400)', 12, 'Abonné', true),
        ('nom', 'character varying(400)', 13, 'Nom', true),
        ('adresse', 'character varying(400)', 14, 'Adresse', true),
        ('etat_abonnement', 'character varying(400)', 15, 'Etat abonnement', true),
        ('ancien_ref_sap', 'character varying(400)', 16, 'Ancienne référence SAP', true),
        ('id_geo', 'character varying(400)', 17, 'Identifiant géographique', true),
        ('type_abonnement', 'character varying(400)', 18, 'Type d''abonnement', false),
        ('ref', 'character varying(400)', 19, 'Référence SAP', false)
)
UPDATE public.attribut_config_mobile a
SET type_champ = desired.type_champ,
    ordre = desired.ordre,
    titre_app = desired.titre_app,
    visible = desired.visible
FROM desired
WHERE a.nom_metier = 'ep'
  AND a.nom_table = 'ep_brc_pt'
  AND a.nom_champ = desired.nom_champ;

UPDATE public.attribut_config_mobile
SET visible = false
WHERE nom_metier = 'ep'
  AND nom_table = 'ep_brc_pt'
  AND nom_champ IN ('ep_diam', 'type_abonnement');

UPDATE ep.ep_brc_pt
SET num_contrat = num_contrat
WHERE NULLIF(btrim(coalesce(num_contrat, '')), '') IS NOT NULL
   OR (
        NULLIF(btrim(coalesce(ancienne_police, '')), '') IS NOT NULL
        AND upper(btrim(coalesce(ancienne_police, ''))) NOT IN ('NEANT', 'NÉANT', 'NULL')
      );
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0021_restore_ep_hydrant_conf_plan_visibility"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
