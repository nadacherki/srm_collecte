# Comparaison structure EP / ASST hors ELEC
Source: comparaison entre `SRM_bureau` actuelle et backup bureau `srmo_vf_ .backup`, schemas `ep` et `asst` seulement.

## R?sum?
| Section | Seulement actuelle | Seulement bureau | D?finitions diff?rentes |
|---|---:|---:|---:|
| Relations | 0 | 0 | 0 |
| Colonnes | 79 | 4 | 175 |
| Contraintes | 13 | 68 | 2 |
| Indexes | 14 | 22 | 0 |
| Triggers | 2 | 0 | 0 |
| S?quences | 0 | 0 | 2 |

## Par schema

### Relations
- Seulement actuelle: Aucun.
- Seulement bureau: Aucun.
- D?finitions diff?rentes: Aucun.

### Colonnes
- Seulement actuelle: `ep`=79
- Seulement bureau: `ep`=4
- D?finitions diff?rentes: `ep`=175

### Contraintes
- Seulement actuelle: `ep`=13
- Seulement bureau: `ep`=68
- D?finitions diff?rentes: `ep`=2

### Indexes
- Seulement actuelle: `ep`=14
- Seulement bureau: `ep`=22
- D?finitions diff?rentes: Aucun.

### Triggers
- Seulement actuelle: `ep`=2
- Seulement bureau: Aucun.
- D?finitions diff?rentes: Aucun.

### S?quences
- Seulement actuelle: Aucun.
- Seulement bureau: Aucun.
- D?finitions diff?rentes: `ep`=2

## ASST
Aucune diff?rence structurelle d?tect?e sur `asst`: m?mes tables, m?mes colonnes, m?mes types/null/defaults, m?mes contraintes et m?mes indexes.

## EP - Colonnes seulement dans la BD actuelle
- `autre_objet` (2): ep_coor_x:double precision, ep_coor_y:double precision
- `borne_onep` (7): anomalie:boolean, conformite_plan:text, date_leve:date, id_agent_crea:integer, mode_localisation:mode_localisation_enum, observation:text, type_anomalie:text
- `bouche_a_cles` (9): anomalie:boolean, conformite_plan:text, date_leve:timestamp with time zone(6), id_agent_crea:integer, id_compteur_abonne:integer, id_conduite:integer, mode_localisation:mode_localisation_enum, observation:varchar, type_anomalie:text
- `centre_tampon` (3): date_leve:timestamp with time zone(6), ep_anomalie:varchar(400), mode_localisation:varchar(400)
- `conduite_terrain` (31): anomalie:boolean, conformite_plan:text, emplacement:varchar, ep_anomalie:varchar(400), ep_classe_conduite:varchar, ep_croquis:varchar, ep_date_interv:date, ep_detail:varchar, ep_dxf_dwg:varchar, ep_entreprise:varchar, ep_etage_p:varchar, ep_lien:varchar, ep_long_c:double precision, ep_long_r:double precision, ep_num:varchar, ep_profondeur:double precision, ep_ref_marche:varchar, ep_ref_rue:varchar(400), ep_sect_hydro:varchar, ep_statut:varchar, ep_type:varchar, etage_aqua:varchar, id_agent_crea:integer, mode_localisation:varchar(400), pente:double precision, ref_rue:varchar, secteur_aqua:varchar, type_anomalie:text, zalerte:double precision, zamont:double precision, zaval:double precision
- `ep_branchement` (1): emplacement:varchar(400)
- `ep_brc_pt` (5): date_leve:timestamp with time zone(6), diametre_calibre_terrain:varchar(400), diametre_conduite:varchar(400), ep_diam:varchar(400), ep_ref_rue:varchar(400)
- `ep_conduite` (8): altitude:double precision, anomalie:boolean, conformite_plan:text, id_agent_crea:integer, photo_1:text, photo_2:text, ref_rue:varchar, type_anomalie:text
- `ep_forage` (1): ep_statut:varchar(400)
- `ep_hydrant` (2): ep_diam:varchar(400), ep_etat_s:varchar(400)
- `ep_noeud` (2): ep_anomalie:varchar(400), mode_localisation:varchar(400)
- `ep_obturateur` (1): emplacement:varchar(400)
- `ep_reduc_pres` (1): ep_ref_rue:varchar(400)
- `ep_reservoir` (1): emplacement:varchar(400)
- `ep_station_pompage` (1): emplacement:varchar(400)
- `ep_traversee` (2): ep_long_c:double precision, ep_type:varchar(400)
- `ep_vanne` (1): ep_etat_s:varchar(400)
- `ep_vidange` (1): ep_etat_s:varchar(400)

## EP - Colonnes seulement dans le backup bureau
- `autre_objet` (1): updated_at:timestamp with time zone(6)
- `ep_bf` (1): updated_at:timestamp with time zone(6)
- `statistique_conduite` (1): updated_at:timestamp with time zone(6)
- `statistique_conduite_segment` (1): updated_at:timestamp with time zone(6)

## EP - Diff?rences de type/null/default importantes
| Objet | Attribut | Actuelle | Bureau |
|---|---|---|---|
| `ep.ep_brc_pt.ancien_ref_sap` | `type_signature` | varchar(400) | integer |
| `ep.ep_brc_pt.ancienne_police` | `type_signature` | varchar(400) | integer |
| `ep.ep_brc_pt.id_geo` | `type_signature` | varchar(400) | integer |

## EP - Diff?rences d'ordre de colonnes
Il y a 172 diff?rences d'ordre de colonne dans `ep`. Elles ne changent pas le type ni la compatibilit? SQL des champs, mais elles expliquent une grosse partie du volume du rapport.
| Objet | Attribut | Actuelle | Bureau |
|---|---|---|---|
| `ep.anomalie_conduite.id_mission` | `ordinal_position` | 24 | 21 |
| `ep.anomalie_conduite.id_zone` | `ordinal_position` | 19 | 15 |
| `ep.anomalie_conduite.photo_1` | `ordinal_position` | 20 | 16 |
| `ep.anomalie_conduite.photo_2` | `ordinal_position` | 21 | 17 |
| `ep.anomalie_conduite.photo_3` | `ordinal_position` | 22 | 18 |
| `ep.anomalie_conduite.photo_4` | `ordinal_position` | 23 | 19 |
| `ep.anomalie_conduite.source` | `ordinal_position` | 15 | 20 |
| `ep.borne_onep.id_mission` | `ordinal_position` | 28 | 19 |
| `ep.borne_onep.id_planche` | `ordinal_position` | 21 | 20 |
| `ep.bouche_a_cles.date_creation` | `ordinal_position` | 23 | 12 |
| `ep.bouche_a_cles.date_modif` | `ordinal_position` | 24 | 13 |
| `ep.bouche_a_cles.date_validation` | `ordinal_position` | 28 | 17 |
| `ep.bouche_a_cles.ep_coor_x` | `ordinal_position` | 17 | 3 |
| `ep.bouche_a_cles.ep_coor_y` | `ordinal_position` | 18 | 4 |
| `ep.bouche_a_cles.ep_coor_z` | `ordinal_position` | 12 | 5 |
| `ep.bouche_a_cles.geom` | `ordinal_position` | 5 | 6 |
| `ep.bouche_a_cles.id_commune` | `ordinal_position` | 8 | 7 |
| `ep.bouche_a_cles.id_mission` | `ordinal_position` | 30 | 19 |
| `ep.bouche_a_cles.id_planche` | `ordinal_position` | 7 | 20 |
| `ep.bouche_a_cles.id_province` | `ordinal_position` | 19 | 8 |
| `ep.bouche_a_cles.id_user_creat` | `ordinal_position` | 21 | 10 |
| `ep.bouche_a_cles.id_user_modif` | `ordinal_position` | 22 | 11 |
| `ep.bouche_a_cles.id_user_valid` | `ordinal_position` | 27 | 16 |
| `ep.bouche_a_cles.id_zone` | `ordinal_position` | 20 | 9 |
| `ep.bouche_a_cles.is_deleted` | `ordinal_position` | 25 | 14 |
| `ep.bouche_a_cles.is_validated` | `ordinal_position` | 26 | 15 |
| `ep.bouche_a_cles.source` | `ordinal_position` | 29 | 18 |
| `ep.bouche_a_cles.uuid` | `ordinal_position` | 4 | 2 |
| `ep.centre_tampon.id_mission` | `ordinal_position` | 30 | 23 |
| `ep.centre_tampon.id_zone` | `ordinal_position` | 25 | 17 |
| `ep.centre_tampon.photo_1` | `ordinal_position` | 26 | 18 |
| `ep.centre_tampon.photo_2` | `ordinal_position` | 27 | 19 |
| `ep.centre_tampon.photo_3` | `ordinal_position` | 28 | 20 |
| `ep.centre_tampon.photo_4` | `ordinal_position` | 29 | 21 |
| `ep.centre_tampon.source` | `ordinal_position` | 17 | 22 |
| `ep.conduite_terrain.date_creation` | `ordinal_position` | 43 | 10 |
| `ep.conduite_terrain.date_modif` | `ordinal_position` | 44 | 11 |
| `ep.conduite_terrain.date_validation` | `ordinal_position` | 48 | 15 |
| `ep.conduite_terrain.ep_diam` | `ordinal_position` | 5 | 3 |
| `ep.conduite_terrain.ep_mat` | `ordinal_position` | 6 | 4 |
| `ep.conduite_terrain.geom` | `ordinal_position` | 2 | 5 |
| `ep.conduite_terrain.id_commune` | `ordinal_position` | 32 | 6 |
| `ep.conduite_terrain.id_mission` | `ordinal_position` | 58 | 22 |
| `ep.conduite_terrain.id_planche` | `ordinal_position` | 31 | 23 |
| `ep.conduite_terrain.id_province` | `ordinal_position` | 40 | 7 |
| `ep.conduite_terrain.id_user_creat` | `ordinal_position` | 41 | 8 |
| `ep.conduite_terrain.id_user_modif` | `ordinal_position` | 42 | 9 |
| `ep.conduite_terrain.id_user_valid` | `ordinal_position` | 47 | 14 |
| `ep.conduite_terrain.id_zone` | `ordinal_position` | 55 | 16 |
| `ep.conduite_terrain.is_deleted` | `ordinal_position` | 45 | 12 |
| `ep.conduite_terrain.is_validated` | `ordinal_position` | 46 | 13 |
| `ep.conduite_terrain.photo_1` | `ordinal_position` | 36 | 17 |
| `ep.conduite_terrain.photo_2` | `ordinal_position` | 37 | 18 |
| `ep.conduite_terrain.photo_3` | `ordinal_position` | 56 | 19 |
| `ep.conduite_terrain.photo_4` | `ordinal_position` | 57 | 20 |
| `ep.conduite_terrain.source` | `ordinal_position` | 49 | 21 |
| `ep.conduite_terrain.uuid` | `ordinal_position` | 29 | 2 |
| `ep.ep_bache.id_mission` | `ordinal_position` | 55 | 51 |
| `ep.ep_bf.diamcond` | `ordinal_position` | 68 | 66 |
| `ep.ep_bf.emplacement` | `ordinal_position` | 67 | 65 |
| ... | ... | ... | 112 autres diff?rences dans le JSON d?taill? |

## EP - Contraintes seulement dans la BD actuelle
| Objet | D?tail |
|---|---|
| `ep.anomalie_conduite.ep_anomalie_conduite_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.borne_onep.borne_onep_id_agent_crea_fkey` | constraint_type=f; definition=FOREIGN KEY (id_agent_crea) REFERENCES utilisateur(id_user) ON DELETE SET NULL |
| `ep.bouche_a_cles.bouche_cles_id_compteur_abonne_fkey` | constraint_type=f; definition=FOREIGN KEY (id_compteur_abonne) REFERENCES ep.ep_brc_pt(fid) ON DELETE SET NULL |
| `ep.bouche_a_cles.bouche_cles_id_conduite_fkey` | constraint_type=f; definition=FOREIGN KEY (id_conduite) REFERENCES ep.ep_conduite(fid) ON DELETE SET NULL |
| `ep.bouche_a_cles.bouche_cles_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.bouche_a_cles.fk_bouche_cles_agent` | constraint_type=f; definition=FOREIGN KEY (id_agent_crea) REFERENCES utilisateur(id_user) ON DELETE SET NULL |
| `ep.centre_tampon.ep_centre_tampon_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.conduite_terrain.ep_conduite_terrain_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.conduite_terrain.fk_ep_conduite_terrain_agent` | constraint_type=f; definition=FOREIGN KEY (id_agent_crea) REFERENCES utilisateur(id_user) ON DELETE SET NULL |
| `ep.ep_conduite.ep_conduite_bureau_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.ep_conduite.fk_ep_conduite_bureau_agent` | constraint_type=f; definition=FOREIGN KEY (id_agent_crea) REFERENCES utilisateur(id_user) ON DELETE SET NULL |
| `ep.tn.ep_tn_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.voie.ep_voie_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |

## EP - Contraintes seulement dans le backup bureau
| Objet | D?tail |
|---|---|
| `ep.anomalie_conduite.anomalie_conduite_id_commune_fkey` | constraint_type=f; definition=FOREIGN KEY (id_commune) REFERENCES commune_oriental(fid) |
| `ep.anomalie_conduite.anomalie_conduite_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.anomalie_conduite.anomalie_conduite_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.anomalie_conduite.anomalie_conduite_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.anomalie_conduite.anomalie_conduite_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.anomalie_conduite.anomalie_conduite_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.anomalie_conduite.anomalie_conduite_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.anomalie_conduite.anomalie_conduite_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.anomalie_conduite.anomalie_conduite_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.borne_onep.borne_onep_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.bouche_a_cles.bouche_a_cles_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.bouche_a_cles.bouche_a_cles_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.bouche_a_cles.bouche_a_cles_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.bouche_a_cles.bouche_a_cles_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.bouche_a_cles.bouche_a_cles_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.bouche_a_cles.bouche_a_cles_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.bouche_a_cles.bouche_a_cles_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.bouche_a_cles.bouche_a_cles_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.centre_tampon.centre_tampon_id_commune_fkey` | constraint_type=f; definition=FOREIGN KEY (id_commune) REFERENCES commune_oriental(fid) |
| `ep.centre_tampon.centre_tampon_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.centre_tampon.centre_tampon_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.centre_tampon.centre_tampon_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.centre_tampon.centre_tampon_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.centre_tampon.centre_tampon_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.centre_tampon.centre_tampon_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.centre_tampon.centre_tampon_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.centre_tampon.centre_tampon_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.conduite_terrain.conduite_terrain_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.conduite_terrain.conduite_terrain_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.conduite_terrain.conduite_terrain_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.conduite_terrain.conduite_terrain_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.conduite_terrain.conduite_terrain_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.conduite_terrain.conduite_terrain_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.conduite_terrain.conduite_terrain_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.conduite_terrain.conduite_terrain_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.ep_conduite.ep_conduite_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.ep_conduite.ep_conduite_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.ep_conduite.ep_conduite_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.ep_conduite.ep_conduite_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.ep_conduite.ep_conduite_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.ep_conduite.ep_conduite_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.ep_conduite.ep_conduite_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.ep_conduite.ep_conduite_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.ep_regard.ep_regard_id_commune_fkey` | constraint_type=f; definition=FOREIGN KEY (id_commune) REFERENCES commune_oriental(fid) |
| `ep.ep_regard.ep_regard_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.ep_regard.ep_regard_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.ep_regard.ep_regard_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.ep_regard.ep_regard_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.ep_regard.ep_regard_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.ep_regard.ep_regard_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.tn.tn_id_commune_fkey` | constraint_type=f; definition=FOREIGN KEY (id_commune) REFERENCES commune_oriental(fid) |
| `ep.tn.tn_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.tn.tn_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.tn.tn_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.tn.tn_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.tn.tn_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.tn.tn_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.tn.tn_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.tn.tn_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |
| `ep.voie.voie_id_commune_fkey` | constraint_type=f; definition=FOREIGN KEY (id_commune) REFERENCES commune_oriental(fid) |
| `ep.voie.voie_id_province_fkey` | constraint_type=f; definition=FOREIGN KEY (id_province) REFERENCES province(fid) |
| `ep.voie.voie_id_user_creat_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_creat) REFERENCES utilisateur(id_user) |
| `ep.voie.voie_id_user_modif_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_modif) REFERENCES utilisateur(id_user) |
| `ep.voie.voie_id_user_valid_fkey` | constraint_type=f; definition=FOREIGN KEY (id_user_valid) REFERENCES utilisateur(id_user) |
| `ep.voie.voie_id_zone_fkey` | constraint_type=f; definition=FOREIGN KEY (id_zone) REFERENCES zone(id_zone) |
| `ep.voie.voie_pkey` | constraint_type=p; definition=PRIMARY KEY (fid) |
| `ep.voie.voie_source_check` | constraint_type=c; definition=CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.voie.voie_uuid_key` | constraint_type=u; definition=UNIQUE (uuid) |

## EP - Contraintes avec d?finition diff?rente
| Objet | Attribut | Actuelle | Bureau |
|---|---|---|---|
| `ep.borne_onep.borne_onep_source_check` | `definition` | CHECK ((source = ANY (ARRAY['web'::text, 'mobile'::text])) OR source IS NULL) | CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |
| `ep.onep_db.onep_db_source_check` | `definition` | CHECK ((source = ANY (ARRAY['web'::text, 'mobile'::text])) OR source IS NULL) | CHECK (source = ANY (ARRAY['web'::text, 'mobile'::text])) |

## EP - Index seulement dans la BD actuelle
| Objet | D?tail |
|---|---|
| `ep.anomalie_conduite.ep_anomalie_conduite_geom_gix` | definition=CREATE INDEX ep_anomalie_conduite_geom_gix ON ep.anomalie_conduite USING gist (geom) |
| `ep.anomalie_conduite.ep_anomalie_conduite_pkey` | definition=CREATE UNIQUE INDEX ep_anomalie_conduite_pkey ON ep.anomalie_conduite USING btree (fid) |
| `ep.bouche_a_cles.bouche_cles_geom_geom_idx` | definition=CREATE INDEX bouche_cles_geom_geom_idx ON ep.bouche_a_cles USING gist (geom) |
| `ep.bouche_a_cles.bouche_cles_pkey` | definition=CREATE UNIQUE INDEX bouche_cles_pkey ON ep.bouche_a_cles USING btree (fid) |
| `ep.centre_tampon.ep_centre_tampon_geom_gix` | definition=CREATE INDEX ep_centre_tampon_geom_gix ON ep.centre_tampon USING gist (geom) |
| `ep.centre_tampon.ep_centre_tampon_pkey` | definition=CREATE UNIQUE INDEX ep_centre_tampon_pkey ON ep.centre_tampon USING btree (fid) |
| `ep.conduite_terrain.ep_conduite_terrain_geom_geom_idx` | definition=CREATE INDEX ep_conduite_terrain_geom_geom_idx ON ep.conduite_terrain USING gist (geom) |
| `ep.conduite_terrain.ep_conduite_terrain_pkey` | definition=CREATE UNIQUE INDEX ep_conduite_terrain_pkey ON ep.conduite_terrain USING btree (fid) |
| `ep.ep_conduite.ep_conduite_bureau_geom_geom_idx` | definition=CREATE INDEX ep_conduite_bureau_geom_geom_idx ON ep.ep_conduite USING gist (geom) |
| `ep.ep_conduite.ep_conduite_bureau_pkey` | definition=CREATE UNIQUE INDEX ep_conduite_bureau_pkey ON ep.ep_conduite USING btree (fid) |
| `ep.tn.ep_tn_geom_gix` | definition=CREATE INDEX ep_tn_geom_gix ON ep.tn USING gist (geom) |
| `ep.tn.ep_tn_pkey` | definition=CREATE UNIQUE INDEX ep_tn_pkey ON ep.tn USING btree (fid) |
| `ep.voie.ep_voie_geom_gix` | definition=CREATE INDEX ep_voie_geom_gix ON ep.voie USING gist (geom) |
| `ep.voie.ep_voie_pkey` | definition=CREATE UNIQUE INDEX ep_voie_pkey ON ep.voie USING btree (fid) |

## EP - Index seulement dans le backup bureau
| Objet | D?tail |
|---|---|
| `ep.anomalie_conduite.anomalie_conduite_pkey` | definition=CREATE UNIQUE INDEX anomalie_conduite_pkey ON ep.anomalie_conduite USING btree (fid) |
| `ep.anomalie_conduite.anomalie_conduite_uuid_key` | definition=CREATE UNIQUE INDEX anomalie_conduite_uuid_key ON ep.anomalie_conduite USING btree (uuid) |
| `ep.anomalie_conduite.idx_anomalie_conduite_geom` | definition=CREATE INDEX idx_anomalie_conduite_geom ON ep.anomalie_conduite USING gist (geom) |
| `ep.borne_onep.borne_onep_uuid_key` | definition=CREATE UNIQUE INDEX borne_onep_uuid_key ON ep.borne_onep USING btree (uuid) |
| `ep.bouche_a_cles.bouche_a_cles_pkey` | definition=CREATE UNIQUE INDEX bouche_a_cles_pkey ON ep.bouche_a_cles USING btree (fid) |
| `ep.bouche_a_cles.bouche_a_cles_uuid_key` | definition=CREATE UNIQUE INDEX bouche_a_cles_uuid_key ON ep.bouche_a_cles USING btree (uuid) |
| `ep.bouche_a_cles.idx_bouche_a_cles_geom` | definition=CREATE INDEX idx_bouche_a_cles_geom ON ep.bouche_a_cles USING gist (geom) |
| `ep.centre_tampon.centre_tampon_pkey` | definition=CREATE UNIQUE INDEX centre_tampon_pkey ON ep.centre_tampon USING btree (fid) |
| `ep.centre_tampon.centre_tampon_uuid_key` | definition=CREATE UNIQUE INDEX centre_tampon_uuid_key ON ep.centre_tampon USING btree (uuid) |
| `ep.centre_tampon.idx_centre_tampon_geom` | definition=CREATE INDEX idx_centre_tampon_geom ON ep.centre_tampon USING gist (geom) |
| `ep.conduite_terrain.conduite_terrain_pkey` | definition=CREATE UNIQUE INDEX conduite_terrain_pkey ON ep.conduite_terrain USING btree (fid) |
| `ep.conduite_terrain.conduite_terrain_uuid_key` | definition=CREATE UNIQUE INDEX conduite_terrain_uuid_key ON ep.conduite_terrain USING btree (uuid) |
| `ep.conduite_terrain.idx_conduite_terrain_geom` | definition=CREATE INDEX idx_conduite_terrain_geom ON ep.conduite_terrain USING gist (geom) |
| `ep.ep_conduite.ep_conduite_pkey` | definition=CREATE UNIQUE INDEX ep_conduite_pkey ON ep.ep_conduite USING btree (fid) |
| `ep.ep_conduite.ep_conduite_uuid_key` | definition=CREATE UNIQUE INDEX ep_conduite_uuid_key ON ep.ep_conduite USING btree (uuid) |
| `ep.ep_conduite.idx_ep_conduite_geom` | definition=CREATE INDEX idx_ep_conduite_geom ON ep.ep_conduite USING gist (geom) |
| `ep.tn.idx_tn_geom` | definition=CREATE INDEX idx_tn_geom ON ep.tn USING gist (geom) |
| `ep.tn.tn_pkey` | definition=CREATE UNIQUE INDEX tn_pkey ON ep.tn USING btree (fid) |
| `ep.tn.tn_uuid_key` | definition=CREATE UNIQUE INDEX tn_uuid_key ON ep.tn USING btree (uuid) |
| `ep.voie.idx_voie_geom` | definition=CREATE INDEX idx_voie_geom ON ep.voie USING gist (geom) |
| `ep.voie.voie_pkey` | definition=CREATE UNIQUE INDEX voie_pkey ON ep.voie USING btree (fid) |
| `ep.voie.voie_uuid_key` | definition=CREATE UNIQUE INDEX voie_uuid_key ON ep.voie USING btree (uuid) |

## EP - Triggers
### Seulement actuelle
| Objet | D?tail |
|---|---|
| `ep.ep_brc_pt.trg_srm_fill_ep_brc_pt_customer_link.INSERT` | action_timing=BEFORE; action_statement=EXECUTE FUNCTION ep.srm_fill_ep_brc_pt_customer_link() |
| `ep.ep_brc_pt.trg_srm_fill_ep_brc_pt_customer_link.UPDATE` | action_timing=BEFORE; action_statement=EXECUTE FUNCTION ep.srm_fill_ep_brc_pt_customer_link() |

### Seulement bureau
Aucun.
