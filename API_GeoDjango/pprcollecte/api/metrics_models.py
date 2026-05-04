from django.contrib.gis.db import models


class MetricAggregateBase(models.Model):
    id_agent = models.IntegerField(null=True, blank=True)
    nom_schema = models.CharField(max_length=30, null=True, blank=True)
    nom_table = models.CharField(max_length=100, null=True, blank=True)
    metier = models.CharField(max_length=10, null=True, blank=True)
    type_geometrie = models.CharField(max_length=30, null=True, blank=True)
    famille_geometrie = models.CharField(max_length=20, null=True, blank=True)
    nb_objets_crees = models.BigIntegerField(null=True, blank=True)
    nb_objets_anomalie = models.BigIntegerField(null=True, blank=True)
    nb_objets_avec_photo = models.BigIntegerField(null=True, blank=True)
    nb_photos_renseignees = models.BigIntegerField(null=True, blank=True)
    nb_photos_uploadees = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_signales = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_completes = models.BigIntegerField(null=True, blank=True)
    nb_modifications_terrain = models.BigIntegerField(null=True, blank=True)
    nb_validations_terrain = models.BigIntegerField(null=True, blank=True)
    nb_corrections_backoffice = models.BigIntegerField(null=True, blank=True)
    nb_corrections_superviseur = models.BigIntegerField(null=True, blank=True)
    nb_reouvertures = models.BigIntegerField(null=True, blank=True)
    nb_evenements_mobiles = models.BigIntegerField(null=True, blank=True)
    nb_attributs_mobiles = models.BigIntegerField(null=True, blank=True)
    nb_sessions_login = models.BigIntegerField(null=True, blank=True)
    nb_sessions_logout = models.BigIntegerField(null=True, blank=True)
    nb_evenements_sync = models.BigIntegerField(null=True, blank=True)

    class Meta:
        abstract = True


class MetricAgentJour(MetricAggregateBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    jour = models.DateField()

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_jour'


class MetricAgentSemaine(MetricAggregateBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    semaine_debut = models.DateField()
    semaine_fin = models.DateField()
    annee_iso = models.IntegerField()
    semaine_iso = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_semaine'


class MetricAgentMois(MetricAggregateBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    mois = models.DateField()
    annee = models.IntegerField()
    mois_numero = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_mois'


class MetricAgentTablePeriod(MetricAggregateBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    grain = models.CharField(max_length=10)
    periode_debut = models.DateField()
    periode_fin = models.DateField()
    annee = models.IntegerField(null=True, blank=True)
    mois_numero = models.IntegerField(null=True, blank=True)
    annee_iso = models.IntegerField(null=True, blank=True)
    semaine_iso = models.IntegerField(null=True, blank=True)
    nb_interventions_signalees = models.BigIntegerField(null=True, blank=True)
    nb_interventions_terrain_traitees = models.BigIntegerField(null=True, blank=True)
    nb_interventions_cloturees = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_table_period'


class MetricPublicBase(models.Model):
    nb_objets_crees = models.BigIntegerField(null=True, blank=True)
    nb_points = models.BigIntegerField(null=True, blank=True)
    nb_lignes = models.BigIntegerField(null=True, blank=True)
    nb_surfaces = models.BigIntegerField(null=True, blank=True)
    nb_objets_anomalie = models.BigIntegerField(null=True, blank=True)
    taux_anomalie_pct = models.FloatField(null=True, blank=True)
    nb_objets_avec_photo = models.BigIntegerField(null=True, blank=True)
    taux_objets_avec_photo_pct = models.FloatField(null=True, blank=True)
    nb_photos_renseignees = models.BigIntegerField(null=True, blank=True)
    nb_photos_uploadees = models.BigIntegerField(null=True, blank=True)
    moyenne_photos_par_objet = models.FloatField(null=True, blank=True)
    nb_objets_incomplets_signales = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_completes = models.BigIntegerField(null=True, blank=True)
    solde_incomplets = models.BigIntegerField(null=True, blank=True)
    nb_modifications_terrain = models.BigIntegerField(null=True, blank=True)
    nb_validations_terrain = models.BigIntegerField(null=True, blank=True)
    nb_corrections_backoffice = models.BigIntegerField(null=True, blank=True)
    nb_corrections_superviseur = models.BigIntegerField(null=True, blank=True)
    nb_reouvertures = models.BigIntegerField(null=True, blank=True)
    nb_evenements_mobiles = models.BigIntegerField(null=True, blank=True)
    nb_attributs_mobiles = models.BigIntegerField(null=True, blank=True)
    nb_sessions_login = models.BigIntegerField(null=True, blank=True)
    nb_sessions_logout = models.BigIntegerField(null=True, blank=True)
    nb_evenements_sync = models.BigIntegerField(null=True, blank=True)
    objets_par_heure = models.FloatField(null=True, blank=True)
    actif = models.BooleanField(null=True, blank=True)
    nb_jours_actifs = models.BigIntegerField(null=True, blank=True)

    class Meta:
        abstract = True


class MetricAgentPublicJour(MetricPublicBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    jour = models.DateField()
    id_agent = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_public_jour'


class MetricAgentPublicSemaine(MetricPublicBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    semaine_debut = models.DateField()
    semaine_fin = models.DateField()
    annee_iso = models.IntegerField()
    semaine_iso = models.IntegerField()
    id_agent = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_public_semaine'


class MetricAgentPublicMois(MetricPublicBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    mois = models.DateField()
    annee = models.IntegerField()
    mois_numero = models.IntegerField()
    id_agent = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_public_mois'


class MetricAgentPeriod(MetricPublicBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    grain = models.CharField(max_length=10)
    periode_debut = models.DateField()
    periode_fin = models.DateField()
    annee = models.IntegerField(null=True, blank=True)
    mois_numero = models.IntegerField(null=True, blank=True)
    annee_iso = models.IntegerField(null=True, blank=True)
    semaine_iso = models.IntegerField(null=True, blank=True)
    id_agent = models.IntegerField(null=True, blank=True)
    nb_interventions_signalees = models.BigIntegerField(null=True, blank=True)
    nb_interventions_terrain_traitees = models.BigIntegerField(null=True, blank=True)
    nb_interventions_cloturees = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_period'


class MetricAgentPublicResume(models.Model):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    id_agent = models.IntegerField(null=True, blank=True)
    premiere_activite = models.DateField(null=True, blank=True)
    derniere_activite = models.DateField(null=True, blank=True)
    nb_jours_actifs = models.BigIntegerField(null=True, blank=True)
    nb_objets_crees_total = models.BigIntegerField(null=True, blank=True)
    nb_points_total = models.BigIntegerField(null=True, blank=True)
    nb_lignes_total = models.BigIntegerField(null=True, blank=True)
    nb_surfaces_total = models.BigIntegerField(null=True, blank=True)
    nb_objets_anomalie_total = models.BigIntegerField(null=True, blank=True)
    taux_anomalie_global_pct = models.FloatField(null=True, blank=True)
    nb_objets_avec_photo_total = models.BigIntegerField(null=True, blank=True)
    nb_photos_renseignees_total = models.BigIntegerField(null=True, blank=True)
    nb_photos_uploadees_total = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_signales_total = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_completes_total = models.BigIntegerField(null=True, blank=True)
    nb_modifications_terrain_total = models.BigIntegerField(null=True, blank=True)
    nb_validations_terrain_total = models.BigIntegerField(null=True, blank=True)
    nb_corrections_backoffice_total = models.BigIntegerField(null=True, blank=True)
    nb_corrections_superviseur_total = models.BigIntegerField(null=True, blank=True)
    nb_reouvertures_total = models.BigIntegerField(null=True, blank=True)
    nb_evenements_sync_total = models.BigIntegerField(null=True, blank=True)
    objets_par_heure_global = models.FloatField(null=True, blank=True)
    nb_objets_7j = models.BigIntegerField(null=True, blank=True)
    nb_objets_30j = models.BigIntegerField(null=True, blank=True)
    nb_objets_mois_courant = models.BigIntegerField(null=True, blank=True)
    nb_objets_semaine_courante = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_public_resume'


class MetricAgentResume(models.Model):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    id_agent = models.IntegerField(null=True, blank=True)
    premiere_activite = models.DateField(null=True, blank=True)
    derniere_activite = models.DateField(null=True, blank=True)
    nb_jours_actifs = models.BigIntegerField(null=True, blank=True)
    nb_objets_crees_total = models.BigIntegerField(null=True, blank=True)
    nb_points_total = models.BigIntegerField(null=True, blank=True)
    nb_lignes_total = models.BigIntegerField(null=True, blank=True)
    nb_surfaces_total = models.BigIntegerField(null=True, blank=True)
    nb_objets_anomalie_total = models.BigIntegerField(null=True, blank=True)
    taux_anomalie_global_pct = models.FloatField(null=True, blank=True)
    nb_objets_avec_photo_total = models.BigIntegerField(null=True, blank=True)
    nb_photos_renseignees_total = models.BigIntegerField(null=True, blank=True)
    nb_photos_uploadees_total = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_signales_total = models.BigIntegerField(null=True, blank=True)
    nb_objets_incomplets_completes_total = models.BigIntegerField(null=True, blank=True)
    nb_modifications_terrain_total = models.BigIntegerField(null=True, blank=True)
    nb_validations_terrain_total = models.BigIntegerField(null=True, blank=True)
    nb_corrections_backoffice_total = models.BigIntegerField(null=True, blank=True)
    nb_corrections_superviseur_total = models.BigIntegerField(null=True, blank=True)
    nb_reouvertures_total = models.BigIntegerField(null=True, blank=True)
    nb_evenements_sync_total = models.BigIntegerField(null=True, blank=True)
    nb_interventions_signalees_total = models.BigIntegerField(null=True, blank=True)
    nb_interventions_terrain_traitees_total = models.BigIntegerField(null=True, blank=True)
    nb_interventions_cloturees_total = models.BigIntegerField(null=True, blank=True)
    objets_par_heure_global = models.FloatField(null=True, blank=True)
    nb_objets_7j = models.BigIntegerField(null=True, blank=True)
    nb_objets_30j = models.BigIntegerField(null=True, blank=True)
    nb_objets_mois_courant = models.BigIntegerField(null=True, blank=True)
    nb_objets_semaine_courante = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_resume'
