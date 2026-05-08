# Application des contraintes EP bureau mobile-safe

| D?cision | Nombre |
|---|---:|
| `apply` | 53 |
| `skip` | 7 |
| `apply_adapted` | 8 |

## R?sultat d'application

- Application effectu?e sur `SRM_bureau` dans une transaction unique.
- Contraintes appliqu?es: `61` (`53` reprises telles quelles + `8` checks `source` adapt?s pour rester compatibles avec le mobile).
- Contraintes ignor?es: `7` primary keys redondantes; les PK actuelles sont conserv?es.
- Aucun changement de type appliqu?.
- Aucun `updated_at` ajout? au schema `ep`.
- Les contraintes r?centes existantes ont ?t? conserv?es.

## V?rifications post-application

- `ep` contient maintenant `297` contraintes.
- `ep.updated_at`: `0` colonne.
- `ep.ep_brc_pt.ancien_ref_sap`, `ancienne_police`, `id_geo` restent en `varchar(400)`.
- `manage.py check`: OK.
- `tools/audit_mobile_form_mapping.py`: OK, avec les gaps visibles d?j? connus dans le rapport d'audit.

## Contraintes appliqu?es
| Table | Contrainte | Type | Raison |
|---|---|---|---|
| `ep.anomalie_conduite` | `anomalie_conduite_id_commune_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.anomalie_conduite` | `anomalie_conduite_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.borne_onep` | `borne_onep_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.bouche_a_cles` | `bouche_a_cles_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.bouche_a_cles` | `bouche_a_cles_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.bouche_a_cles` | `bouche_a_cles_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.bouche_a_cles` | `bouche_a_cles_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.bouche_a_cles` | `bouche_a_cles_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.bouche_a_cles` | `bouche_a_cles_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.bouche_a_cles` | `bouche_a_cles_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.centre_tampon` | `centre_tampon_id_commune_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.centre_tampon` | `centre_tampon_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.centre_tampon` | `centre_tampon_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.centre_tampon` | `centre_tampon_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.centre_tampon` | `centre_tampon_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.centre_tampon` | `centre_tampon_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.centre_tampon` | `centre_tampon_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.centre_tampon` | `centre_tampon_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.conduite_terrain` | `conduite_terrain_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.conduite_terrain` | `conduite_terrain_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.conduite_terrain` | `conduite_terrain_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.conduite_terrain` | `conduite_terrain_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.conduite_terrain` | `conduite_terrain_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.conduite_terrain` | `conduite_terrain_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.conduite_terrain` | `conduite_terrain_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.ep_conduite` | `ep_conduite_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_conduite` | `ep_conduite_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_conduite` | `ep_conduite_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_conduite` | `ep_conduite_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_conduite` | `ep_conduite_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_conduite` | `ep_conduite_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.ep_conduite` | `ep_conduite_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.ep_regard` | `ep_regard_id_commune_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_regard` | `ep_regard_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_regard` | `ep_regard_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_regard` | `ep_regard_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_regard` | `ep_regard_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_regard` | `ep_regard_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.ep_regard` | `ep_regard_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.tn` | `tn_id_commune_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.tn` | `tn_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.tn` | `tn_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.tn` | `tn_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.tn` | `tn_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.tn` | `tn_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.tn` | `tn_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.tn` | `tn_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |
| `ep.voie` | `voie_id_commune_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.voie` | `voie_id_province_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.voie` | `voie_id_user_creat_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.voie` | `voie_id_user_modif_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.voie` | `voie_id_user_valid_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.voie` | `voie_id_zone_fkey` | `f` | aucun orphelin actuel; FK nullable donc compatible avec champs non remplis par mobile |
| `ep.voie` | `voie_source_check` | `c` | adapt?e pour autoriser source NULL et ?viter de casser mobile |
| `ep.voie` | `voie_uuid_key` | `u` | uuid non dupliqu?; contrainte mobile-safe |

## Contraintes ignor?es
| Table | Contrainte | Type | Raison |
|---|---|---|---|
| `ep.anomalie_conduite` | `anomalie_conduite_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
| `ep.bouche_a_cles` | `bouche_a_cles_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
| `ep.centre_tampon` | `centre_tampon_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
| `ep.conduite_terrain` | `conduite_terrain_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
| `ep.ep_conduite` | `ep_conduite_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
| `ep.tn` | `tn_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
| `ep.voie` | `voie_pkey` | `p` | primary key d?j? pr?sente ou redondante; on garde les noms actuels |
