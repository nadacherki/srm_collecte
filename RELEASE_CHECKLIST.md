# SRM Collecte — Checklist de mise en production

Guide opérationnel à dérouler **dans l'ordre** avant chaque go-live.
Le code (sécurité P0/P1/P2 + conteneurisation B1–B6/M1) est déjà en place ;
ce qui suit = les actions humaines/infra non automatisables.

Légende : ☐ à faire · ⚠️ secret/irréversible · ✅ vérification

---

## 0. Pré-requis serveur

- ☐ VM Linux (2 vCPU / 4 Go mini), Docker + Docker Compose v2 installés
- ☐ Nom de domaine prod (ex. `api.srm.ma`) avec un enregistrement **DNS A**
  pointant vers l'IP publique du serveur (nécessaire pour le certificat
  TLS automatique de Caddy)
- ☐ Ports `80` et `443` ouverts en entrée (Let's Encrypt + trafic mobile)
- ☐ Accès au PostgreSQL/PostGIS de prod (conteneur de la stack, ou managé)

---

## 1. Keystore de signature Android ⚠️

À faire **une seule fois**. La perte du keystore = impossible de publier
une mise à jour de l'app (Play Store comme sideload).

```bash
cd PPRCollecte_Flutter/android
keytool -genkey -v -keystore srm-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias srm
# Renseigner CN, organisation, etc. Noter le mot de passe.
```

- ☐ Créer `PPRCollecte_Flutter/android/key.properties` depuis
  `key.properties.example` :

```properties
storeFile=../srm-release.jks
storePassword=<mot_de_passe_store>
keyAlias=srm
keyPassword=<mot_de_passe_cle>
```

- ⚠️ **Sauvegarder `srm-release.jks` + les mots de passe** dans un coffre
  (gestionnaire de secrets / KeePass hors dépôt). Vérifier qu'ils sont
  gitignorés :

```bash
git check-ignore PPRCollecte_Flutter/android/srm-release.jks \
                  PPRCollecte_Flutter/android/key.properties
# Doit afficher les deux chemins (= ignorés). Sinon STOP.
```

---

## 2. Configuration backend (`.env` prod) ⚠️

```bash
cd API_GeoDjango/pprcollecte
cp .env.example .env
```

Renseigner dans `.env` :

- ☐ `DJANGO_DEBUG=False`
- ☐ `DJANGO_SECRET_KEY=` → générer :
  `python -c "import secrets; print(secrets.token_urlsafe(50))"`
- ☐ `DJANGO_ALLOWED_HOSTS=api.srm.ma` (le domaine prod, sans wildcard)
- ☐ `DB_NAME` / `DB_USER` / `DB_PASSWORD` (mot de passe fort)
- ☐ `REDIS_URL=redis://redis:6379/1` (obligatoire en prod)
- ☐ `SRM_DOMAIN=api.srm.ma` (utilisé par Caddy pour le certificat)
- ☐ `SENTRY_DSN=` (recommandé) + `SENTRY_ENV=production`
- ☐ `DJANGO_ADMINS=Nom:mail@exemple.ma` + bloc `EMAIL_*` si SMTP dispo
- ☐ `GUNICORN_WORKERS=3` (≈ 2×vCPU+1), `GUNICORN_TIMEOUT=60`

⚠️ `.env` ne doit JAMAIS être commité — vérifier :
`git check-ignore API_GeoDjango/pprcollecte/.env`

✅ Garde-fous intégrés : le boot **échoue** si `DEBUG=False` avec la
SECRET_KEY de dev, ou sans `REDIS_URL`. C'est voulu.

---

## 3. Backup base de données ⚠️

À faire **juste avant** la bascule (le dernier backup date d'avant les
travaux sécurité).

```bash
cd API_GeoDjango
TS=$(date +%Y%m%d_%H%M%S)
pg_dump -h <db_host> -U <db_user> -d SRM_bureau \
  --no-owner --no-privileges -f "../backups/SRM_bureau_preprod_${TS}.sql"
```

- ☐ Backup créé et **copié hors serveur** (taille cohérente, ~70 Mo)
- ☐ Test de restauration sur une base jetable (au moins 1 fois) :

```bash
createdb -h <db_host> -U <db_user> SRM_restore_test
psql -h <db_host> -U <db_user> -d SRM_restore_test \
  -f ../backups/SRM_bureau_preprod_${TS}.sql
dropdb -h <db_host> -U <db_user> SRM_restore_test
```

---

## 4. Déploiement de la stack backend

```bash
cd API_GeoDjango
docker compose build
docker compose up -d
docker compose ps          # db, redis, web, caddy = healthy
docker compose logs -f web # migrate + collectstatic OK, gunicorn up
```

✅ Vérifications :

- ☐ `docker compose ps` : 4 services `healthy`
- ☐ Certificat TLS émis :
  `curl -sI https://api.srm.ma/api/login/ | head -1` → réponse HTTPS
- ☐ Login fonctionne (renvoie un JWT) :

```bash
curl -s -X POST https://api.srm.ma/api/login/ \
  -H "Content-Type: application/json" \
  -d '{"login":"<agent>","mot_de_passe":"<mdp>"}' | head -c 300
# Doit contenir "auth":{"access":...,"refresh":...}
```

- ☐ Anonyme refusé (fail-closed) :
  `curl -s -o /dev/null -w "%{http_code}" https://api.srm.ma/api/ep/regards/`
  → **401**
- ☐ Headers sécurité présents :
  `curl -sI https://api.srm.ma/api/login/ | grep -i \
   "strict-transport\|content-security\|x-frame\|x-content-type"`
- ☐ Rate-limit login actif (≥ 11 requêtes/min → `429`)

---

## 5. Build APK de production

Depuis un poste avec Flutter + le keystore (étape 1) :

```bash
cd PPRCollecte_Flutter
flutter clean && flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.srm.ma \
  --obfuscate --split-debug-info=build/symbols
```

- ☐ APK généré : `build/app/outputs/flutter-apk/SRM_Collecte-release.apk`
- ⚠️ Conserver `build/symbols/` (dé-obfuscation des crashes Sentry/Play)
- ✅ Garde-fous : sans `key.properties` le build avertit et reste en
  signature debug (NE PAS distribuer) ; sans `API_BASE_URL` HTTPS l'app
  lève `StateError` au démarrage (fail-fast).

✅ Vérifications APK :

- ☐ Signature release (pas debug) :
  `keytool -printcert -jarfile SRM_Collecte-release.apk` → CN = celui du
  keystore SRM, pas « Android Debug »
- ☐ `ACCESS_MOCK_LOCATION` **absente** du release :
  `aapt dump permissions SRM_Collecte-release.apk | grep -i mock`
  → aucune sortie
- ☐ Installer sur un device propre, se connecter, télécharger une zone,
  saisir + synchroniser un objet, vérifier la photo.

---

## 6. Durcissement réseau mobile (optionnel mais recommandé)

Pour fermer totalement le HTTP en distribution :

- ☐ Dans
  `PPRCollecte_Flutter/android/app/src/main/res/xml/network_security_config.xml`,
  retirer le bloc `<domain-config cleartextTrafficPermitted="true">`
  (10.0.2.2/localhost/127.0.0.1) — il n'est utile qu'en dev émulateur.
- ☐ Rebuild l'APK (étape 5) et re-tester.

---

## 7. Post-déploiement

- ☐ Sentry reçoit bien un événement test (déclencher une 500 contrôlée
  ou `sentry_sdk.capture_message` en staging)
- ☐ Sauvegarde DB planifiée (cron `pg_dump` quotidien + rétention)
- ☐ Rotation/monitoring des logs `docker compose logs` (volume, espace)
- ☐ Procédure de rollback documentée : `git revert` + redeploy + restore
  backup étape 3 (⚠️ migrations 0054–0057 sont `reverse=noop` → le
  rollback DB se fait par **restauration de backup**, pas par
  `migrate` arrière)
- ☐ Rotation du `DB_PASSWORD` historique (présent en clair dans les
  anciens `.env` locaux et l'historique de travail)
- ☐ Incrémenter `flutter.versionCode` / `versionName` (local.properties /
  pubspec) à chaque nouvelle release

---

## Récapitulatif Go / No-Go

| Bloquant | Statut requis |
|---|---|
| Keystore release + `key.properties` | ☐ présent, sauvegardé |
| `.env` prod (DEBUG=False, SECRET_KEY, ALLOWED_HOSTS, Redis) | ☐ rempli |
| Backup DB frais + restauration testée | ☐ OK |
| Stack `docker compose` 4 services healthy + TLS | ☐ OK |
| APK release signé, sans mock-location, HTTPS | ☐ OK |
| Anonyme = 401, rate-limit = 429, headers présents | ☐ OK |
| Sentry/alerting opérationnel | ☐ OK |

**Go** uniquement si toutes les lignes sont cochées.
