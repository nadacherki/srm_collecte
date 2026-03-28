# SRM Collecte — Application Mobile

Application mobile Flutter de collecte de données géospatiales pour les réseaux d'eau potable (EP), d'assainissement (ASS) et d'électricité (ELEC).

## Architecture

```
SRM Collecte (Flutter/Dart)
    ├── API Backend (Django/GeoDjango)
    │     └── PostgreSQL/PostGIS (EPSG:26191 Merchich Nord)
    └── SQLite locale (mode offline)
```

## Métiers couverts

| Métier | Schéma BD | Nb tables | Exemples d'objets |
|--------|-----------|-----------|-------------------|
| Eau Potable | `ep` | 27 | Vanne, Conduite, Regard, Réservoir, Borne fontaine |
| Assainissement | `ass` | 9 | Regard, Canalisation, Bassin, Station |
| Électricité | `elec` | 11 | Support, Poste, Coffret BT, Tronçon HTA |

## Fonctionnalités clés

- **Collecte GNSS** : coordonnées précises via mock location (récepteur GNSS externe)
- **Double affichage** : position WGS84 sur carte + coordonnées X/Y Merchich Nord
- **3 types de géométrie** : Points, Lignes (conduites/canalisations/tronçons), Polygones (planches)
- **Photos** : 1 à 4 photos par objet collecté
- **Anomalies** : signalement avec type
- **Mode offline** : stockage SQLite avec synchronisation différée
- **Gestion par projet/mission** : chaque collecte est liée à un projet et une mission

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
│   ├── config/srm_config.dart         # Configuration EP/ASS/ELEC (47 entités)
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

La base PostGIS utilise 4 schémas :
- `public` : utilisateur, projet, mission, commune
- `ep` : 27 tables eau potable
- `ass` : 9 tables assainissement
- `elec` : 11 tables électricité

Toutes les géométries sont en **EPSG:26191 (Merchich Nord)**.

## Adapté de

Ce projet est adapté de [GeoDNGR-Collecte](https://github.com/Ayoub101010/mobile) (collecte de pistes rurales en Guinée) pour les besoins du SRM Maroc.
