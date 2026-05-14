from django.db import migrations


FORWARD_SQL = r"""
CREATE OR REPLACE VIEW public.vw_metrics_agent_jour AS
SELECT md5(concat_ws('|',
           COALESCE(id_agent_crea::text, '-'),
           nom_schema,
           nom_table,
           COALESCE(date_action::date, CURRENT_DATE)::text
       )) AS metric_uid,
       COALESCE(date_action::date, CURRENT_DATE) AS jour,
       id_agent_crea AS id_agent,
       nom_schema,
       nom_table,
       metier,
       type_geometrie,
       famille_geometrie,
       count(*)::bigint AS nb_objets_crees,
       count(*) FILTER (WHERE anomalie)::bigint AS nb_objets_anomalie,
       count(*) FILTER (WHERE COALESCE(nb_photos_renseignees, 0) > 0)::bigint
           AS nb_objets_avec_photo,
       COALESCE(sum(nb_photos_renseignees), 0)::bigint AS nb_photos_renseignees,
       0::bigint AS nb_photos_uploadees,
       0::bigint AS nb_objets_incomplets_signales,
       0::bigint AS nb_objets_incomplets_completes,
       0::bigint AS nb_modifications_terrain,
       0::bigint AS nb_validations_terrain,
       0::bigint AS nb_corrections_backoffice,
       0::bigint AS nb_corrections_superviseur,
       0::bigint AS nb_reouvertures,
       0::bigint AS nb_evenements_mobiles,
       0::bigint AS nb_attributs_mobiles,
       0::bigint AS nb_sessions_login,
       0::bigint AS nb_sessions_logout,
       0::bigint AS nb_evenements_sync
FROM public.vw_srm_objet_fact
GROUP BY COALESCE(date_action::date, CURRENT_DATE),
         id_agent_crea,
         nom_schema,
         nom_table,
         metier,
         type_geometrie,
         famille_geometrie;

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_jour AS
WITH object_metrics AS (
    SELECT jour,
           id_agent,
           sum(nb_objets_crees)::bigint AS nb_objets_crees,
           sum(CASE WHEN famille_geometrie = 'POINT' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_points,
           sum(CASE WHEN famille_geometrie = 'LINE' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_lignes,
           sum(CASE WHEN famille_geometrie = 'POLYGON' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_surfaces,
           sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
           sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
           sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
           sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
           sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
           sum(nb_modifications_terrain)::bigint AS nb_modifications_terrain,
           sum(nb_validations_terrain)::bigint AS nb_validations_terrain,
           sum(nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
           sum(nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
           sum(nb_reouvertures)::bigint AS nb_reouvertures,
           sum(nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
           sum(nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
           sum(nb_sessions_login)::bigint AS nb_sessions_login,
           sum(nb_sessions_logout)::bigint AS nb_sessions_logout,
           sum(nb_evenements_sync)::bigint AS nb_evenements_sync
    FROM public.vw_metrics_agent_jour
    GROUP BY jour, id_agent
),
photo_metrics AS (
    SELECT date_photo::date AS jour,
           id_agent,
           count(DISTINCT concat_ws('|', nom_schema, nom_table, uuid_objet))::bigint
               AS nb_objets_avec_photo,
           count(*)::bigint AS nb_photos_uploadees
    FROM public.vw_srm_photo_object_fact
    WHERE id_agent IS NOT NULL
      AND date_photo IS NOT NULL
    GROUP BY date_photo::date, id_agent
),
merged AS (
    SELECT COALESCE(o.jour, p.jour) AS jour,
           COALESCE(o.id_agent, p.id_agent) AS id_agent,
           COALESCE(o.nb_objets_crees, 0)::bigint AS nb_objets_crees,
           COALESCE(o.nb_points, 0)::bigint AS nb_points,
           COALESCE(o.nb_lignes, 0)::bigint AS nb_lignes,
           COALESCE(o.nb_surfaces, 0)::bigint AS nb_surfaces,
           COALESCE(o.nb_objets_anomalie, 0)::bigint AS nb_objets_anomalie,
           (
               COALESCE(o.nb_objets_avec_photo, 0)
               + COALESCE(p.nb_objets_avec_photo, 0)
           )::bigint AS nb_objets_avec_photo,
           COALESCE(o.nb_photos_renseignees, 0)::bigint AS nb_photos_renseignees,
           COALESCE(p.nb_photos_uploadees, 0)::bigint AS nb_photos_uploadees,
           COALESCE(o.nb_objets_incomplets_signales, 0)::bigint AS nb_objets_incomplets_signales,
           COALESCE(o.nb_objets_incomplets_completes, 0)::bigint AS nb_objets_incomplets_completes,
           COALESCE(o.nb_modifications_terrain, 0)::bigint AS nb_modifications_terrain,
           COALESCE(o.nb_validations_terrain, 0)::bigint AS nb_validations_terrain,
           COALESCE(o.nb_corrections_backoffice, 0)::bigint AS nb_corrections_backoffice,
           COALESCE(o.nb_corrections_superviseur, 0)::bigint AS nb_corrections_superviseur,
           COALESCE(o.nb_reouvertures, 0)::bigint AS nb_reouvertures,
           COALESCE(o.nb_evenements_mobiles, 0)::bigint AS nb_evenements_mobiles,
           COALESCE(o.nb_attributs_mobiles, 0)::bigint AS nb_attributs_mobiles,
           COALESCE(o.nb_sessions_login, 0)::bigint AS nb_sessions_login,
           COALESCE(o.nb_sessions_logout, 0)::bigint AS nb_sessions_logout,
           COALESCE(o.nb_evenements_sync, 0)::bigint AS nb_evenements_sync
    FROM object_metrics o
    FULL JOIN photo_metrics p
      ON p.jour = o.jour
     AND p.id_agent = o.id_agent
)
SELECT md5(concat_ws('|', 'public-jour', id_agent::text, jour::text)) AS metric_uid,
       jour,
       id_agent,
       nb_objets_crees,
       nb_points,
       nb_lignes,
       nb_surfaces,
       nb_objets_anomalie,
       CASE WHEN nb_objets_crees > 0
            THEN round((nb_objets_anomalie::numeric * 100) / nb_objets_crees::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_anomalie_pct,
       nb_objets_avec_photo,
       CASE WHEN nb_objets_crees > 0
            THEN LEAST(
                100::numeric,
                round((nb_objets_avec_photo::numeric * 100) / nb_objets_crees::numeric, 2)
            )::double precision
            ELSE 0::double precision END AS taux_objets_avec_photo_pct,
       nb_photos_renseignees,
       nb_photos_uploadees,
       CASE WHEN nb_objets_crees > 0
            THEN round((nb_photos_renseignees + nb_photos_uploadees)::numeric / nb_objets_crees::numeric, 2)::double precision
            ELSE 0::double precision END AS moyenne_photos_par_objet,
       nb_objets_incomplets_signales,
       nb_objets_incomplets_completes,
       (nb_objets_incomplets_signales - nb_objets_incomplets_completes)::bigint AS solde_incomplets,
       nb_modifications_terrain,
       nb_validations_terrain,
       nb_corrections_backoffice,
       nb_corrections_superviseur,
       nb_reouvertures,
       nb_evenements_mobiles,
       nb_attributs_mobiles,
       nb_sessions_login,
       nb_sessions_logout,
       nb_evenements_sync,
       0::double precision AS objets_par_heure,
       true AS actif,
       1::bigint AS nb_jours_actifs
FROM merged;
"""


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0043_fix_public_metrics_photo_and_geometry_sources'),
    ]

    operations = [
        migrations.RunSQL(sql=FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
