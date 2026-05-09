from django.db import migrations, models


UNUSED_MODEL_NAMES = [
    'InterventionLog',
    'EpVanne',
    'EpVanneDeVidange',
    'EpVentouse',
    'EpHydrant',
    'EpBorneFontaine',
    'EpBorneOnep',
    'EpBoucheCles',
    'EpBoucheDarrosage',
    'EpCompteurAbonne',
    'EpCompteurReseau',
    'EpConeDeReduction',
    'EpCentreTampon',
    'EpNoeud',
    'EpObturateur',
    'EpReducteurDePression',
    'EpForage',
    'EpPuit',
    'EpPompe',
    'EpReservoir',
    'EpStationDePompage',
    'EpRegardMiroir',
    'EpRegardEp',
    'EpAutreObjet',
    'EpConduiteTerrain',
    'EpConduiteBureau',
    'EpBranchement',
    'EpTraverse',
    'AssRegardBranchement',
    'AssCanalisation',
    'AssCanalisationReutilisation',
    'AssBranchement',
    'AssBassin',
    'AssOuvrage',
    'AssEquipement',
    'AssStation',
    'ElecSupport',
    'ElecPoste',
    'ElecCoffretBt',
    'ElecNoeudRaccord',
    'ElecPointDesserte',
    'ElecTransformateur',
    'ElecCellule',
    'ElecDepartBt',
    'ElecDepartHta',
    'ElecTronconBt',
    'ElecTronconHta',
]


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0039_complete_history_audit_coverage'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.CreateModel(
                    name='ListeChoix',
                    fields=[
                        ('id', models.AutoField(primary_key=True, serialize=False)),
                        ('attribut_config_mobile_id', models.IntegerField()),
                        ('nom_metier', models.CharField(max_length=50)),
                        ('nom_table', models.CharField(max_length=100)),
                        ('nom_champ', models.CharField(max_length=100)),
                        ('liste_choix_alias', models.CharField(blank=True, max_length=255, null=True)),
                        ('liste_choix_valeur', models.CharField(blank=True, max_length=255, null=True)),
                        ('liste_choix_ordre', models.IntegerField(blank=True, null=True)),
                        ('liste_choix_actif', models.BooleanField(blank=True, null=True)),
                        ('contraintes', models.TextField(blank=True, null=True)),
                    ],
                    options={
                        'db_table': 'liste_choix',
                        'managed': False,
                    },
                ),
            ] + [
                migrations.DeleteModel(name=model_name)
                for model_name in UNUSED_MODEL_NAMES
            ],
            database_operations=[],
        ),
    ]
