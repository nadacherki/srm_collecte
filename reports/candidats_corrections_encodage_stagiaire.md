# Corrections encodage candidates depuis backup stagiaire

- Base actuelle: `SRM_bureau`
- Base stagiaire temporaire: `srm_stag_merge_20260508_111731`
- Colonnes candidates: `{'formulaire_config_mobile': ['titre_app'], 'attribut_config_mobile': ['titre_app'], 'liste_choix': ['liste_choix_alias', 'liste_choix_valeur']}`

- Candidats s?rs: 0
- Diff?rences texte rejet?es (pas clairement une am?lioration encodage): 3


## Rejets ? ne pas appliquer automatiquement

- `attribut_config_mobile` id=44 `ep.ep_brc_pt.ref` `titre_app` score 0->0: 'Référence SAP' -> 'Référence'
- `attribut_config_mobile` id=59 `ep.ep_brc_pt.ancien_ref_sap` `titre_app` score 0->0: 'Ancienne référence SAP' -> 'Ancienne reference SAP'
- `attribut_config_mobile` id=60 `ep.ep_brc_pt.id_geo` `titre_app` score 0->0: 'Identifiant géographique' -> 'Identifiant geographique'
