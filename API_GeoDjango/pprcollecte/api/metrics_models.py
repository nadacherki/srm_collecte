from django.contrib.gis.db import models


class MetricAggregateBase(models.Model):
    id_agent = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
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


class MetricPublicBase(models.Model):
    id_projet = models.IntegerField(null=True, blank=True)
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
    nb_missions = models.BigIntegerField(null=True, blank=True)
    nb_missions_cloturees = models.BigIntegerField(null=True, blank=True)
    duree_mission_heures = models.FloatField(null=True, blank=True)
    objets_par_mission = models.FloatField(null=True, blank=True)
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


class MetricAgentPublicResume(models.Model):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    id_agent = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
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
    nb_missions_total = models.BigIntegerField(null=True, blank=True)
    nb_missions_cloturees_total = models.BigIntegerField(null=True, blank=True)
    duree_mission_heures_total = models.FloatField(null=True, blank=True)
    objets_par_mission_global = models.FloatField(null=True, blank=True)
    objets_par_heure_global = models.FloatField(null=True, blank=True)
    nb_objets_7j = models.BigIntegerField(null=True, blank=True)
    nb_objets_30j = models.BigIntegerField(null=True, blank=True)
    nb_objets_mois_courant = models.BigIntegerField(null=True, blank=True)
    nb_objets_semaine_courante = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_agent_public_resume'


class MetricProjetBase(models.Model):
    id_projet = models.IntegerField(null=True, blank=True)
    nb_agents_actifs = models.BigIntegerField(null=True, blank=True)
    nb_objets_crees = models.BigIntegerField(null=True, blank=True)
    nb_points = models.BigIntegerField(null=True, blank=True)
    nb_lignes = models.BigIntegerField(null=True, blank=True)
    nb_surfaces = models.BigIntegerField(null=True, blank=True)
    nb_objets_anomalie = models.BigIntegerField(null=True, blank=True)
    taux_anomalie_pct = models.FloatField(null=True, blank=True)
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
    nb_evenements_sync = models.BigIntegerField(null=True, blank=True)
    nb_missions = models.BigIntegerField(null=True, blank=True)
    nb_missions_cloturees = models.BigIntegerField(null=True, blank=True)
    duree_mission_heures = models.FloatField(null=True, blank=True)
    objets_par_mission = models.FloatField(null=True, blank=True)
    objets_par_heure = models.FloatField(null=True, blank=True)
    moyenne_objets_par_agent_actif = models.FloatField(null=True, blank=True)
    actif = models.BooleanField(null=True, blank=True)
    nb_jours_actifs = models.BigIntegerField(null=True, blank=True)

    class Meta:
        abstract = True


class MetricProjetJour(MetricProjetBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    jour = models.DateField()
    taux_objets_avec_photo_pct = models.FloatField(null=True, blank=True)
    moyenne_photos_par_objet = models.FloatField(null=True, blank=True)
    solde_incomplets = models.BigIntegerField(null=True, blank=True)
    nb_evenements_mobiles = models.BigIntegerField(null=True, blank=True)
    nb_attributs_mobiles = models.BigIntegerField(null=True, blank=True)
    nb_sessions_login = models.BigIntegerField(null=True, blank=True)
    nb_sessions_logout = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_projet_jour'


class MetricProjetSemaine(MetricProjetBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    semaine_debut = models.DateField()
    semaine_fin = models.DateField()
    annee_iso = models.IntegerField()
    semaine_iso = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'vw_metrics_projet_semaine'


class MetricProjetMois(MetricProjetBase):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    mois = models.DateField()
    annee = models.IntegerField()
    mois_numero = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'vw_metrics_projet_mois'


class MetricProjetResume(models.Model):
    metric_uid = models.CharField(max_length=32, primary_key=True)
    id_projet = models.IntegerField(null=True, blank=True)
    premiere_activite = models.DateField(null=True, blank=True)
    derniere_activite = models.DateField(null=True, blank=True)
    nb_jours_actifs = models.BigIntegerField(null=True, blank=True)
    nb_agents_actifs = models.BigIntegerField(null=True, blank=True)
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
    nb_missions_total = models.BigIntegerField(null=True, blank=True)
    nb_missions_cloturees_total = models.BigIntegerField(null=True, blank=True)
    duree_mission_heures_total = models.FloatField(null=True, blank=True)
    objets_par_mission_global = models.FloatField(null=True, blank=True)
    objets_par_heure_global = models.FloatField(null=True, blank=True)
    moyenne_objets_par_agent_actif = models.FloatField(null=True, blank=True)
    nb_objets_7j = models.BigIntegerField(null=True, blank=True)
    nb_objets_30j = models.BigIntegerField(null=True, blank=True)
    nb_objets_mois_courant = models.BigIntegerField(null=True, blank=True)
    nb_objets_semaine_courante = models.BigIntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'vw_metrics_projet_resume'
