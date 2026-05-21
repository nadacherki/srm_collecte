# Audit Bloc 4 — Branchement config mobile (serveur ↔ Flutter)

**Date** : 2026-05-20
**Contexte** : pré-test APK release pointant sur Django local (192.168.8.128:6061), BD `SRM_bureau`.

## 1. Volumétrie BD (rappel)

| Table | Lignes | Notes |
|---|---|---|
| `formulaire_config_mobile` | 61 | 38 visibles, 40 downloadables — 2 cas `download_mobile=true` mais `visible=false` : `ep_regard`, `onep_db` (intentionnel : rendu visuel / liens FK sans formulaire) |
| `attribut_config_mobile` | 3 279 | 310 visibles. Le reste = PK, FK techniques, géom, audit (created_at, updated_at), pas anormal |
| `liste_choix` | 938 | 937 actives, **1 inactive** : `ep.ep_vanne.ep_marque = "introuvable"` (ordre 6) |

## 2. Flux serveur

| Endpoint | Filtrage serveur | Renommages JSON |
|---|---|---|
| `GET /api/formulaire-config-mobile/` | `visible_only`, `download_only` optionnels (COALESCE) | Aucun |
| `GET /api/attribut-config-mobile/` | `visible_only` optionnel | Aucun |
| `GET /api/srm-field-options/` | `active_only=true` par défaut, dédup | `id→id_option`, `nom_metier→table_schema`, `nom_table→table_name`, `nom_champ→field_name`, `liste_choix_valeur→code_value`, `liste_choix_alias→label_value` (fallback valeur si alias null), `liste_choix_ordre→display_order` |

**Auth** : aucun des 3 endpoints n'exige `IsAuthenticated`. Public par défaut. Hors scope test Bloc 4 mais à noter pour sécurité.

## 3. Flux Flutter

### 3.1 Refresh au login (`login_page.dart:56-85`)
Les 3 endpoints sont appelés **en parallèle**, **systématiquement** (pas conditionné au cache vide). Timeout global 8 s. En cas d'échec : cache SQLite précédent conservé, **erreur silencieuse** (debugPrint).

### 3.2 Refresh à l'ouverture d'un formulaire (`srm_point_form_widget.dart:295-307`)
**Chaque ouverture de formulaire** déclenche `forceRefresh: true` sur les attributs et options du formulaire en question. Donc même si le login a échoué partiellement, le formulaire re-pull à l'ouverture. C'est un filet de sécurité important.

### 3.3 Refresh à la reconnexion réseau (`home_page_bootstrap.dart:265-315`)
**Throttle 2 min** : pas de re-pull si dernier refresh < 2 min. Concerne uniquement le refresh global au bootstrap, **pas** l'ouverture de formulaires individuels.

### 3.4 Cache local
- Tables SQLite : `formulaire_config_mobile_local`, `attribut_config_mobile_local`, `srm_field_option_local`
- Stratégie `REPLACE INTO` (upsert)
- Filtrage `visible=1` appliqué côté SQLite pour les formulaires (`database_helper.dart:4340`) et options (`actif=1` pour `srm_field_option_local`)

### 3.5 Fallbacks hardcodés
- **Formulaires** : oui, 61 items dans `formulaire_config_mobile_service.dart:443-1118`. Utilisé si BD vide + fetch échoue.
- **Attributs** : ❌ **AUCUN** fallback hardcodé. Si pull échoue + cache vide → `[]` → formulaire vide.
- **Options** : ❌ **AUCUN** fallback hardcodé. Idem.

## 4. Mapping des 9 dimensions (item 6)

| Dimension | Transmis | Utilisé | Notes |
|---|---|---|---|
| `visible` (formulaires) | ✅ | ✅ | Filtré au SQLite + UI (`visibleOnly=true`) |
| `visible` (attributs) | ✅ | ✅ | Filtré au **rendu** dans les 3 form pages ([srm_point_form_widget.dart:335-337](PPRCollecte_Flutter/lib/widgets/forms/srm_point_form_widget.dart#L335-L337), [srm_ligne_form_page.dart:464-466](PPRCollecte_Flutter/lib/screens/forms/srm_ligne_form_page.dart#L464-L466), [polygon_form_page.dart:380-381](PPRCollecte_Flutter/lib/screens/forms/polygon_form_page.dart#L380-L381)). Pas filtré dans `getFormFields()` car la logique submit a besoin de tous les attrs pour injecter les valeurs par défaut des invisibles non-null. |
| `ordre` | ✅ | ✅ | ORDER BY ordre |
| `titre_app` | ✅ | ✅ | Fallback `nom_champ` formaté si null |
| `valeur_par_defaut` | ✅ | ✅ | Parsée par type |
| `nullable` | ✅ | ✅ | Détermine `isRequired` |
| `valeur_min` / `valeur_max` | ✅ | ✅ | Validation au submit — **mais 3 cas seulement en BD, coverage faible** |
| `liste_choix_actif` | ✅ | ✅ | Filtré côté serveur + SQLite |
| `liste_choix_alias` vs `valeur` | ✅ | ✅ | `label_value` (alias prioritaire) affiché, `code_value` envoyé en POST |
| `contraintes` | ✅ stocké | ❌ **pas interprété** | Champ texte libre côté serveur, jamais lu côté Flutter pour validation |

## 5. Comportement sur réponses anormales

| Scénario | Comportement | Verdict |
|---|---|---|
| `/api/formulaire-config-mobile/` → 200 + `[]`, cache vide | Fallback hardcodé 61 items | ✅ |
| `/api/attribut-config-mobile/` → 200 + `[]`, cache vide | Formulaire affichable mais **sans aucun champ** | ❌ blocage |
| `/api/srm-field-options/` → 200 + `[]`, cache vide | Dropdowns vides (peut être OK si pas de liste_choix attendue) | ⚠️ |
| Tout endpoint → 404/500 | Catch silencieux, cache précédent utilisé | ✅ si cache pré-existant, sinon → cas 4-5 ci-dessous |
| Offline + cache présent | Lecture cache, aucune tentative réseau | ✅ |
| Offline + cache vide (1er lancement) | Formulaires fallback, attributs vides | ❌ collecte impossible |

## 5bis. Sémantique `visible` × `nullable` (clarifiée client)

| visible | nullable | default | Comportement | Count BD (sur 40 forms actifs) |
|---|---|---|---|---|
| true | false | with/no | Affiché au collecteur, doit saisir | 211 |
| true | true | with/no | Affiché au collecteur, saisie optionnelle | 65 |
| false | false | with_default | Invisible, injecté auto au POST avec `valeur_par_defaut` | 41 |
| false | false | no_default | Invisible, sentinelle typée injectée (`NON_RENSEIGNE`, `0`, UUID nul, etc.) — éviter à terme | ~~1~~ 0 (fix appliqué : `ep_hydrant.codinsee` → nullable=true) |
| false | true | with/no | Invisible, laissé null si pas résolu | 1572 (audit, FK auto, géom internes) |

## 6. À tester en priorité sur le device (max 8)

Priorisés en croisant les risques code et la couverture BD locale :

1. **[CRITIQUE]** Ouvrir un formulaire EP visible (ex: `ep_bf`, `ep_vanne`) et vérifier que tous les champs métier attendus s'affichent dans le bon ordre avec les bons libellés (titre_app). Coverage : 38 formulaires visibles à parcourir au moins en rapide scan.
2. **[CRITIQUE]** Dropdown `ep_vanne.ep_marque` : vérifier que l'option **"introuvable"** (id=1860, actif=false) **n'apparaît pas**. Si elle apparaît, le filtre `actif=true` est cassé.
3. **[FORT]** Champs `nullable=false` : tenter de submit un formulaire en laissant vide un champ requis (453 candidats). L'app doit bloquer avec message clair.
4. **[FORT]** Champ avec `valeur_par_defaut` (353 candidats) : ouvrir un formulaire neuf, vérifier que la valeur défaut est pré-remplie.
5. **[FORT]** Modif config serveur "à chaud" : `UPDATE attribut_config_mobile SET titre_app='TEST_LIBELLE' WHERE ...`, fermer le formulaire, le ré-ouvrir (pas re-login), vérifier que le nouveau libellé apparaît (grâce au `forceRefresh: true` à l'ouverture).
6. **[MOYEN]** Cas `download_mobile=true` + `visible=false` : `ep_regard` doit être téléchargé (visible en carte) mais **pas** dans la liste de formulaires sélectionnables. Idem `onep_db`.
7. **[MOYEN]** Visibilité attribut : `UPDATE attribut_config_mobile SET visible=false WHERE nom_metier='ep' AND nom_table='ep_vanne' AND nom_champ='<un_champ_metier>'`, re-ouvrir formulaire, vérifier que le champ disparaît du rendu **mais** est bien envoyé au serveur (avec valeur_par_defaut si configurée, sinon sentinelle).
8. **[FAIBLE]** Libellés/accents : scan visuel rapide des écrans formulaire — détecter mojibake (caractères type `Ã©`, `Â`) qui indiqueraient un problème d'encodage UTF-8 dans le pipeline serveur → mobile.

## 7. Lacunes à enrichir plus tard (hors scope test actuel)

- `valeur_min` / `valeur_max` : 3 entrées BD seulement → ajouter manuellement quelques cas numériques (pression, profondeur) pour tester sérieusement.
- `contraintes` : non interprété côté mobile. Soit on supprime la colonne, soit on implémente un parseur (regex, longueur, format). Décision produit à prendre.
- Fallbacks attributs/options manquants : si le serveur a un downtime au premier lancement d'un nouvel utilisateur, l'app est inutilisable. Ajouter au moins un fallback minimal serait prudent.
