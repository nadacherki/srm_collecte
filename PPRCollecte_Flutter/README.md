# SRM Collecte — Application Mobile

Application mobile Flutter de collecte de données géospatiales pour les réseaux d'eau potable (EP) et d'assainissement (ASS).

## Architecture

```
SRM Collecte (Flutter/Dart)
    ├── API Backend (Django/GeoDjango)
    │     └── PostgreSQL/PostGIS (EPSG:26191 Merchich Nord)
    └── SQLite locale (mode offline)
```

## Métiers couverts

| Métier | Schéma BD | Exemples d'objets |
|--------|-----------|-------------------|
| Eau Potable | `ep` | Vanne, Conduite, Regard, Réservoir, Borne fontaine |
| Assainissement | `ass` | Regard, Canalisation, Bassin, Station |

## Fonctionnalités clés

- **Collecte GNSS** : coordonnées précises via mock location (récepteur GNSS externe)
- **Double affichage** : position WGS84 sur carte + coordonnées X/Y Merchich Nord
- **3 types de géométrie** : Points, Lignes (conduites/canalisations), Polygones
- **Photos** : 1 à 4 photos par objet collecté
- **Anomalies** : signalement avec type
- **Mode offline** : stockage SQLite avec synchronisation différée
- **Affectation par zones** : la collecte et les fonds de plan suivent les zones affectées aux agents

## Prérequis

- Flutter SDK >= 3.4.1
- Android Studio (émulateur API 34+)
- PostgreSQL + PostGIS (base SRM restaurée)
- Python >= 3.10 + Django/GeoDjango (backend)

## Installation

```bash
cd PPRCollecte_Flutter
flutter clean
flutter pub get
flutter run
```

## Structure du code

```
lib/
├── main.dart                          # Point d'entrée
├── core/
│   ├── config/srm_config.dart         # Configuration EP/ASS
│   └── constants/
│       ├── app_constants.dart          # Constantes globales
│       └── projection_constants.dart   # Paramètres EPSG:26191
├── data/
│   ├── local/database_helper.dart      # SQLite offline
│   └── remote/api_service.dart         # Communication API REST
├── models/                             # Modèles de données
├── screens/                            # Écrans (auth, home, forms, data)
├── services/                           # Services métier (GPS, sync, projection)
└── widgets/                            # Composants UI réutilisables
```

## Base de données

La base PostGIS utilise 3 schémas principaux :
- `public` : utilisateur, commune, zone, zone_utilisateur, synchronisation
- `ep` : 27 tables eau potable
- `ass` : 9 tables assainissement

Toutes les géométries sont en **EPSG:26191 (Merchich Nord)**.
