# Anomalie / Intervention — référence DB

**DB :** `SRM_oriental_vf` · **Tables :** `public.intervention_anomalie`, `public.intervention_log`

---

## 1. Triggers actifs

### Sur `intervention_anomalie`

| Trigger | Quand | Fonction | Effet |
|---|---|---|---|
| `trg_intervention_anomalie_before_write` | BEFORE INSERT/UPDATE | `intervention_anomalie_before_write()` | Auto-fill (nom_table, dates, etats), force `responsable_actuel` selon `statut` |
| `trg_intervention_anomalie_after_write_log` | AFTER INSERT/UPDATE | `intervention_anomalie_after_write_log()` | Insère automatiquement une ligne dans `intervention_log` |
| `trg_audit_intervention_anomalie` | AFTER INSERT/DELETE/UPDATE | `capture_historique_attribut('id')` | Audit générique vers `historique_action` |

### Sur `intervention_log`

| Trigger | Quand | Fonction | Effet |
|---|---|---|---|
| `trg_intervention_log_prevent_update` | BEFORE DELETE/UPDATE | `intervention_log_prevent_mutation()` | Bloque toute modification (table append-only). Bypass admin : `SET LOCAL app.allow_intervention_log_mutation='on'` |

### Détail — `before_write`

À chaque INSERT/UPDATE, le trigger :

1. **Auto-remplit `nom_table`** depuis `nom_classe` (si non fourni) :
   - `ep_<x>` → `ep.<x>`
   - `ass_<x>` ou `asst_<x>` → `ass.<x>`
   - sinon → `public.<x>`
2. **Auto-remplit dates** : `date_creation`, `created_at` (sur INSERT), `updated_at` (toujours).
3. **Initialise états** par défaut à `'en_attente'` ; statut par défaut à `'signale'` ; responsable_actuel par défaut à `'exploitant'`.
4. **Force `responsable_actuel` depuis `statut`** (cf. table mapping section 4).
5. Selon `statut`, pose aussi : `etat_<étape>='traite'`, `date_<étape>=now()`, `date_cloture=now()`, `retour_terrain=true`.

### Détail — `after_write_log`

| Cas | `action` posée | `de_statut` | `a_statut` |
|---|---|---|---|
| INSERT | `NEW.statut` | `NULL` | `NEW.statut` |
| UPDATE avec changement de `statut` | `NEW.statut` | `OLD.statut` | `NEW.statut` |
| UPDATE sans changement de statut mais d'un commentaire ou état | `'update'` | `OLD.statut` | `NEW.statut` |

`id_user` du log = `COALESCE(NEW.id_user_bureau, NEW.id_user_terrain, NEW.id_user_exploitant, OLD.id_user_bureau, OLD.id_user_terrain, OLD.id_user_exploitant)`.

`commentaire` du log = `COALESCE(commentaire_bureau, commentaire_terrain, commentaire_exploitant, '')` (priorité bureau > terrain > exploitant).

---

## 2. Cycle de vie d'une anomalie

```
       ┌──────────────────┐
       │     SIGNALE      │  ← INSERT mobile (création)
       │  resp=exploitant │
       └────────┬─────────┘
                │ exploitant qualifie (web)
                │ UPDATE statut := 'exploitant_traite'
                ▼
       ┌──────────────────┐
       │ EXPLOITANT_TRAITE│
       │  resp=terrain    │
       └────────┬─────────┘
                │ terrain agit (mobile)
                │ UPDATE statut := 'terrain_traite'
                ▼
       ┌──────────────────┐
       │  TERRAIN_TRAITE  │
       │  resp=bureau     │
       └────────┬─────────┘
                │  bureau décide (web) :
                │  ┌────────────────────────────────────────┐
                │  │                                        │
       ┌────────┴────────┐               ┌──────────────────┐
       │   ✓ valide      │               │  ✗ rejette        │
       │ statut=          │               │ statut=           │
       │  'cloture'       │               │  'retour_terrain' │
       └────────┬─────────┘               └────────┬──────────┘
                ▼                                  │ resp=terrain
       ┌──────────────────┐                        │ etat_terrain=
       │     CLOTURE      │                        │   en_attente
       │  resp=cloture    │                        │ retour_terrain=
       └──────────────────┘                        │   true
                                                   └────────┬──────
                                                            │ terrain refait
                                                            │ UPDATE statut := 'terrain_traite'
                                                            ▼
                                                    (retour vers TERRAIN_TRAITE)

  ── chemins exceptionnels (depuis n'importe quel état non clos) ──

  • Bureau peut renvoyer à l'exploitant pour re-qualifier :
       statut := 'signale' → resp=exploitant
  • Bureau peut annuler (faux positif, anomalie obsolète) :
       statut := 'annule'  → resp=cloture
```

### Qui agit où

| Étape | Acteur | Côté | Endpoint web |
|---|---|---|---|
| création (`signale`) | mobile (auto si `anomalie=oui` + `retour_terrain=oui`) | mobile | — |
| `exploitant_traite` | exploitant | **web** | `POST /api/intervention-anomalie/{id}/traiter-exploitant/` |
| `terrain_traite` | terrain | **mobile** (web possible en backup) | `POST /api/intervention-anomalie/{id}/traiter-terrain/` |
| `cloture` (validation bureau) | bureau | **web** | `POST /api/intervention-anomalie/{id}/valider-bureau/` |
| `retour_terrain` (rejet bureau) | bureau | **web** | `POST /api/intervention-anomalie/{id}/renvoyer-terrain/` |
| renvoi exploitant (`statut=signale` à nouveau) | bureau | **web** | `POST /api/intervention-anomalie/{id}/renvoyer-exploitant/` |
| `annule` | bureau | **web** | `POST /api/intervention-anomalie/{id}/annuler/` |

**Permissions** :
- `traiter-exploitant` requiert `anomalies.intervenir_exploitant`
- Tous les autres endpoints web requièrent `anomalies.intervenir_bureau`

---

## 3. Schéma — `intervention_anomalie`

| Colonne | Type | Null | Défaut | Note |
|---|---|---|---|---|
| `id` | integer | NO | sequence | PK |
| `id_objet` | integer | NO | — | fid de l'objet métier (ex: `ep_regard.fid`) |
| `nom_classe` | varchar(100) | NO | — | nom logique de la couche (ex: `'ep_regard'`) |
| `nom_table` | varchar(255) | NO | (auto) | schema.table — auto-rempli par trigger |
| `uuid_objet` | varchar(254) | YES | — | uuid de l'objet métier (optionnel) |
| `retour_terrain` | boolean | YES | `false` | flag « anomalie rejetée par bureau » — passe à `true` via trigger |
| `statut` | varchar(50) | NO | `'signale'` | état du workflow (cf. table valeurs §4) |
| `responsable_actuel` | varchar(50) | YES | `'exploitant'` | dérivé de `statut` par trigger (cf. §4) |
| `etat_exploitant` | varchar(50) | YES | `'en_attente'` | (cf. table valeurs §4) |
| `commentaire_exploitant` | text | YES | — | |
| `date_exploitant` | timestamp | YES | — | posée par trigger quand `statut='exploitant_traite'` |
| `id_user_exploitant` | integer | YES | — | FK → `utilisateur(id_user)` |
| `etat_terrain` | varchar(50) | YES | `'en_attente'` | |
| `commentaire_terrain` | text | YES | — | |
| `date_terrain` | timestamp | YES | — | posée par trigger quand `statut='terrain_traite'` |
| `id_user_terrain` | integer | YES | — | FK → `utilisateur(id_user)` |
| `etat_bureau` | varchar(50) | YES | `'en_attente'` | |
| `commentaire_bureau` | text | YES | — | |
| `date_bureau` | timestamp | YES | — | |
| `id_user_bureau` | integer | YES | — | FK → `utilisateur(id_user)` |
| `date_creation` | timestamp | YES | `now()` | |
| `date_cloture` | timestamp | YES | — | posée par trigger quand `statut` ∈ {cloture, annule} |
| `created_at` | timestamptz | NO | `now()` | |
| `updated_at` | timestamptz | NO | `now()` | mise à jour à chaque save par trigger |

### Contraintes

- **PK** : `id`
- **FK** : `id_user_exploitant`, `id_user_terrain`, `id_user_bureau` → `utilisateur(id_user)`
- **UNIQUE partiel** : `(nom_table, id_objet) WHERE statut NOT IN ('cloture','annule')` — une seule intervention active par objet
- **Index** : sur `(nom_table, id_objet)`, `(id_objet, nom_classe)`, `responsable_actuel`, `statut`, `uuid_objet WHERE NOT NULL`

---

## 4. Valeurs autorisées par champ (CHECK)

### `statut` — 7 valeurs

| Valeur | Signification | `responsable_actuel` posé par trigger |
|---|---|---|
| `signale` | Anomalie signalée par mobile, attend qualification | `exploitant` |
| `exploitant_traite` | Exploitant a qualifié, terrain doit traiter | `terrain` |
| `terrain_traite` | Terrain a traité, bureau doit valider | `bureau` |
| `bureau_traite` | Bureau a traité (chemin alt) | `bureau` |
| `retour_terrain` | Bureau a rejeté, terrain doit refaire | `terrain` (+ `etat_terrain='en_attente'`, `retour_terrain=true`) |
| `cloture` | Validé par bureau, terminé OK | `cloture` (+ `date_cloture=now()`) |
| `annule` | Anomalie obsolète/faux positif | `cloture` (+ `date_cloture=now()`) |

### `responsable_actuel` — 4 valeurs

| Valeur | Sens |
|---|---|
| `exploitant` | l'exploitant doit agir |
| `terrain` | le terrain doit agir |
| `bureau` | le bureau doit agir |
| `cloture` | personne — l'intervention est close |

> **Important** : `responsable_actuel` est **toujours** dérivé de `statut` par le trigger. Toute valeur écrite par mobile/web est écrasée. Le seul levier pour faire bouger le workflow, c'est `statut`.

### `etat_exploitant` — 4 valeurs

| Valeur | Sens |
|---|---|
| `en_attente` | étape pas encore traitée (défaut) |
| `traite` | étape complétée |
| `rejete` | étape rejetée |
| `a_corriger` | à corriger |

### `etat_terrain` — 4 valeurs

| Valeur | Sens |
|---|---|
| `en_attente` | étape pas encore traitée (défaut) |
| `traite` | étape complétée |
| `rejete` | étape rejetée |
| `a_corriger` | à corriger |

### `etat_bureau` — 5 valeurs

| Valeur | Sens |
|---|---|
| `en_attente` | étape pas encore traitée (défaut) |
| `traite` | bureau a validé/cloturé |
| `rejete` | bureau a rejeté (cf. `renvoyer-terrain` ou `renvoyer-exploitant`) |
| `valide` | (réservé) |
| `a_corriger` | à corriger |

### `retour_terrain` (boolean)

| Valeur | Sens |
|---|---|
| `false` | défaut — l'anomalie n'a pas été rejetée par le bureau |
| `true` | l'anomalie a été rejetée au moins une fois (le trigger pose ça quand `statut='retour_terrain'`) |

---

## 5. Schéma — `intervention_log`

| Colonne | Type | Null | Défaut | Note |
|---|---|---|---|---|
| `id` | integer | NO | sequence | PK |
| `id_intervention` | integer | NO | — | FK → `intervention_anomalie(id)` ON DELETE CASCADE |
| `action` | varchar(50) | NO | — | (cf. valeurs ci-dessous) |
| `de_statut` | varchar(50) | YES | — | statut avant la transition |
| `a_statut` | varchar(50) | YES | — | statut après la transition |
| `id_user` | integer | YES | — | FK → `utilisateur(id_user)` (NOT VALID — anciens user_id non vérifiés) |
| `commentaire` | text | YES | — | |
| `date_action` | timestamp | YES | `now()` | |

### `action` — 8 valeurs autorisées

| Valeur | Quand |
|---|---|
| `signale` | INSERT initial |
| `exploitant_traite` | transition vers exploitant_traite |
| `terrain_traite` | transition vers terrain_traite |
| `bureau_traite` | transition vers bureau_traite |
| `retour_terrain` | bureau a rejeté |
| `cloture` | bureau a validé/cloturé |
| `annule` | annulation |
| `update` | UPDATE sans changement de statut (commentaire/etat modifié) |

### `de_statut` / `a_statut`

Mêmes 7 valeurs que `intervention_anomalie.statut` (sauf `de_statut=NULL` sur INSERT).

### Append-only

- INSERT : OK (auto via trigger `after_write_log`)
- UPDATE : ❌ bloqué
- DELETE : ❌ bloqué (sauf bypass `SET LOCAL app.allow_intervention_log_mutation='on'`)

→ **Ne pas insérer manuellement** dans `intervention_log` côté mobile/web : le trigger le fait déjà, et un INSERT manuel créerait des doublons.

---

## 6. Contrat mobile

### Création d'une anomalie

```sql
INSERT INTO public.intervention_anomalie
    (id_objet, nom_classe, retour_terrain,
     id_user_exploitant, commentaire_exploitant, statut)
VALUES
    (12345, 'ep_regard', false,
     <id_user_signaleur>, '<commentaire>', 'signale');
```

> Pourquoi poser `id_user_exploitant` et `commentaire_exploitant` à l'INSERT ?
> → Le trigger `after_write_log` log la ligne avec `id_user = COALESCE(...)` et `commentaire = COALESCE(...)`. Si tu ne les poses pas, le log aura `id_user=NULL` et `commentaire=''`.

Le trigger pose ensuite : `nom_table='ep.ep_regard'`, `responsable_actuel='exploitant'`, `etat_*='en_attente'`, dates, plus une ligne dans `intervention_log`.

### Traitement terrain (étape principale du mobile)

```sql
UPDATE public.intervention_anomalie
   SET statut              = 'terrain_traite',
       commentaire_terrain = '<commentaire>',
       id_user_terrain     = <id_user_agent>
 WHERE id = <id>;
```

Le trigger pose : `etat_terrain='traite'`, `date_terrain=now()`, `responsable_actuel='bureau'`, plus le log.

### À NE PAS faire

- ❌ Insérer manuellement dans `intervention_log` — le trigger le fait
- ❌ Tenter de poser `responsable_actuel` — il est dérivé du statut
- ❌ UPDATE/DELETE `intervention_log` — bloqué
- ❌ DELETE `intervention_anomalie` sans bypass — CASCADE échoue. Préférer `statut='annule'`

---

## 7. Récap visuel `responsable_actuel`

```
        signale            →  exploitant
        exploitant_traite  →  terrain
        terrain_traite     →  bureau
        bureau_traite      →  bureau
        retour_terrain     →  terrain
        cloture            →  cloture
        annule             →  cloture
```

Source live des triggers en prod :
```sql
SELECT pg_get_functiondef(oid) FROM pg_proc
WHERE proname IN (
    'intervention_anomalie_before_write',
    'intervention_anomalie_after_write_log',
    'intervention_log_prevent_mutation'
);
```
