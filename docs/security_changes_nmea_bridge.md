# Pont NMEA - points de securite

- Permission Android ajoutee : `BLUETOOTH_SCAN` avec `neverForLocation` pour Android 12+.

- Impact : evite l'erreur runtime `Need android.permission.BLUETOOTH_SCAN permission` lors de `BluetoothAdapter.cancelDiscovery()` avant la connexion SPP.

- Auto-connexion ajoutee : apres selection manuelle initiale du recepteur GNSS, l'adresse Bluetooth est stockee dans `app_metadata`; a l'ouverture de la carte, l'app tente de reconnecter automatiquement le pont NMEA si SRM Collecte est deja selectionnee comme app de position fictive.

- Fallback terrain : si aucun choix n'est encore stocke et qu'un seul appareil appaire ressemble a `GNSS/Tersus/Oscar/NMEA`, il est memorise automatiquement et utilise pour lancer la connexion.

- Risque production : l'auto-connexion simplifie le terrain mais garde le meme perimetre de securite que le pont NMEA. La selection Android de l'application de position fictive reste une action systeme volontaire et doit etre geree pendant la preparation du telephone.

- Durcissement source GNSS : le recentrage NMEA consomme directement `bridge.lastLocation` uniquement si `source=nmea_bridge`.

- Impact : en mode NMEA attendu, l'app ne retombe plus silencieusement sur `LocationService.getLocation()` pour recentrer la carte.

- Diagnostic terrain : la barre de statut mobile affiche maintenant `Source: GNSS externe`, `Source: téléphone` ou `Source: mock interne`.

- Logs : chaque fix NMEA natif journalise `source=nmea_bridge`, le recepteur Bluetooth, `lat/lon`, la precision et le timestamp de reception NMEA.
