# Comparaison sch?ma BD actuelle vs backup final bureau

- BD actuelle: `SRM_bureau`
- Backup final restaur? en temporaire: `codex_cmp_srm_vf_web_20260508_1440`
- Source backup: `C:\Users\AnasDahou\Downloads\srm_db_vf_web .backup`
- Sch?mas compar?s: `public, ep, asst, elec`
- G?n?r?: `2026-05-08T14:46:39`

## R?sum?
| Schema | Relations + actuelles | Relations + ref | Relations modif | Colonnes + actuelles | Colonnes + ref | Colonnes modif | Contraintes + actuelles | Contraintes + ref | Contraintes modif | Index + actuels | Index + ref | Index modif | Triggers + actuels | Triggers + ref | Triggers modif |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| public | 0 | 17 | 0 | 1 | 365 | 8 | 0 | 5 | 1 | 0 | 2 | 1 | 2 | 1 | 0 |
| ep | 0 | 0 | 0 | 0 | 77 | 171 | 0 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| asst | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| elec | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Schema `public`
### Relations
Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.vw_metrics_agent_jour |
| public.vw_metrics_agent_mois |
| public.vw_metrics_agent_period |
| public.vw_metrics_agent_public_jour |
| public.vw_metrics_agent_public_mois |
| public.vw_metrics_agent_public_resume |
| public.vw_metrics_agent_public_semaine |
| public.vw_metrics_agent_resume |
| public.vw_metrics_agent_semaine |
| public.vw_metrics_agent_table_period |
| public.vw_srm_historique_fact |
| public.vw_srm_incomplet_fact |
| public.vw_srm_intervention_fact |
| public.vw_srm_objet_activity_fact |
| public.vw_srm_objet_dates |
| public.vw_srm_objet_fact |
| public.vw_srm_photo_fact |

### Colonnes
Pr?sent seulement dans la BD actuelle:
| Objet |
| --- |
| public.formulaire_config_mobile.download_mobile |

Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.vw_metrics_agent_jour.famille_geometrie |
| public.vw_metrics_agent_jour.id_agent |
| public.vw_metrics_agent_jour.jour |
| public.vw_metrics_agent_jour.metier |
| public.vw_metrics_agent_jour.metric_uid |
| public.vw_metrics_agent_jour.nb_attributs_mobiles |
| public.vw_metrics_agent_jour.nb_corrections_backoffice |
| public.vw_metrics_agent_jour.nb_corrections_superviseur |
| public.vw_metrics_agent_jour.nb_evenements_mobiles |
| public.vw_metrics_agent_jour.nb_evenements_sync |
| public.vw_metrics_agent_jour.nb_modifications_terrain |
| public.vw_metrics_agent_jour.nb_objets_anomalie |
| public.vw_metrics_agent_jour.nb_objets_avec_photo |
| public.vw_metrics_agent_jour.nb_objets_crees |
| public.vw_metrics_agent_jour.nb_objets_incomplets_completes |
| public.vw_metrics_agent_jour.nb_objets_incomplets_signales |
| public.vw_metrics_agent_jour.nb_photos_renseignees |
| public.vw_metrics_agent_jour.nb_photos_uploadees |
| public.vw_metrics_agent_jour.nb_reouvertures |
| public.vw_metrics_agent_jour.nb_sessions_login |
| public.vw_metrics_agent_jour.nb_sessions_logout |
| public.vw_metrics_agent_jour.nb_validations_terrain |
| public.vw_metrics_agent_jour.nom_schema |
| public.vw_metrics_agent_jour.nom_table |
| public.vw_metrics_agent_jour.type_geometrie |
| public.vw_metrics_agent_mois.annee |
| public.vw_metrics_agent_mois.famille_geometrie |
| public.vw_metrics_agent_mois.id_agent |
| public.vw_metrics_agent_mois.metier |
| public.vw_metrics_agent_mois.metric_uid |
| public.vw_metrics_agent_mois.mois |
| public.vw_metrics_agent_mois.mois_numero |
| public.vw_metrics_agent_mois.nb_attributs_mobiles |
| public.vw_metrics_agent_mois.nb_corrections_backoffice |
| public.vw_metrics_agent_mois.nb_corrections_superviseur |
| public.vw_metrics_agent_mois.nb_evenements_mobiles |
| public.vw_metrics_agent_mois.nb_evenements_sync |
| public.vw_metrics_agent_mois.nb_modifications_terrain |
| public.vw_metrics_agent_mois.nb_objets_anomalie |
| public.vw_metrics_agent_mois.nb_objets_avec_photo |
| public.vw_metrics_agent_mois.nb_objets_crees |
| public.vw_metrics_agent_mois.nb_objets_incomplets_completes |
| public.vw_metrics_agent_mois.nb_objets_incomplets_signales |
| public.vw_metrics_agent_mois.nb_photos_renseignees |
| public.vw_metrics_agent_mois.nb_photos_uploadees |
| public.vw_metrics_agent_mois.nb_reouvertures |
| public.vw_metrics_agent_mois.nb_sessions_login |
| public.vw_metrics_agent_mois.nb_sessions_logout |
| public.vw_metrics_agent_mois.nb_validations_terrain |
| public.vw_metrics_agent_mois.nom_schema |
| public.vw_metrics_agent_mois.nom_table |
| public.vw_metrics_agent_mois.type_geometrie |
| public.vw_metrics_agent_period.actif |
| public.vw_metrics_agent_period.annee |
| public.vw_metrics_agent_period.annee_iso |
| public.vw_metrics_agent_period.grain |
| public.vw_metrics_agent_period.id_agent |
| public.vw_metrics_agent_period.metric_uid |
| public.vw_metrics_agent_period.mois_numero |
| public.vw_metrics_agent_period.moyenne_photos_par_objet |
| public.vw_metrics_agent_period.nb_attributs_mobiles |
| public.vw_metrics_agent_period.nb_corrections_backoffice |
| public.vw_metrics_agent_period.nb_corrections_superviseur |
| public.vw_metrics_agent_period.nb_evenements_mobiles |
| public.vw_metrics_agent_period.nb_evenements_sync |
| public.vw_metrics_agent_period.nb_interventions_cloturees |
| public.vw_metrics_agent_period.nb_interventions_signalees |
| public.vw_metrics_agent_period.nb_interventions_terrain_traitees |
| public.vw_metrics_agent_period.nb_jours_actifs |
| public.vw_metrics_agent_period.nb_lignes |
| public.vw_metrics_agent_period.nb_modifications_terrain |
| public.vw_metrics_agent_period.nb_objets_anomalie |
| public.vw_metrics_agent_period.nb_objets_avec_photo |
| public.vw_metrics_agent_period.nb_objets_crees |
| public.vw_metrics_agent_period.nb_objets_incomplets_completes |
| public.vw_metrics_agent_period.nb_objets_incomplets_signales |
| public.vw_metrics_agent_period.nb_photos_renseignees |
| public.vw_metrics_agent_period.nb_photos_uploadees |
| public.vw_metrics_agent_period.nb_points |
| public.vw_metrics_agent_period.nb_reouvertures |
| public.vw_metrics_agent_period.nb_sessions_login |
| public.vw_metrics_agent_period.nb_sessions_logout |
| public.vw_metrics_agent_period.nb_surfaces |
| public.vw_metrics_agent_period.nb_validations_terrain |
| public.vw_metrics_agent_period.objets_par_heure |
| public.vw_metrics_agent_period.periode_debut |
| public.vw_metrics_agent_period.periode_fin |
| public.vw_metrics_agent_period.semaine_iso |
| public.vw_metrics_agent_period.solde_incomplets |
| public.vw_metrics_agent_period.taux_anomalie_pct |
| public.vw_metrics_agent_period.taux_objets_avec_photo_pct |
| public.vw_metrics_agent_public_jour.actif |
| public.vw_metrics_agent_public_jour.id_agent |
| public.vw_metrics_agent_public_jour.jour |
| public.vw_metrics_agent_public_jour.metric_uid |
| public.vw_metrics_agent_public_jour.moyenne_photos_par_objet |
| public.vw_metrics_agent_public_jour.nb_attributs_mobiles |
| public.vw_metrics_agent_public_jour.nb_corrections_backoffice |
| public.vw_metrics_agent_public_jour.nb_corrections_superviseur |
| public.vw_metrics_agent_public_jour.nb_evenements_mobiles |
| public.vw_metrics_agent_public_jour.nb_evenements_sync |
| public.vw_metrics_agent_public_jour.nb_jours_actifs |
| public.vw_metrics_agent_public_jour.nb_lignes |
| public.vw_metrics_agent_public_jour.nb_modifications_terrain |
| public.vw_metrics_agent_public_jour.nb_objets_anomalie |
| public.vw_metrics_agent_public_jour.nb_objets_avec_photo |
| public.vw_metrics_agent_public_jour.nb_objets_crees |
| public.vw_metrics_agent_public_jour.nb_objets_incomplets_completes |
| public.vw_metrics_agent_public_jour.nb_objets_incomplets_signales |
| public.vw_metrics_agent_public_jour.nb_photos_renseignees |
| public.vw_metrics_agent_public_jour.nb_photos_uploadees |
| public.vw_metrics_agent_public_jour.nb_points |
| public.vw_metrics_agent_public_jour.nb_reouvertures |
| public.vw_metrics_agent_public_jour.nb_sessions_login |
| public.vw_metrics_agent_public_jour.nb_sessions_logout |
| public.vw_metrics_agent_public_jour.nb_surfaces |
| public.vw_metrics_agent_public_jour.nb_validations_terrain |
| public.vw_metrics_agent_public_jour.objets_par_heure |
| public.vw_metrics_agent_public_jour.solde_incomplets |
| public.vw_metrics_agent_public_jour.taux_anomalie_pct |
| public.vw_metrics_agent_public_jour.taux_objets_avec_photo_pct |
| public.vw_metrics_agent_public_mois.actif |
| public.vw_metrics_agent_public_mois.annee |
| public.vw_metrics_agent_public_mois.id_agent |
| public.vw_metrics_agent_public_mois.metric_uid |
| public.vw_metrics_agent_public_mois.mois |
| public.vw_metrics_agent_public_mois.mois_numero |
| public.vw_metrics_agent_public_mois.moyenne_photos_par_objet |
| public.vw_metrics_agent_public_mois.nb_attributs_mobiles |
| public.vw_metrics_agent_public_mois.nb_corrections_backoffice |
| public.vw_metrics_agent_public_mois.nb_corrections_superviseur |
| public.vw_metrics_agent_public_mois.nb_evenements_mobiles |
| public.vw_metrics_agent_public_mois.nb_evenements_sync |
| public.vw_metrics_agent_public_mois.nb_jours_actifs |
| public.vw_metrics_agent_public_mois.nb_lignes |
| public.vw_metrics_agent_public_mois.nb_modifications_terrain |
| public.vw_metrics_agent_public_mois.nb_objets_anomalie |
| public.vw_metrics_agent_public_mois.nb_objets_avec_photo |
| public.vw_metrics_agent_public_mois.nb_objets_crees |
| public.vw_metrics_agent_public_mois.nb_objets_incomplets_completes |
| public.vw_metrics_agent_public_mois.nb_objets_incomplets_signales |
| public.vw_metrics_agent_public_mois.nb_photos_renseignees |
| public.vw_metrics_agent_public_mois.nb_photos_uploadees |
| public.vw_metrics_agent_public_mois.nb_points |
| public.vw_metrics_agent_public_mois.nb_reouvertures |
| public.vw_metrics_agent_public_mois.nb_sessions_login |
| public.vw_metrics_agent_public_mois.nb_sessions_logout |
| public.vw_metrics_agent_public_mois.nb_surfaces |
| public.vw_metrics_agent_public_mois.nb_validations_terrain |
| public.vw_metrics_agent_public_mois.objets_par_heure |
| public.vw_metrics_agent_public_mois.solde_incomplets |
| public.vw_metrics_agent_public_mois.taux_anomalie_pct |
| public.vw_metrics_agent_public_mois.taux_objets_avec_photo_pct |
| public.vw_metrics_agent_public_resume.derniere_activite |
| public.vw_metrics_agent_public_resume.id_agent |
| public.vw_metrics_agent_public_resume.metric_uid |
| public.vw_metrics_agent_public_resume.nb_corrections_backoffice_total |
| public.vw_metrics_agent_public_resume.nb_corrections_superviseur_total |
| public.vw_metrics_agent_public_resume.nb_evenements_sync_total |
| public.vw_metrics_agent_public_resume.nb_jours_actifs |
| public.vw_metrics_agent_public_resume.nb_lignes_total |
| public.vw_metrics_agent_public_resume.nb_modifications_terrain_total |
| public.vw_metrics_agent_public_resume.nb_objets_30j |
| public.vw_metrics_agent_public_resume.nb_objets_7j |
| public.vw_metrics_agent_public_resume.nb_objets_anomalie_total |
| public.vw_metrics_agent_public_resume.nb_objets_avec_photo_total |
| public.vw_metrics_agent_public_resume.nb_objets_crees_total |
| public.vw_metrics_agent_public_resume.nb_objets_incomplets_completes_total |
| public.vw_metrics_agent_public_resume.nb_objets_incomplets_signales_total |
| public.vw_metrics_agent_public_resume.nb_objets_mois_courant |
| public.vw_metrics_agent_public_resume.nb_objets_semaine_courante |
| public.vw_metrics_agent_public_resume.nb_photos_renseignees_total |
| public.vw_metrics_agent_public_resume.nb_photos_uploadees_total |
| public.vw_metrics_agent_public_resume.nb_points_total |
| public.vw_metrics_agent_public_resume.nb_reouvertures_total |
| public.vw_metrics_agent_public_resume.nb_surfaces_total |
| public.vw_metrics_agent_public_resume.nb_validations_terrain_total |
| public.vw_metrics_agent_public_resume.objets_par_heure_global |
| public.vw_metrics_agent_public_resume.premiere_activite |
| public.vw_metrics_agent_public_resume.taux_anomalie_global_pct |
| public.vw_metrics_agent_public_semaine.actif |
| public.vw_metrics_agent_public_semaine.annee_iso |
| public.vw_metrics_agent_public_semaine.id_agent |
| public.vw_metrics_agent_public_semaine.metric_uid |
| public.vw_metrics_agent_public_semaine.moyenne_photos_par_objet |
| public.vw_metrics_agent_public_semaine.nb_attributs_mobiles |
| public.vw_metrics_agent_public_semaine.nb_corrections_backoffice |
| public.vw_metrics_agent_public_semaine.nb_corrections_superviseur |
| public.vw_metrics_agent_public_semaine.nb_evenements_mobiles |
| public.vw_metrics_agent_public_semaine.nb_evenements_sync |
| public.vw_metrics_agent_public_semaine.nb_jours_actifs |
| public.vw_metrics_agent_public_semaine.nb_lignes |
| public.vw_metrics_agent_public_semaine.nb_modifications_terrain |
| public.vw_metrics_agent_public_semaine.nb_objets_anomalie |
| public.vw_metrics_agent_public_semaine.nb_objets_avec_photo |
| public.vw_metrics_agent_public_semaine.nb_objets_crees |
| public.vw_metrics_agent_public_semaine.nb_objets_incomplets_completes |
| public.vw_metrics_agent_public_semaine.nb_objets_incomplets_signales |
| public.vw_metrics_agent_public_semaine.nb_photos_renseignees |
| public.vw_metrics_agent_public_semaine.nb_photos_uploadees |
| public.vw_metrics_agent_public_semaine.nb_points |
| public.vw_metrics_agent_public_semaine.nb_reouvertures |
| public.vw_metrics_agent_public_semaine.nb_sessions_login |
| public.vw_metrics_agent_public_semaine.nb_sessions_logout |
| public.vw_metrics_agent_public_semaine.nb_surfaces |
| public.vw_metrics_agent_public_semaine.nb_validations_terrain |
| public.vw_metrics_agent_public_semaine.objets_par_heure |
| public.vw_metrics_agent_public_semaine.semaine_debut |
| public.vw_metrics_agent_public_semaine.semaine_fin |
| public.vw_metrics_agent_public_semaine.semaine_iso |
| public.vw_metrics_agent_public_semaine.solde_incomplets |
| public.vw_metrics_agent_public_semaine.taux_anomalie_pct |
| public.vw_metrics_agent_public_semaine.taux_objets_avec_photo_pct |
| public.vw_metrics_agent_resume.derniere_activite |
| public.vw_metrics_agent_resume.id_agent |
| public.vw_metrics_agent_resume.metric_uid |
| public.vw_metrics_agent_resume.nb_corrections_backoffice_total |
| public.vw_metrics_agent_resume.nb_corrections_superviseur_total |
| public.vw_metrics_agent_resume.nb_evenements_sync_total |
| public.vw_metrics_agent_resume.nb_interventions_cloturees_total |
| public.vw_metrics_agent_resume.nb_interventions_signalees_total |
| public.vw_metrics_agent_resume.nb_interventions_terrain_traitees_total |
| public.vw_metrics_agent_resume.nb_jours_actifs |
| public.vw_metrics_agent_resume.nb_lignes_total |
| public.vw_metrics_agent_resume.nb_modifications_terrain_total |
| public.vw_metrics_agent_resume.nb_objets_30j |
| public.vw_metrics_agent_resume.nb_objets_7j |
| public.vw_metrics_agent_resume.nb_objets_anomalie_total |
| public.vw_metrics_agent_resume.nb_objets_avec_photo_total |
| public.vw_metrics_agent_resume.nb_objets_crees_total |
| public.vw_metrics_agent_resume.nb_objets_incomplets_completes_total |
| public.vw_metrics_agent_resume.nb_objets_incomplets_signales_total |
| public.vw_metrics_agent_resume.nb_objets_mois_courant |
| public.vw_metrics_agent_resume.nb_objets_semaine_courante |
| public.vw_metrics_agent_resume.nb_photos_renseignees_total |
| public.vw_metrics_agent_resume.nb_photos_uploadees_total |
| public.vw_metrics_agent_resume.nb_points_total |
| public.vw_metrics_agent_resume.nb_reouvertures_total |
| public.vw_metrics_agent_resume.nb_surfaces_total |
| public.vw_metrics_agent_resume.nb_validations_terrain_total |
| public.vw_metrics_agent_resume.objets_par_heure_global |
| public.vw_metrics_agent_resume.premiere_activite |
| public.vw_metrics_agent_resume.taux_anomalie_global_pct |
| public.vw_metrics_agent_semaine.annee_iso |
| public.vw_metrics_agent_semaine.famille_geometrie |
| public.vw_metrics_agent_semaine.id_agent |
| public.vw_metrics_agent_semaine.metier |
| public.vw_metrics_agent_semaine.metric_uid |
| public.vw_metrics_agent_semaine.nb_attributs_mobiles |
| public.vw_metrics_agent_semaine.nb_corrections_backoffice |

_... 115 autres._
Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| public.formulaire_config_mobile.created_at | `not_null`: actuelle=`False` / ref=`True`<br>`default_expr`: actuelle=`None` / ref=`now()` |
| public.formulaire_config_mobile.id | `formatted_type`: actuelle=`integer` / ref=`bigint` |
| public.formulaire_config_mobile.nom_metier | `formatted_type`: actuelle=`character varying` / ref=`character varying(50)`<br>`not_null`: actuelle=`False` / ref=`True`<br>`comment`: actuelle=`None` / ref=`Metier/schema fonctionnel, par exemple ep.` |
| public.formulaire_config_mobile.nom_table | `formatted_type`: actuelle=`character varying` / ref=`character varying(100)`<br>`not_null`: actuelle=`False` / ref=`True`<br>`comment`: actuelle=`None` / ref=`Nom technique exact de la table/config serveur. Ne pas utiliser de nom mobile alias ici.` |
| public.formulaire_config_mobile.ordre | `not_null`: actuelle=`False` / ref=`True`<br>`comment`: actuelle=`None` / ref=`Ordre d affichage du formulaire dans le metier.` |
| public.formulaire_config_mobile.titre_app | `formatted_type`: actuelle=`character varying` / ref=`character varying(255)`<br>`not_null`: actuelle=`False` / ref=`True`<br>`comment`: actuelle=`None` / ref=`Libelle affiche dans l application mobile pour ce formulaire.` |
| public.formulaire_config_mobile.updated_at | `not_null`: actuelle=`False` / ref=`True`<br>`default_expr`: actuelle=`None` / ref=`now()` |
| public.formulaire_config_mobile.visible | `not_null`: actuelle=`False` / ref=`True`<br>`default_expr`: actuelle=`None` / ref=`true`<br>`comment`: actuelle=`None` / ref=`Indique si le formulaire est affiche dans l application mobile.` |

### Contraintes
Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.formulaire_config_mobile.formulaire_config_mobile_metier_ordre_uk |
| public.formulaire_config_mobile.formulaire_config_mobile_metier_table_uk |
| public.formulaire_config_mobile.formulaire_config_mobile_nom_metier_chk |
| public.formulaire_config_mobile.formulaire_config_mobile_nom_table_chk |
| public.formulaire_config_mobile.formulaire_config_mobile_ordre_chk |

Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| public.objet_photo.objet_photo_num_photo_check | `definition`: actuelle=`CHECK (num_photo >= 1)` / ref=`CHECK (num_photo >= 1 AND num_photo <= 4)` |

### Index
Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.formulaire_config_mobile.formulaire_config_mobile_metier_ordre_uk |
| public.formulaire_config_mobile.formulaire_config_mobile_metier_table_uk |

Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| public.historique_traitement.idx_ht_date | `definition`: actuelle=`CREATE INDEX idx_ht_date ON public.historique_traitement USING btree (date_action DESC)` / ref=`CREATE INDEX idx_ht_date ON public.historique_traitement USING btree (date_action)` |

### Triggers
Pr?sent seulement dans la BD actuelle:
| Objet |
| --- |
| public.formulaire_config_mobile.trg_srm_formulaire_config_mobile_download_guard |
| public.objet_photo.trg_objet_photo_prevent_new_extra_slots |

Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.formulaire_config_mobile.trg_formulaire_config_mobile_updated_at |

### Vues
Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.vw_metrics_agent_jour |
| public.vw_metrics_agent_mois |
| public.vw_metrics_agent_period |
| public.vw_metrics_agent_public_jour |
| public.vw_metrics_agent_public_mois |
| public.vw_metrics_agent_public_resume |
| public.vw_metrics_agent_public_semaine |
| public.vw_metrics_agent_resume |
| public.vw_metrics_agent_semaine |
| public.vw_metrics_agent_table_period |
| public.vw_srm_historique_fact |
| public.vw_srm_incomplet_fact |
| public.vw_srm_intervention_fact |
| public.vw_srm_objet_activity_fact |
| public.vw_srm_objet_dates |
| public.vw_srm_objet_fact |
| public.vw_srm_photo_fact |

### Fonctions
Pr?sent seulement dans la BD actuelle:
| Objet |
| --- |
| public.objet_photo_prevent_new_extra_slots. |
| public.srm_formulaire_config_mobile_download_guard. |

Pr?sent seulement dans le backup final:
| Objet |
| --- |
| public.srm_pointz_from_geom_or_coords.input_geom geometry, input_x double precision, input_y double precision, input_z double precision |
| public.srm_regard_pointz_from_geom_or_coords.input_geom geometry, input_x double precision, input_y double precision, input_z double precision |

Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| public.capture_historique_attribut. | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.capture_historique_attribut()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$<br><br>DECLARE<br><br>    pk_column_name text := TG_ARGV[0];<br><br>    v_new json...` / ref=`CREATE OR REPLACE FUNCTION public.capture_historique_attribut()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>DECLARE
<br>    pk_column_name text := TG_ARGV[0];
<br>    v_new json...` |
| public.intervention_anomalie_after_write_log. | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.intervention_anomalie_after_write_log()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>
<br>DECLARE
<br>
<br>    v_action varchar(50);
<br>
<br>    v_user ...` / ref=`CREATE OR REPLACE FUNCTION public.intervention_anomalie_after_write_log()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>DECLARE
<br>    v_action varchar(50);
<br>    v_user intege...` |
| public.intervention_anomalie_before_write. | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.intervention_anomalie_before_write()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$<br>BEGIN<br>    IF NEW.nom_table IS NULL OR btrim(NEW.nom_table...` / ref=`CREATE OR REPLACE FUNCTION public.intervention_anomalie_before_write()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>BEGIN
<br>    IF NEW.nom_table IS NULL OR btrim(NEW.nom_tab...` |
| public.intervention_log_prevent_mutation. | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.intervention_log_prevent_mutation()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$

<br>BEGIN

<br>    IF current_setting('app.allow_intervention_l...` / ref=`CREATE OR REPLACE FUNCTION public.intervention_log_prevent_mutation()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>BEGIN
<br>    IF current_setting('app.allow_intervention_log...` |
| public.set_updated_at. | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.set_updated_at()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$<br>BEGIN<br>  NEW.updated_at = now();<br>  RETURN NEW;<br>END;<br>$function$<br>` / ref=`CREATE OR REPLACE FUNCTION public.set_updated_at()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>BEGIN
<br>  NEW.updated_at = now();
<br>  RETURN NEW;
<br>END;
<br>$function$<br>` |
| public.srm_append_compteur_abonne_observation.current_value character varying, note text | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.srm_append_compteur_abonne_observation(current_value character varying, note text)<br> RETURNS character varying<br> LANGUAGE plpgsql<br> IMMUTABLE<br>AS $...` / ref=`CREATE OR REPLACE FUNCTION public.srm_append_compteur_abonne_observation(current_value character varying, note text)<br> RETURNS character varying<br> LANGUAGE plpgsql<br> IMMUTABLE<br>AS $...` |
| public.srm_ep_spatial_commune_key.point_geom geometry | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.srm_ep_spatial_commune_key(point_geom geometry)<br> RETURNS text<br> LANGUAGE plpgsql<br> STABLE<br>AS $function$<br>DECLARE<br>    commune_key text;<br>BEGIN<br>    I...` / ref=`CREATE OR REPLACE FUNCTION public.srm_ep_spatial_commune_key(point_geom geometry)<br> RETURNS text<br> LANGUAGE plpgsql<br> STABLE<br>AS $function$
<br>DECLARE
<br>    commune_key text;
<br>BEGIN
<br> ...` |
| public.srm_normalize_commune_name.raw_value text | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.srm_normalize_commune_name(raw_value text)<br> RETURNS text<br> LANGUAGE plpgsql<br> IMMUTABLE<br>AS $function$<br>DECLARE<br>    normalized text;<br>BEGIN<br>    norm...` / ref=`CREATE OR REPLACE FUNCTION public.srm_normalize_commune_name(raw_value text)<br> RETURNS text<br> LANGUAGE plpgsql<br> IMMUTABLE<br>AS $function$
<br>DECLARE
<br>    normalized text;
<br>BEGIN
<br>    ...` |
| public.srm_onep_commune_key.raw_value text | `definition`: actuelle=`CREATE OR REPLACE FUNCTION public.srm_onep_commune_key(raw_value text)<br> RETURNS text<br> LANGUAGE plpgsql<br> STABLE<br>AS $function$<br>DECLARE<br>    normalized text;<br>    mapped text;<br>BEGIN<br>...` / ref=`CREATE OR REPLACE FUNCTION public.srm_onep_commune_key(raw_value text)<br> RETURNS text<br> LANGUAGE plpgsql<br> STABLE<br>AS $function$
<br>DECLARE
<br>    normalized text;
<br>    mapped text;
<br>BE...` |

### S?quences
Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| public.formulaire_config_mobile_id_seq | `data_type`: actuelle=`integer` / ref=`bigint`<br>`max_value`: actuelle=`2147483647` / ref=`9223372036854775807` |

## Schema `ep`
### Colonnes
Pr?sent seulement dans le backup final:
| Objet |
| --- |
| ep.borne_onep.anomalie |
| ep.borne_onep.conformite_plan |
| ep.borne_onep.date_leve |
| ep.borne_onep.id_agent_crea |
| ep.borne_onep.mode_localisation |
| ep.borne_onep.observation |
| ep.borne_onep.type_anomalie |
| ep.bouche_a_cles.anomalie |
| ep.bouche_a_cles.conformite_plan |
| ep.bouche_a_cles.date_leve |
| ep.bouche_a_cles.id_agent_crea |
| ep.bouche_a_cles.id_compteur_abonne |
| ep.bouche_a_cles.id_conduite |
| ep.bouche_a_cles.mode_localisation |
| ep.bouche_a_cles.observation |
| ep.bouche_a_cles.type_anomalie |
| ep.centre_tampon.date_leve |
| ep.centre_tampon.ep_anomalie |
| ep.centre_tampon.mode_localisation |
| ep.conduite_terrain.anomalie |
| ep.conduite_terrain.conformite_plan |
| ep.conduite_terrain.emplacement |
| ep.conduite_terrain.ep_anomalie |
| ep.conduite_terrain.ep_classe_conduite |
| ep.conduite_terrain.ep_croquis |
| ep.conduite_terrain.ep_date_interv |
| ep.conduite_terrain.ep_detail |
| ep.conduite_terrain.ep_dxf_dwg |
| ep.conduite_terrain.ep_entreprise |
| ep.conduite_terrain.ep_etage_p |
| ep.conduite_terrain.ep_lien |
| ep.conduite_terrain.ep_long_c |
| ep.conduite_terrain.ep_long_r |
| ep.conduite_terrain.ep_num |
| ep.conduite_terrain.ep_profondeur |
| ep.conduite_terrain.ep_ref_marche |
| ep.conduite_terrain.ep_ref_rue |
| ep.conduite_terrain.ep_sect_hydro |
| ep.conduite_terrain.ep_statut |
| ep.conduite_terrain.ep_type |
| ep.conduite_terrain.etage_aqua |
| ep.conduite_terrain.id_agent_crea |
| ep.conduite_terrain.mode_localisation |
| ep.conduite_terrain.pente |
| ep.conduite_terrain.ref_rue |
| ep.conduite_terrain.secteur_aqua |
| ep.conduite_terrain.type_anomalie |
| ep.conduite_terrain.zalerte |
| ep.conduite_terrain.zamont |
| ep.conduite_terrain.zaval |
| ep.ep_branchement.emplacement |
| ep.ep_brc_pt.date_leve |
| ep.ep_brc_pt.diametre_calibre_terrain |
| ep.ep_brc_pt.diametre_conduite |
| ep.ep_brc_pt.ep_diam |
| ep.ep_brc_pt.ep_ref_rue |
| ep.ep_conduite.altitude |
| ep.ep_conduite.anomalie |
| ep.ep_conduite.conformite_plan |
| ep.ep_conduite.id_agent_crea |
| ep.ep_conduite.photo_1 |
| ep.ep_conduite.photo_2 |
| ep.ep_conduite.ref_rue |
| ep.ep_conduite.type_anomalie |
| ep.ep_forage.ep_statut |
| ep.ep_hydrant.ep_diam |
| ep.ep_hydrant.ep_etat_s |
| ep.ep_noeud.ep_anomalie |
| ep.ep_noeud.mode_localisation |
| ep.ep_obturateur.emplacement |
| ep.ep_reduc_pres.ep_ref_rue |
| ep.ep_reservoir.emplacement |
| ep.ep_station_pompage.emplacement |
| ep.ep_traversee.ep_long_c |
| ep.ep_traversee.ep_type |
| ep.ep_vanne.ep_etat_s |
| ep.ep_vidange.ep_etat_s |

Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| ep.anomalie_conduite.id_zone | `ordinal`: actuelle=`15` / ref=`16` |
| ep.anomalie_conduite.photo_1 | `ordinal`: actuelle=`16` / ref=`17` |
| ep.anomalie_conduite.photo_2 | `ordinal`: actuelle=`17` / ref=`18` |
| ep.anomalie_conduite.photo_3 | `ordinal`: actuelle=`18` / ref=`19` |
| ep.anomalie_conduite.photo_4 | `ordinal`: actuelle=`19` / ref=`20` |
| ep.anomalie_conduite.source | `ordinal`: actuelle=`20` / ref=`15` |
| ep.autre_objet.ep_coor_x | `ordinal`: actuelle=`22` / ref=`21` |
| ep.autre_objet.ep_coor_y | `ordinal`: actuelle=`23` / ref=`22` |
| ep.borne_onep.id_mission | `ordinal`: actuelle=`19` / ref=`27` |
| ep.borne_onep.id_planche | `ordinal`: actuelle=`20` / ref=`21` |
| ep.bouche_a_cles.date_creation | `ordinal`: actuelle=`12` / ref=`22` |
| ep.bouche_a_cles.date_modif | `ordinal`: actuelle=`13` / ref=`23` |
| ep.bouche_a_cles.date_validation | `ordinal`: actuelle=`17` / ref=`27` |
| ep.bouche_a_cles.ep_coor_x | `ordinal`: actuelle=`3` / ref=`16` |
| ep.bouche_a_cles.ep_coor_y | `ordinal`: actuelle=`4` / ref=`17` |
| ep.bouche_a_cles.ep_coor_z | `ordinal`: actuelle=`5` / ref=`12` |
| ep.bouche_a_cles.geom | `ordinal`: actuelle=`6` / ref=`5` |
| ep.bouche_a_cles.id_commune | `ordinal`: actuelle=`7` / ref=`8` |
| ep.bouche_a_cles.id_mission | `ordinal`: actuelle=`19` / ref=`29` |
| ep.bouche_a_cles.id_planche | `ordinal`: actuelle=`20` / ref=`7` |
| ep.bouche_a_cles.id_province | `ordinal`: actuelle=`8` / ref=`18` |
| ep.bouche_a_cles.id_user_creat | `ordinal`: actuelle=`10` / ref=`20` |
| ep.bouche_a_cles.id_user_modif | `ordinal`: actuelle=`11` / ref=`21` |
| ep.bouche_a_cles.id_user_valid | `ordinal`: actuelle=`16` / ref=`26` |
| ep.bouche_a_cles.id_zone | `ordinal`: actuelle=`9` / ref=`19` |
| ep.bouche_a_cles.is_deleted | `ordinal`: actuelle=`14` / ref=`24` |
| ep.bouche_a_cles.is_validated | `ordinal`: actuelle=`15` / ref=`25` |
| ep.bouche_a_cles.source | `ordinal`: actuelle=`18` / ref=`28` |
| ep.bouche_a_cles.uuid | `ordinal`: actuelle=`2` / ref=`4` |
| ep.centre_tampon.id_mission | `ordinal`: actuelle=`23` / ref=`26` |
| ep.centre_tampon.id_zone | `ordinal`: actuelle=`17` / ref=`21` |
| ep.centre_tampon.photo_1 | `ordinal`: actuelle=`18` / ref=`22` |
| ep.centre_tampon.photo_2 | `ordinal`: actuelle=`19` / ref=`23` |
| ep.centre_tampon.photo_3 | `ordinal`: actuelle=`20` / ref=`24` |
| ep.centre_tampon.photo_4 | `ordinal`: actuelle=`21` / ref=`25` |
| ep.centre_tampon.source | `ordinal`: actuelle=`22` / ref=`17` |
| ep.conduite_terrain.date_creation | `ordinal`: actuelle=`10` / ref=`42` |
| ep.conduite_terrain.date_modif | `ordinal`: actuelle=`11` / ref=`43` |
| ep.conduite_terrain.date_validation | `ordinal`: actuelle=`15` / ref=`47` |
| ep.conduite_terrain.ep_diam | `ordinal`: actuelle=`3` / ref=`5` |
| ep.conduite_terrain.ep_mat | `ordinal`: actuelle=`4` / ref=`6` |
| ep.conduite_terrain.geom | `ordinal`: actuelle=`5` / ref=`2` |
| ep.conduite_terrain.id_commune | `ordinal`: actuelle=`6` / ref=`32` |
| ep.conduite_terrain.id_mission | `ordinal`: actuelle=`22` / ref=`54` |
| ep.conduite_terrain.id_planche | `ordinal`: actuelle=`23` / ref=`31` |
| ep.conduite_terrain.id_province | `ordinal`: actuelle=`7` / ref=`39` |
| ep.conduite_terrain.id_user_creat | `ordinal`: actuelle=`8` / ref=`40` |
| ep.conduite_terrain.id_user_modif | `ordinal`: actuelle=`9` / ref=`41` |
| ep.conduite_terrain.id_user_valid | `ordinal`: actuelle=`14` / ref=`46` |
| ep.conduite_terrain.id_zone | `ordinal`: actuelle=`16` / ref=`51` |
| ep.conduite_terrain.is_deleted | `ordinal`: actuelle=`12` / ref=`44` |
| ep.conduite_terrain.is_validated | `ordinal`: actuelle=`13` / ref=`45` |
| ep.conduite_terrain.photo_1 | `ordinal`: actuelle=`17` / ref=`36` |
| ep.conduite_terrain.photo_2 | `ordinal`: actuelle=`18` / ref=`37` |
| ep.conduite_terrain.photo_3 | `ordinal`: actuelle=`19` / ref=`52` |
| ep.conduite_terrain.photo_4 | `ordinal`: actuelle=`20` / ref=`53` |
| ep.conduite_terrain.source | `ordinal`: actuelle=`21` / ref=`48` |
| ep.conduite_terrain.uuid | `ordinal`: actuelle=`2` / ref=`29` |
| ep.ep_bf.diamcond | `ordinal`: actuelle=`66` / ref=`64` |
| ep.ep_bf.emplacement | `ordinal`: actuelle=`65` / ref=`63` |
| ep.ep_bf.ep_diam | `ordinal`: actuelle=`67` / ref=`65` |
| ep.ep_bf.ep_etat_s | `ordinal`: actuelle=`63` / ref=`62` |
| ep.ep_bf.existence_compteur_global | `ordinal`: actuelle=`68` / ref=`66` |
| ep.ep_bf.existence_compteurs_prives | `ordinal`: actuelle=`69` / ref=`67` |
| ep.ep_bf.fonctionnelle | `ordinal`: actuelle=`70` / ref=`68` |
| ep.ep_bf.id_mission | `ordinal`: actuelle=`62` / ref=`70` |
| ep.ep_bf.nombre_robinets | `ordinal`: actuelle=`71` / ref=`69` |
| ep.ep_branchement.id_mission | `ordinal`: actuelle=`42` / ref=`43` |
| ep.ep_brc_pt.id_mission | `ordinal`: actuelle=`56` / ref=`62` |
| ep.ep_brc_pt.type_anomalie | `ordinal`: actuelle=`57` / ref=`56` |
| ep.ep_conduite.altitute | `ordinal`: actuelle=`43` / ref=`82` |
| ep.ep_conduite.annee_renouv | `ordinal`: actuelle=`42` / ref=`81` |
| ep.ep_conduite.autocad_layer | `ordinal`: actuelle=`33` / ref=`75` |
| ep.ep_conduite.commune | `ordinal`: actuelle=`52` / ref=`67` |
| ep.ep_conduite.date_creation | `ordinal`: actuelle=`67` / ref=`60` |
| ep.ep_conduite.date_modif | `ordinal`: actuelle=`68` / ref=`61` |
| ep.ep_conduite.date_validation | `ordinal`: actuelle=`72` / ref=`65` |
| ep.ep_conduite.emplacement | `ordinal`: actuelle=`14` / ref=`11` |
| ep.ep_conduite.ep_adresse | `ordinal`: actuelle=`16` / ref=`41` |
| ep.ep_conduite.ep_agent_crea | `ordinal`: actuelle=`48` / ref=`47` |
| ep.ep_conduite.ep_agent_maj | `ordinal`: actuelle=`20` / ref=`43` |
| ep.ep_conduite.ep_anomalie | `ordinal`: actuelle=`56` / ref=`53` |
| ep.ep_conduite.ep_classe_conduite | `ordinal`: actuelle=`13` / ref=`10` |
| ep.ep_conduite.ep_code_ter | `ordinal`: actuelle=`5` / ref=`71` |
| ep.ep_conduite.ep_conf_plan | `ordinal`: actuelle=`54` / ref=`51` |
| ep.ep_conduite.ep_coor_x | `ordinal`: actuelle=`57` / ref=`54` |
| ep.ep_conduite.ep_coor_y | `ordinal`: actuelle=`58` / ref=`55` |
| ep.ep_conduite.ep_coor_z | `ordinal`: actuelle=`59` / ref=`56` |
| ep.ep_conduite.ep_croquis | `ordinal`: actuelle=`28` / ref=`25` |
| ep.ep_conduite.ep_date_insertion | `ordinal`: actuelle=`9` / ref=`39` |
| ep.ep_conduite.ep_date_interv | `ordinal`: actuelle=`22` / ref=`24` |
| ep.ep_conduite.ep_date_pose | `ordinal`: actuelle=`8` / ref=`72` |
| ep.ep_conduite.ep_detail | `ordinal`: actuelle=`30` / ref=`27` |
| ep.ep_conduite.ep_diam | `ordinal`: actuelle=`6` / ref=`5` |
| ep.ep_conduite.ep_dxf_dwg | `ordinal`: actuelle=`29` / ref=`26` |
| ep.ep_conduite.ep_entreprise | `ordinal`: actuelle=`18` / ref=`17` |
| ep.ep_conduite.ep_etage_p | `ordinal`: actuelle=`26` / ref=`20` |
| ep.ep_conduite.ep_interv | `ordinal`: actuelle=`21` / ref=`70` |
| ep.ep_conduite.ep_lien | `ordinal`: actuelle=`32` / ref=`28` |
| ep.ep_conduite.ep_long_c | `ordinal`: actuelle=`10` / ref=`7` |
| ep.ep_conduite.ep_long_r | `ordinal`: actuelle=`11` / ref=`8` |
| ep.ep_conduite.ep_mat | `ordinal`: actuelle=`7` / ref=`6` |
| ep.ep_conduite.ep_observ | `ordinal`: actuelle=`23` / ref=`44` |
| ep.ep_conduite.ep_observation | `ordinal`: actuelle=`55` / ref=`52` |
| ep.ep_conduite.ep_p_asbuilt | `ordinal`: actuelle=`27` / ref=`73` |
| ep.ep_conduite.ep_photo | `ordinal`: actuelle=`31` / ref=`74` |
| ep.ep_conduite.ep_profondeur | `ordinal`: actuelle=`12` / ref=`9` |
| ep.ep_conduite.ep_qual1 | `ordinal`: actuelle=`36` / ref=`76` |
| ep.ep_conduite.ep_qual2 | `ordinal`: actuelle=`37` / ref=`77` |
| ep.ep_conduite.ep_qual3 | `ordinal`: actuelle=`38` / ref=`78` |
| ep.ep_conduite.ep_ref_marche | `ordinal`: actuelle=`19` / ref=`18` |
| ep.ep_conduite.ep_ref_rue | `ordinal`: actuelle=`15` / ref=`40` |
| ep.ep_conduite.ep_sect_hydro | `ordinal`: actuelle=`25` / ref=`19` |
| ep.ep_conduite.ep_secteur_com | `ordinal`: actuelle=`17` / ref=`42` |
| ep.ep_conduite.ep_statut | `ordinal`: actuelle=`39` / ref=`23` |
| ep.ep_conduite.ep_tf | `ordinal`: actuelle=`40` / ref=`79` |
| ep.ep_conduite.ep_zone_hydro | `ordinal`: actuelle=`24` / ref=`45` |
| ep.ep_conduite.etage_aqua | `ordinal`: actuelle=`34` / ref=`21` |
| ep.ep_conduite.geom | `ordinal`: actuelle=`62` / ref=`2` |
| ep.ep_conduite.id_commune | `ordinal`: actuelle=`63` / ref=`32` |
| ep.ep_conduite.id_mission | `ordinal`: actuelle=`75` / ref=`84` |
| ep.ep_conduite.id_planche | `ordinal`: actuelle=`76` / ref=`31` |
| ep.ep_conduite.id_province | `ordinal`: actuelle=`64` / ref=`57` |
| ep.ep_conduite.id_user_creat | `ordinal`: actuelle=`65` / ref=`58` |
| ep.ep_conduite.id_user_modif | `ordinal`: actuelle=`66` / ref=`59` |
| ep.ep_conduite.id_user_valid | `ordinal`: actuelle=`71` / ref=`64` |
| ep.ep_conduite.id_zone | `ordinal`: actuelle=`73` / ref=`69` |
| ep.ep_conduite.is_deleted | `ordinal`: actuelle=`69` / ref=`62` |
| ep.ep_conduite.is_validated | `ordinal`: actuelle=`70` / ref=`63` |
| ep.ep_conduite.mission | `ordinal`: actuelle=`61` / ref=`83` |
| ep.ep_conduite.mode_localisation | `ordinal`: actuelle=`60` / ref=`33` |
| ep.ep_conduite.note_renouv | `ordinal`: actuelle=`41` / ref=`80` |
| ep.ep_conduite.pente | `ordinal`: actuelle=`44` / ref=`14` |
| ep.ep_conduite.province | `ordinal`: actuelle=`53` / ref=`68` |
| ep.ep_conduite.sec_com | `ordinal`: actuelle=`49` / ref=`48` |
| ep.ep_conduite.sect_hydr | `ordinal`: actuelle=`50` / ref=`49` |
| ep.ep_conduite.secteur_aqua | `ordinal`: actuelle=`35` / ref=`22` |
| ep.ep_conduite.source | `ordinal`: actuelle=`74` / ref=`66` |
| ep.ep_conduite.uuid | `ordinal`: actuelle=`2` / ref=`29` |
| ep.ep_conduite.zalerte | `ordinal`: actuelle=`47` / ref=`15` |
| ep.ep_conduite.zamont | `ordinal`: actuelle=`45` / ref=`12`<br>`comment`: actuelle=`None` / ref=`Z côté amont (m) — Merchich Nord EPSG:26191 — colonne GeoPackage conservée` |
| ep.ep_conduite.zaval | `ordinal`: actuelle=`46` / ref=`13`<br>`comment`: actuelle=`None` / ref=`Z côté aval (m) — Merchich Nord EPSG:26191 — colonne GeoPackage conservée` |
| ep.ep_conduite.zone | `ordinal`: actuelle=`51` / ref=`50` |
| ep.ep_cone_reduc.id_mission | `ordinal`: actuelle=`54` / ref=`55` |
| ep.ep_cone_reduc.type_anomalie | `ordinal`: actuelle=`55` / ref=`54`<br>`comment`: actuelle=`None` / ref=`Champ mobile normalise depuis attribut_config_mobile.` |
| ep.ep_forage.id_mission | `ordinal`: actuelle=`61` / ref=`62` |
| ep.ep_hydrant.id_mission | `ordinal`: actuelle=`66` / ref=`69` |
| ep.ep_hydrant.type_anomalie | `ordinal`: actuelle=`67` / ref=`68` |
| ep.ep_noeud.id_mission | `ordinal`: actuelle=`37` / ref=`39` |
| ep.ep_obturateur.id_mission | `ordinal`: actuelle=`43` / ref=`44` |
| ep.ep_reduc_pres.id_mission | `ordinal`: actuelle=`61` / ref=`62` |
| ep.ep_regard.fid_regard_source | `ordinal`: actuelle=`69` / ref=`68` |
| ep.ep_regard.id_mission | `ordinal`: actuelle=`68` / ref=`73` |
| ep.ep_regard.miroir_created_at | `ordinal`: actuelle=`72` / ref=`71` |
| ep.ep_regard.miroir_source_fid | `ordinal`: actuelle=`71` / ref=`70` |
| ep.ep_regard.miroir_source_table | `ordinal`: actuelle=`70` / ref=`69` |
| ep.ep_regard.miroir_updated_at | `ordinal`: actuelle=`73` / ref=`72` |
| ep.ep_reservoir.id_mission | `ordinal`: actuelle=`68` / ref=`69` |
| ep.ep_station_pompage.id_mission | `ordinal`: actuelle=`60` / ref=`61` |
| ep.ep_traversee.id_mission | `ordinal`: actuelle=`57` / ref=`59` |
| ep.ep_vanne.id_mission | `ordinal`: actuelle=`61` / ref=`63` |
| ep.ep_vanne.type_anomalie | `ordinal`: actuelle=`62` / ref=`61`<br>`comment`: actuelle=`None` / ref=`Champ mobile normalise depuis attribut_config_mobile.` |
| ep.ep_ventouse.id_mission | `ordinal`: actuelle=`56` / ref=`57` |
| ep.ep_ventouse.type_anomalie | `ordinal`: actuelle=`57` / ref=`56` |
| ep.ep_vidange.id_mission | `ordinal`: actuelle=`57` / ref=`58` |
| ep.statistique_conduite.uuid | `ordinal`: actuelle=`8` / ref=`7` |
| ep.statistique_conduite_segment.uuid | `ordinal`: actuelle=`11` / ref=`10` |
| ep.tn.id_zone | `ordinal`: actuelle=`17` / ref=`18` |
| ep.tn.source | `ordinal`: actuelle=`18` / ref=`17` |
| ep.voie.id_zone | `ordinal`: actuelle=`15` / ref=`16` |
| ep.voie.source | `ordinal`: actuelle=`16` / ref=`15` |

### Contraintes
Pr?sent seulement dans le backup final:
| Objet |
| --- |
| ep.borne_onep.borne_onep_id_agent_crea_fkey |
| ep.bouche_a_cles.bouche_cles_id_compteur_abonne_fkey |
| ep.bouche_a_cles.bouche_cles_id_conduite_fkey |
| ep.bouche_a_cles.fk_bouche_cles_agent |
| ep.conduite_terrain.fk_ep_conduite_terrain_agent |
| ep.ep_conduite.fk_ep_conduite_bureau_agent |

### Fonctions
Diff?rent entre les deux:
| Objet | Diff?rences |
| --- | --- |
| ep.srm_fill_ep_brc_pt_customer_link. | `definition`: actuelle=`CREATE OR REPLACE FUNCTION ep.srm_fill_ep_brc_pt_customer_link()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$<br>DECLARE<br>    contract_key text;<br>    police_key text;<br>    spatial...` / ref=`CREATE OR REPLACE FUNCTION ep.srm_fill_ep_brc_pt_customer_link()<br> RETURNS trigger<br> LANGUAGE plpgsql<br>AS $function$
<br>DECLARE
<br>    contract_key text;
<br>    police_key text;
<br>    spa...` |

## Schema `asst`
_Aucune diff?rence d?tect?e._
## Schema `elec`
_Aucune diff?rence d?tect?e._
## D?tails typ?s des colonnes absentes/ajout?es

### Colonnes pr?sentes dans le backup final mais absentes de la BD actuelle - `public`
| Colonne | Type backup final | Nullable | Default | Commentaire |
| --- | --- | --- | --- | --- |
| public.vw_metrics_agent_jour.famille_geometrie | character varying(20) | YES |  |  |
| public.vw_metrics_agent_jour.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_jour.jour | date | YES |  |  |
| public.vw_metrics_agent_jour.metier | character varying(10) | YES |  |  |
| public.vw_metrics_agent_jour.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_jour.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_jour.nom_schema | character varying(30) | YES |  |  |
| public.vw_metrics_agent_jour.nom_table | character varying(100) | YES |  |  |
| public.vw_metrics_agent_jour.type_geometrie | character varying(30) | YES |  |  |
| public.vw_metrics_agent_mois.annee | integer | YES |  |  |
| public.vw_metrics_agent_mois.famille_geometrie | character varying(20) | YES |  |  |
| public.vw_metrics_agent_mois.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_mois.metier | character varying(10) | YES |  |  |
| public.vw_metrics_agent_mois.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_mois.mois | date | YES |  |  |
| public.vw_metrics_agent_mois.mois_numero | integer | YES |  |  |
| public.vw_metrics_agent_mois.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_mois.nom_schema | character varying(30) | YES |  |  |
| public.vw_metrics_agent_mois.nom_table | character varying(100) | YES |  |  |
| public.vw_metrics_agent_mois.type_geometrie | character varying(30) | YES |  |  |
| public.vw_metrics_agent_period.actif | boolean | YES |  |  |
| public.vw_metrics_agent_period.annee | integer | YES |  |  |
| public.vw_metrics_agent_period.annee_iso | integer | YES |  |  |
| public.vw_metrics_agent_period.grain | character varying(10) | YES |  |  |
| public.vw_metrics_agent_period.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_period.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_period.mois_numero | integer | YES |  |  |
| public.vw_metrics_agent_period.moyenne_photos_par_objet | double precision | YES |  |  |
| public.vw_metrics_agent_period.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_interventions_cloturees | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_interventions_signalees | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_interventions_terrain_traitees | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_jours_actifs | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_lignes | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_points | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_surfaces | bigint | YES |  |  |
| public.vw_metrics_agent_period.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_period.objets_par_heure | double precision | YES |  |  |
| public.vw_metrics_agent_period.periode_debut | date | YES |  |  |
| public.vw_metrics_agent_period.periode_fin | date | YES |  |  |
| public.vw_metrics_agent_period.semaine_iso | integer | YES |  |  |
| public.vw_metrics_agent_period.solde_incomplets | bigint | YES |  |  |
| public.vw_metrics_agent_period.taux_anomalie_pct | double precision | YES |  |  |
| public.vw_metrics_agent_period.taux_objets_avec_photo_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_jour.actif | boolean | YES |  |  |
| public.vw_metrics_agent_public_jour.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_public_jour.jour | date | YES |  |  |
| public.vw_metrics_agent_public_jour.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_public_jour.moyenne_photos_par_objet | double precision | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_jours_actifs | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_lignes | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_points | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_surfaces | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.objets_par_heure | double precision | YES |  |  |
| public.vw_metrics_agent_public_jour.solde_incomplets | bigint | YES |  |  |
| public.vw_metrics_agent_public_jour.taux_anomalie_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_jour.taux_objets_avec_photo_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_mois.actif | boolean | YES |  |  |
| public.vw_metrics_agent_public_mois.annee | integer | YES |  |  |
| public.vw_metrics_agent_public_mois.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_public_mois.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_public_mois.mois | date | YES |  |  |
| public.vw_metrics_agent_public_mois.mois_numero | integer | YES |  |  |
| public.vw_metrics_agent_public_mois.moyenne_photos_par_objet | double precision | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_jours_actifs | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_lignes | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_points | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_surfaces | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.objets_par_heure | double precision | YES |  |  |
| public.vw_metrics_agent_public_mois.solde_incomplets | bigint | YES |  |  |
| public.vw_metrics_agent_public_mois.taux_anomalie_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_mois.taux_objets_avec_photo_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_resume.derniere_activite | date | YES |  |  |
| public.vw_metrics_agent_public_resume.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_public_resume.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_corrections_backoffice_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_corrections_superviseur_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_evenements_sync_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_jours_actifs | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_lignes_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_modifications_terrain_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_30j | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_7j | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_anomalie_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_avec_photo_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_crees_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_incomplets_completes_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_incomplets_signales_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_mois_courant | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_objets_semaine_courante | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_photos_renseignees_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_photos_uploadees_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_points_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_reouvertures_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_surfaces_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.nb_validations_terrain_total | bigint | YES |  |  |
| public.vw_metrics_agent_public_resume.objets_par_heure_global | double precision | YES |  |  |
| public.vw_metrics_agent_public_resume.premiere_activite | date | YES |  |  |
| public.vw_metrics_agent_public_resume.taux_anomalie_global_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_semaine.actif | boolean | YES |  |  |
| public.vw_metrics_agent_public_semaine.annee_iso | integer | YES |  |  |
| public.vw_metrics_agent_public_semaine.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_public_semaine.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_public_semaine.moyenne_photos_par_objet | double precision | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_jours_actifs | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_lignes | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_points | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_surfaces | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.objets_par_heure | double precision | YES |  |  |
| public.vw_metrics_agent_public_semaine.semaine_debut | date | YES |  |  |
| public.vw_metrics_agent_public_semaine.semaine_fin | date | YES |  |  |
| public.vw_metrics_agent_public_semaine.semaine_iso | integer | YES |  |  |
| public.vw_metrics_agent_public_semaine.solde_incomplets | bigint | YES |  |  |
| public.vw_metrics_agent_public_semaine.taux_anomalie_pct | double precision | YES |  |  |
| public.vw_metrics_agent_public_semaine.taux_objets_avec_photo_pct | double precision | YES |  |  |
| public.vw_metrics_agent_resume.derniere_activite | date | YES |  |  |
| public.vw_metrics_agent_resume.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_resume.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_resume.nb_corrections_backoffice_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_corrections_superviseur_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_evenements_sync_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_interventions_cloturees_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_interventions_signalees_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_interventions_terrain_traitees_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_jours_actifs | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_lignes_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_modifications_terrain_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_30j | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_7j | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_anomalie_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_avec_photo_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_crees_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_incomplets_completes_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_incomplets_signales_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_mois_courant | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_objets_semaine_courante | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_photos_renseignees_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_photos_uploadees_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_points_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_reouvertures_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_surfaces_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.nb_validations_terrain_total | bigint | YES |  |  |
| public.vw_metrics_agent_resume.objets_par_heure_global | double precision | YES |  |  |
| public.vw_metrics_agent_resume.premiere_activite | date | YES |  |  |
| public.vw_metrics_agent_resume.taux_anomalie_global_pct | double precision | YES |  |  |
| public.vw_metrics_agent_semaine.annee_iso | integer | YES |  |  |
| public.vw_metrics_agent_semaine.famille_geometrie | character varying(20) | YES |  |  |
| public.vw_metrics_agent_semaine.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_semaine.metier | character varying(10) | YES |  |  |
| public.vw_metrics_agent_semaine.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_semaine.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_semaine.nom_schema | character varying(30) | YES |  |  |
| public.vw_metrics_agent_semaine.nom_table | character varying(100) | YES |  |  |
| public.vw_metrics_agent_semaine.semaine_debut | date | YES |  |  |
| public.vw_metrics_agent_semaine.semaine_fin | date | YES |  |  |
| public.vw_metrics_agent_semaine.semaine_iso | integer | YES |  |  |
| public.vw_metrics_agent_semaine.type_geometrie | character varying(30) | YES |  |  |
| public.vw_metrics_agent_table_period.annee | integer | YES |  |  |
| public.vw_metrics_agent_table_period.annee_iso | integer | YES |  |  |
| public.vw_metrics_agent_table_period.famille_geometrie | character varying(20) | YES |  |  |
| public.vw_metrics_agent_table_period.grain | character varying(10) | YES |  |  |
| public.vw_metrics_agent_table_period.id_agent | integer | YES |  |  |
| public.vw_metrics_agent_table_period.metier | character varying(10) | YES |  |  |
| public.vw_metrics_agent_table_period.metric_uid | text | YES |  |  |
| public.vw_metrics_agent_table_period.mois_numero | integer | YES |  |  |
| public.vw_metrics_agent_table_period.nb_attributs_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_corrections_backoffice | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_corrections_superviseur | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_evenements_mobiles | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_evenements_sync | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_interventions_cloturees | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_interventions_signalees | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_interventions_terrain_traitees | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_modifications_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_objets_anomalie | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_objets_avec_photo | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_objets_crees | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_objets_incomplets_completes | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_objets_incomplets_signales | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_photos_renseignees | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_photos_uploadees | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_reouvertures | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_sessions_login | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_sessions_logout | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nb_validations_terrain | bigint | YES |  |  |
| public.vw_metrics_agent_table_period.nom_schema | character varying(30) | YES |  |  |
| public.vw_metrics_agent_table_period.nom_table | character varying(100) | YES |  |  |
| public.vw_metrics_agent_table_period.periode_debut | date | YES |  |  |
| public.vw_metrics_agent_table_period.periode_fin | date | YES |  |  |
| public.vw_metrics_agent_table_period.semaine_iso | integer | YES |  |  |
| public.vw_metrics_agent_table_period.type_geometrie | character varying(30) | YES |  |  |
| public.vw_srm_historique_fact.action | character varying(50) | YES |  |  |
| public.vw_srm_historique_fact.date_action | timestamp without time zone | YES |  |  |
| public.vw_srm_historique_fact.event_uid | text | YES |  |  |
| public.vw_srm_historique_fact.id_agent | integer | YES |  |  |
| public.vw_srm_historique_fact.id_objet | integer | YES |  |  |
| public.vw_srm_historique_fact.nom_table | character varying(100) | YES |  |  |
| public.vw_srm_historique_fact.source | character varying(20) | YES |  |  |
| public.vw_srm_incomplet_fact.date_completion | timestamp without time zone | YES |  |  |
| public.vw_srm_incomplet_fact.date_signalement | timestamp without time zone | YES |  |  |
| public.vw_srm_incomplet_fact.event_uid | text | YES |  |  |
| public.vw_srm_incomplet_fact.id_agent | integer | YES |  |  |
| public.vw_srm_incomplet_fact.id_objet | integer | YES |  |  |
| public.vw_srm_incomplet_fact.nom_table | character varying | YES |  |  |
| public.vw_srm_incomplet_fact.statut | character varying | YES |  |  |
| public.vw_srm_intervention_fact.date_signalement | timestamp without time zone | YES |  |  |
| public.vw_srm_intervention_fact.etat_terrain | character varying(50) | YES |  |  |
| public.vw_srm_intervention_fact.event_uid | text | YES |  |  |
| public.vw_srm_intervention_fact.id_agent | integer | YES |  |  |
| public.vw_srm_intervention_fact.id_objet | integer | YES |  |  |
| public.vw_srm_intervention_fact.nom_table | character varying(255) | YES |  |  |
| public.vw_srm_intervention_fact.statut | character varying(50) | YES |  |  |
| public.vw_srm_intervention_fact.updated_at | timestamp without time zone | YES |  |  |
| public.vw_srm_objet_activity_fact.anomalie | boolean | YES |  |  |
| public.vw_srm_objet_activity_fact.date_action | date | YES |  |  |
| public.vw_srm_objet_activity_fact.famille_geometrie | character varying(20) | YES |  |  |
| public.vw_srm_objet_activity_fact.id_agent | integer | YES |  |  |
| public.vw_srm_objet_activity_fact.metier | character varying(10) | YES |  |  |
| public.vw_srm_objet_activity_fact.nb_photos_renseignees | integer | YES |  |  |
| public.vw_srm_objet_activity_fact.nom_schema | character varying(30) | YES |  |  |
| public.vw_srm_objet_activity_fact.nom_table | character varying(100) | YES |  |  |
| public.vw_srm_objet_activity_fact.objet_uid | text | YES |  |  |
| public.vw_srm_objet_activity_fact.type_geometrie | character varying(30) | YES |  |  |
| public.vw_srm_objet_dates.date_action | date | YES |  |  |
| public.vw_srm_objet_dates.id_agent | integer | YES |  |  |
| public.vw_srm_objet_dates.metier | character varying(10) | YES |  |  |
| public.vw_srm_objet_dates.nom_schema | character varying(30) | YES |  |  |
| public.vw_srm_objet_dates.nom_table | character varying(100) | YES |  |  |
| public.vw_srm_objet_dates.objet_uid | text | YES |  |  |
| public.vw_srm_objet_fact.anomalie | boolean | YES |  |  |
| public.vw_srm_objet_fact.cle_ligne | character varying(254) | YES |  |  |
| public.vw_srm_objet_fact.date_action | timestamp without time zone | YES |  |  |
| public.vw_srm_objet_fact.famille_geometrie | character varying(20) | YES |  |  |
| public.vw_srm_objet_fact.id_agent_crea | integer | YES |  |  |
| public.vw_srm_objet_fact.id_objet | integer | YES |  |  |
| public.vw_srm_objet_fact.metier | character varying(10) | YES |  |  |
| public.vw_srm_objet_fact.mode_localisation | text | YES |  |  |
| public.vw_srm_objet_fact.nb_photos_renseignees | integer | YES |  |  |
| public.vw_srm_objet_fact.nom_classe | character varying(100) | YES |  |  |
| public.vw_srm_objet_fact.nom_schema | character varying(30) | YES |  |  |
| public.vw_srm_objet_fact.nom_table | character varying(100) | YES |  |  |
| public.vw_srm_objet_fact.objet_uid | text | YES |  |  |
| public.vw_srm_objet_fact.type_anomalie | text | YES |  |  |
| public.vw_srm_objet_fact.type_geometrie | character varying(30) | YES |  |  |
| public.vw_srm_objet_fact.uuid_objet | character varying(254) | YES |  |  |
| public.vw_srm_photo_fact.date_photo | timestamp without time zone | YES |  |  |
| public.vw_srm_photo_fact.id_agent | integer | YES |  |  |
| public.vw_srm_photo_fact.id_objet | integer | YES |  |  |
| public.vw_srm_photo_fact.nom_table | character varying(100) | YES |  |  |
| public.vw_srm_photo_fact.photo_slot | smallint | YES |  |  |
| public.vw_srm_photo_fact.photo_uid | text | YES |  |  |

### Colonnes pr?sentes dans la BD actuelle mais absentes du backup final - `public`
| Colonne | Type BD actuelle | Nullable | Default | Commentaire |
| --- | --- | --- | --- | --- |
| public.formulaire_config_mobile.download_mobile | boolean | NO | false |  |

### Colonnes pr?sentes dans le backup final mais absentes de la BD actuelle - `ep`
| Colonne | Type backup final | Nullable | Default | Commentaire |
| --- | --- | --- | --- | --- |
| ep.borne_onep.anomalie | boolean | YES | false |  |
| ep.borne_onep.conformite_plan | text | YES |  |  |
| ep.borne_onep.date_leve | date | YES |  |  |
| ep.borne_onep.id_agent_crea | integer | YES |  |  |
| ep.borne_onep.mode_localisation | mode_localisation_enum | YES | 'gnss'::mode_localisation_enum |  |
| ep.borne_onep.observation | text | YES |  |  |
| ep.borne_onep.type_anomalie | text | YES |  |  |
| ep.bouche_a_cles.anomalie | boolean | YES | false |  |
| ep.bouche_a_cles.conformite_plan | text | YES |  |  |
| ep.bouche_a_cles.date_leve | timestamp with time zone | YES |  |  |
| ep.bouche_a_cles.id_agent_crea | integer | YES |  |  |
| ep.bouche_a_cles.id_compteur_abonne | integer | YES |  |  |
| ep.bouche_a_cles.id_conduite | integer | YES |  |  |
| ep.bouche_a_cles.mode_localisation | mode_localisation_enum | YES | 'gnss'::mode_localisation_enum |  |
| ep.bouche_a_cles.observation | character varying | YES |  |  |
| ep.bouche_a_cles.type_anomalie | text | YES |  |  |
| ep.centre_tampon.date_leve | timestamp with time zone | YES |  |  |
| ep.centre_tampon.ep_anomalie | character varying(400) | YES |  |  |
| ep.centre_tampon.mode_localisation | character varying(400) | YES |  |  |
| ep.conduite_terrain.anomalie | boolean | YES | false |  |
| ep.conduite_terrain.conformite_plan | text | YES |  |  |
| ep.conduite_terrain.emplacement | character varying | YES |  |  |
| ep.conduite_terrain.ep_anomalie | character varying(400) | YES |  |  |
| ep.conduite_terrain.ep_classe_conduite | character varying | YES |  |  |
| ep.conduite_terrain.ep_croquis | character varying | YES |  |  |
| ep.conduite_terrain.ep_date_interv | date | YES |  |  |
| ep.conduite_terrain.ep_detail | character varying | YES |  |  |
| ep.conduite_terrain.ep_dxf_dwg | character varying | YES |  |  |
| ep.conduite_terrain.ep_entreprise | character varying | YES |  |  |
| ep.conduite_terrain.ep_etage_p | character varying | YES |  |  |
| ep.conduite_terrain.ep_lien | character varying | YES |  |  |
| ep.conduite_terrain.ep_long_c | double precision | YES |  |  |
| ep.conduite_terrain.ep_long_r | double precision | YES |  |  |
| ep.conduite_terrain.ep_num | character varying | YES |  |  |
| ep.conduite_terrain.ep_profondeur | double precision | YES |  |  |
| ep.conduite_terrain.ep_ref_marche | character varying | YES |  |  |
| ep.conduite_terrain.ep_ref_rue | character varying(400) | YES |  |  |
| ep.conduite_terrain.ep_sect_hydro | character varying | YES |  |  |
| ep.conduite_terrain.ep_statut | character varying | YES |  |  |
| ep.conduite_terrain.ep_type | character varying | YES |  |  |
| ep.conduite_terrain.etage_aqua | character varying | YES |  |  |
| ep.conduite_terrain.id_agent_crea | integer | YES |  |  |
| ep.conduite_terrain.mode_localisation | character varying(400) | YES | 'gnss'::mode_localisation_enum |  |
| ep.conduite_terrain.pente | double precision | YES |  |  |
| ep.conduite_terrain.ref_rue | character varying | YES |  |  |
| ep.conduite_terrain.secteur_aqua | character varying | YES |  |  |
| ep.conduite_terrain.type_anomalie | text | YES |  |  |
| ep.conduite_terrain.zalerte | double precision | YES |  |  |
| ep.conduite_terrain.zamont | double precision | YES |  |  |
| ep.conduite_terrain.zaval | double precision | YES |  |  |
| ep.ep_branchement.emplacement | character varying(400) | YES |  |  |
| ep.ep_brc_pt.date_leve | timestamp with time zone | YES |  |  |
| ep.ep_brc_pt.diametre_calibre_terrain | character varying(400) | YES |  |  |
| ep.ep_brc_pt.diametre_conduite | character varying(400) | YES |  |  |
| ep.ep_brc_pt.ep_diam | character varying(400) | YES |  |  |
| ep.ep_brc_pt.ep_ref_rue | character varying(400) | YES |  |  |
| ep.ep_conduite.altitude | double precision | YES |  |  |
| ep.ep_conduite.anomalie | boolean | YES | false |  |
| ep.ep_conduite.conformite_plan | text | YES |  |  |
| ep.ep_conduite.id_agent_crea | integer | YES |  |  |
| ep.ep_conduite.photo_1 | text | YES |  |  |
| ep.ep_conduite.photo_2 | text | YES |  |  |
| ep.ep_conduite.ref_rue | character varying | YES |  |  |
| ep.ep_conduite.type_anomalie | text | YES |  |  |
| ep.ep_forage.ep_statut | character varying(400) | YES |  |  |
| ep.ep_hydrant.ep_diam | character varying(400) | YES |  |  |
| ep.ep_hydrant.ep_etat_s | character varying(400) | YES |  |  |
| ep.ep_noeud.ep_anomalie | character varying(400) | YES |  |  |
| ep.ep_noeud.mode_localisation | character varying(400) | YES |  |  |
| ep.ep_obturateur.emplacement | character varying(400) | YES |  |  |
| ep.ep_reduc_pres.ep_ref_rue | character varying(400) | YES |  |  |
| ep.ep_reservoir.emplacement | character varying(400) | YES |  |  |
| ep.ep_station_pompage.emplacement | character varying(400) | YES |  |  |
| ep.ep_traversee.ep_long_c | double precision | YES |  |  |
| ep.ep_traversee.ep_type | character varying(400) | YES |  |  |
| ep.ep_vanne.ep_etat_s | character varying(400) | YES |  |  |
| ep.ep_vidange.ep_etat_s | character varying(400) | YES |  |  |
