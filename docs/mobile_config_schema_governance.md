# Mobile Config / Schema Governance

## Regle

Pour les metiers `ep` et `asst`, la structure physique serveur est consideree stable.

Un changement mobile passe d'abord par les tables de configuration :

- `public.formulaire_config_mobile` pour les tables exposees, l'ordre, la visibilite et `download_mobile`.
- `public.attribut_config_mobile` pour les champs, types, titres, ordre, obligation, visibilite, details et references.
- `public.liste_choix` pour les choix, alias, ordre, visibilite et valeurs.

On ne modifie pas directement la structure de `ep` ou `asst` pour corriger un formulaire mobile, sauf demande explicite et validation que le bureau accepte le changement physique.

Exception encadree : le trigger PostgreSQL `trg_srm_attribut_config_mobile_schema_guard` peut appliquer automatiquement les changements physiques sans perte demandes par `public.attribut_config_mobile`.

## Workflow attendu

1. Identifier la table formulaire dans `public.formulaire_config_mobile`.
2. Ajuster les champs dans `public.attribut_config_mobile`.
3. Ajuster les choix dans `public.liste_choix` si le champ est une liste ou une reference.
4. Mettre a jour les fallbacks mobile quand le comportement local en depend.
5. Lancer les audits avant livraison.

## Audits obligatoires

Depuis la racine du projet :

```powershell
srmenv\Scripts\python.exe tools\audit_mobile_config_schema_coherence.py
srmenv\Scripts\python.exe tools\audit_mobile_form_mapping.py
```

Le premier audit verifie que les formulaires `ep` et `asst` sont coherents avec :

- les colonnes physiques existantes ;
- les types physiques ;
- `attribut_config_mobile` ;
- `liste_choix`.

Le deuxieme audit verifie le mapping mobile, les fallbacks et les listes de choix utilisees par l'application.

## Cas autorises

- Changer l'ordre ou la visibilite d'un champ : `attribut_config_mobile`.
- Changer le titre mobile d'un champ : `attribut_config_mobile`.
- Ajouter ou cacher un choix : `liste_choix`.
- Definir une valeur par defaut pour un champ avec liste : la valeur doit exister comme `liste_choix_valeur` active pour ce champ.
- Cacher une table du mobile : `formulaire_config_mobile.visible=false`.
- Empecher son export offline : `formulaire_config_mobile.download_mobile=false`.
- Ajouter une colonne EP/ASST nullable, non PK, non FK, non geometry, type whitelist : `attribut_config_mobile`, puis trigger safe-auto.
- Elargir `varchar(n)`, passer `varchar(n)` vers `text`, `integer` vers `bigint`, ou rendre une colonne nullable : `attribut_config_mobile`, puis trigger safe-auto.

## Cas interdits sans validation explicite

- `ALTER TABLE ep.*`
- `ALTER TABLE asst.*`
- `DROP COLUMN` ou `ADD COLUMN` dans `ep` ou `asst`
- Changer le type physique d'une colonne `ep` ou `asst`
- Reduire un type, convertir `text` vers nombre/date/boolean, rendre une colonne `NOT NULL`, changer une geometry, creer une FK physique, ou renommer une colonne physique via la config.

Si un changement physique est vraiment necessaire, il doit etre accompagne dans le meme lot par la mise a jour de `attribut_config_mobile`, de `liste_choix` si necessaire, des fallbacks mobile, et des rapports d'audit.

## Trigger safe-auto

- Source : `public.attribut_config_mobile`.
- Cibles : schemas `ep` et `asst` seulement.
- Tables admises : uniquement celles declarees dans `public.formulaire_config_mobile`.
- Colonnes protegees : `geom`, `fid`, `id`, colonnes sync et colonnes systeme.
- Journal : `public.srm_config_schema_ddl_log`.
- Les changements non-safe sont refuses et la modification de config est annulee, pour eviter une divergence entre config et schema reel.
- `public.liste_choix` ne genere aucun DDL physique.

## Garde-fou valeurs par defaut / listes

Le trigger PostgreSQL `trg_srm_attribut_config_choice_default_guard` verifie la coherence formulaire entre `public.attribut_config_mobile.valeur_par_defaut` et `public.liste_choix`.

- Si un champ a une valeur par defaut non vide et des choix actifs, cette valeur doit exister dans `liste_choix_valeur`.
- On ne peut pas inserer, modifier, desactiver ou supprimer des choix actifs de facon a exclure la valeur par defaut existante.
- Les listes optionnelles sans valeur par defaut restent autorisees : on ne cree pas de defaut artificiel juste pour satisfaire une contrainte technique.
- La contrainte est differable : un import peut mettre a jour la valeur par defaut et les choix dans la meme transaction, puis la validation se fait a la fin.

## Piste d'amelioration prioritaire

Quand les tables de configuration seront branchees cote bureau pour les responsables metier, ajouter une previsualisation d'impact avant validation des changements structurels de `attribut_config_mobile`.

Cette previsualisation doit afficher si le changement sera applique automatiquement par le trigger safe-auto ou s'il sera bloque, avec le SQL prevu, la raison du blocage et la table concernee. Le but est d'eviter qu'un responsable metier decouvre un refus seulement apres l'enregistrement, et de garder la configuration metier simple sans transformer l'interface bureau en outil DDL direct.

Endpoint disponible pour l'interface bureau :

```http
POST /api/attribut-config-mobile/schema-preview/
```

Le payload accepte `operation` (`INSERT`, `UPDATE`, `DELETE`), `id` pour recuperer l'ancienne ligne, et `new` pour la nouvelle valeur de configuration. Pour `UPDATE`, `new` peut contenir seulement les champs modifies : l'API fusionne avec la ligne actuelle avant de calculer l'impact. La reponse indique `blocked`, `will_apply`, `reason` et `steps` avec le SQL safe-auto prevu.
