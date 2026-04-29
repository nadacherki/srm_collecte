# Journal des changements de sécurité - SRM Collecte

Dernière mise à jour : 2026-04-27 14:46 +01:00

Ce fichier trace les changements faits pour permettre les tests de l'APK mobile avec un serveur Django de développement lancé sur ce PC. Les éléments marqués "dev uniquement" doivent être revus avant une mise en production.

## Changements appliqués

- Django `ALLOWED_HOSTS` a été rendu configurable par la variable d'environnement `DJANGO_ALLOWED_HOSTS`.

- Valeur par défaut actuelle de développement : `ALLOWED_HOSTS = ['*']`.

- Impact : cela évite de rebuilder ou modifier Django à chaque changement d'adresse IP locale pendant les tests LAN.

- Risque production : `['*']` accepte tous les hôtes et ne doit pas être conservé en production.

- Action production attendue : définir `DJANGO_ALLOWED_HOSTS` avec les domaines/IP explicitement autorisés, par exemple `api.srm.example.ma,10.0.0.12`, et passer `DEBUG=False`.

- Flutter `ApiService.baseUrl` est maintenant configurable au build via `--dart-define=API_BASE_URL=...`.

- Valeur par défaut actuelle : `http://10.0.2.2:8000`, utile pour l'émulateur Android.

- Impact : un APK de test téléphone peut pointer vers l'IP LAN du PC, par exemple `http://192.168.10.100:8000`.

- Risque production : l'URL backend est choisie au build. Il faut s'assurer que l'APK de production pointe vers le backend officiel HTTPS.

- Action production attendue : builder avec une URL backend HTTPS stable et documenter l'environnement utilisé.

- Le bouton de mock GPS est restreint aux comptes `admin`.

- Impact : les agents ne voient plus l'outil de mock GPS dans l'application.

- Risque résiduel : c'est une protection côté client. Les règles métier sensibles doivent rester vérifiées côté serveur si elles deviennent critiques.

- Ajout d'une action admin `Lire GPS/GNSS`.

- Impact : l'admin peut forcer une lecture de la position Android réelle, couper le mock interne, recentrer la carte et afficher X/Y/Z.

- Risque production : faible, mais cet outil doit rester réservé aux administrateurs/diagnostic.

- Ajout d'un premier pont NMEA natif Android.

- Permissions ajoutées : `ACCESS_MOCK_LOCATION`, `BLUETOOTH_CONNECT`, ainsi que `BLUETOOTH`/`BLUETOOTH_ADMIN` limitées aux anciennes versions Android.

- Impact : SRM Collecte peut apparaître dans `Options développeur > Application de position fictive`, lire une trame NMEA `GGA/RMC`, injecter une position dans Android via `LocationManager`, et préparer une connexion Bluetooth SPP vers un Oscar déjà appairé.

- Risque production : `ACCESS_MOCK_LOCATION` et l'injection Android doivent être strictement encadrées. Cette capacité doit rester un mode GNSS contrôlé/diagnostic ou être remplacée par une lecture interne directe de la position Oscar si la politique production interdit les positions fictives Android.

- Action production attendue : décider si le mode `mock location provider` est autorisé en production terrain. Sinon, conserver le parsing NMEA mais alimenter directement le service GPS interne de SRM Collecte sans publier de mock location Android.

- `adb` a été ajouté au PATH utilisateur Windows.

- Chemin ajouté : `C:\Users\AnasDahou\AppData\Local\Android\Sdk\platform-tools`.

- Impact : permet les diagnostics téléphone depuis PowerShell.

- Risque production : aucun sur l'application, mais c'est une modification de l'environnement de développement Windows.

## Changement tenté mais non appliqué

- Ouverture Windows Firewall du port TCP `8000`.

- Tentative précédente : `netsh advfirewall firewall add rule ... localport=8000`.

- Résultat : refusé car la commande nécessite un PowerShell lancé en administrateur.

- Nouvelle tentative depuis Codex avec élévation/UAC : refusée par la couche de sécurité de l'agent, car l'ouverture persistante d'un port entrant affaiblit la sécurité de la machine.

- Statut : aucune règle firewall n'a été ajoutée par Codex.

- Alternative plus sûre pour test USB : utiliser `adb reverse tcp:8000 tcp:8000` et builder l'APK avec `API_BASE_URL=http://127.0.0.1:8000`. Cette option ne modifie pas Windows Firewall et ne fonctionne que lorsque le téléphone est connecté en USB avec le débogage activé.

- Test `adb reverse` effectué : tunnel actif `UsbFfs tcp:8000 tcp:8000`.

- Résultat : le port côté téléphone répond au test TCP local, mais Django ne répondait plus sur `127.0.0.1:8000` côté PC au moment du contrôle final. Il faut relancer le serveur Django avant de tester l'application.

## État réseau de test constaté

- PC sur Wi-Fi : `192.168.10.100`.

- Téléphone sur Wi-Fi : `192.168.10.144`.

- Django écoute sur `0.0.0.0:8000`.

- Le téléphone ping le PC, mais le test TCP vers `192.168.10.100:8000` a expiré avant ouverture firewall.

## Checklist avant production

- Remplacer `ALLOWED_HOSTS = ['*']` par des hôtes explicites via `DJANGO_ALLOWED_HOSTS`.

- Passer `DEBUG=False`.

- Utiliser HTTPS pour le backend de production.

- Vérifier que l'APK production est buildé avec l'URL backend officielle.

- Conserver le mock GPS invisible aux agents.

- Vérifier que les permissions Android déclarées correspondent uniquement aux besoins réels.

- Supprimer ou documenter toute règle firewall ouverte pour les tests locaux.
