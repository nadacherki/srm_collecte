"""
Modèles Django pour la base de données SIG SRM.

IMPORTANT : managed = False sur tous les modèles car les tables existent déjà
dans la base sig_srm. Django ne crée ni ne modifie les tables — il les lit.

Organisation :
  - Schéma public : Utilisateur, Projet, Mission, Commune, etc. (8 tables)
  - Schéma ep     : Eau Potable (27 tables)
  - Schéma ass    : Assainissement (9 tables)
  - Schéma elec   : Électricité (11 tables)

Toutes les géométries sont en EPSG:26191 (Merchich Nord).
"""

from django.contrib.gis.db import models

from .metrics_models import (
    MetricAgentJour,
    MetricAgentSemaine,
    MetricAgentMois,
    MetricAgentPublicJour,
    MetricAgentPublicSemaine,
    MetricAgentPublicMois,
    MetricAgentPublicResume,
    MetricProjetJour,
    MetricProjetSemaine,
    MetricProjetMois,
    MetricProjetResume,
)


class SrmTrackedModel(models.Model):
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True


# =====================================================================
#  SCHÉMA PUBLIC — Tables de gestion (8 tables)
# =====================================================================

class Utilisateur(models.Model):
    id_user = models.AutoField(primary_key=True)
    login = models.CharField(max_length=100, unique=True)
    mot_de_passe = models.CharField(max_length=255, null=True, blank=True)
    nom_prenom = models.CharField(max_length=200, null=True, blank=True)
    actif = models.BooleanField(default=True)
    date_creation = models.DateField(null=True, blank=True)
    dernier_login = models.DateTimeField(null=True, blank=True)
    nb_objets_collectes_total = models.IntegerField(default=0)
    id_projet_actif = models.IntegerField(null=True, blank=True)
    role = models.CharField(max_length=20, default='viewer_mobile')

    class Meta:
        managed = False
        db_table = 'utilisateur'

    def __str__(self):
        return f"{self.nom_prenom} ({self.login})"


class Projet(models.Model):
    id_projet = models.AutoField(primary_key=True)
    code_affaire = models.CharField(max_length=100)
    nom = models.CharField(max_length=200, null=True, blank=True)
    srm = models.CharField(max_length=100, null=True, blank=True)
    region = models.CharField(max_length=100, null=True, blank=True)
    date_debut = models.DateField(null=True, blank=True)
    date_fin = models.DateField(null=True, blank=True)
    statut = models.CharField(max_length=20, default='EN_PREPARATION')
    metier = models.CharField(max_length=10, null=True, blank=True)
    geom_zone = models.MultiPolygonField(srid=26191, dim=3,null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'projet'

    def __str__(self):
        return f"{self.nom} ({self.code_affaire})"


class Mission(models.Model):
    id_mission = models.AutoField(primary_key=True)
    id_agent = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    heure_debut = models.DateTimeField(null=True, blank=True)
    heure_fin = models.DateTimeField(null=True, blank=True)
    nb_objets_collectes = models.IntegerField(default=0)
    nb_objets_incomplets = models.IntegerField(default=0)
    nb_photos_prises = models.IntegerField(default=0)
    etat_mission = models.CharField(max_length=20, default='EN_COURS')
    date_debut = models.DateField(null=True, blank=True)
    date_fin = models.DateField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'mission'

    def __str__(self):
        return f"Mission {self.id_mission} (agent {self.id_agent})"


class Commune(models.Model):
    id_commune = models.AutoField(primary_key=True)
    nom_commune = models.CharField(max_length=100)
    nom_province = models.CharField(max_length=100, null=True, blank=True)
    nom_region = models.CharField(max_length=100, null=True, blank=True)
    geom = models.MultiPolygonField(srid=26191, dim=3,null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'commune'

    def __str__(self):
        return self.nom_commune


class HistoriqueAttribut(models.Model):
    id_historique = models.AutoField(primary_key=True)
    id_objet = models.IntegerField(null=True, blank=True)
    cle_ligne = models.CharField(max_length=254, null=True, blank=True)
    uuid_objet = models.CharField(max_length=254, null=True, blank=True)
    nom_schema = models.CharField(max_length=30, null=True, blank=True)
    nom_table = models.CharField(max_length=100, null=True, blank=True)
    nom_classe = models.CharField(max_length=100, null=True, blank=True)
    nom_attribut = models.CharField(max_length=100, null=True, blank=True)
    ancienne_valeur = models.TextField(null=True, blank=True)
    nouvelle_valeur = models.TextField(null=True, blank=True)
    date_action = models.DateTimeField(null=True, blank=True)
    id_agent = models.IntegerField(null=True, blank=True)
    type_action = models.CharField(max_length=50, null=True, blank=True)
    commentaire_correction = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'historique_attribut'


class HistoriqueMobile(models.Model):
    id_historique_mobile = models.BigAutoField(primary_key=True)
    sync_uuid = models.CharField(max_length=64, unique=True)
    type_entree = models.CharField(max_length=20)
    source_table_locale = models.CharField(max_length=64)
    source_id_local = models.BigIntegerField(null=True, blank=True)
    id_objet = models.IntegerField(null=True, blank=True)
    cle_ligne = models.CharField(max_length=254, null=True, blank=True)
    uuid_objet = models.CharField(max_length=254, null=True, blank=True)
    nom_schema = models.CharField(max_length=30, null=True, blank=True)
    nom_table = models.CharField(max_length=100, null=True, blank=True)
    nom_classe = models.CharField(max_length=100, null=True, blank=True)
    nom_attribut = models.CharField(max_length=100, null=True, blank=True)
    ancienne_valeur = models.TextField(null=True, blank=True)
    nouvelle_valeur = models.TextField(null=True, blank=True)
    type_action = models.CharField(max_length=50, null=True, blank=True)
    type_evenement = models.CharField(max_length=100, null=True, blank=True)
    payload_json = models.JSONField(null=True, blank=True)
    date_action = models.DateTimeField()
    date_reception = models.DateTimeField(null=True, blank=True)
    id_agent = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'historique_mobile'


class ObjetIncomplet(models.Model):
    id_incomplet = models.AutoField(primary_key=True)
    id_objet = models.IntegerField(null=True, blank=True)
    nom_classe = models.CharField(max_length=100, null=True, blank=True)
    metier = models.CharField(max_length=10, null=True, blank=True)
    raison = models.CharField(max_length=50, null=True, blank=True)
    detail_raison = models.TextField(null=True, blank=True)
    date_signalement = models.DateTimeField(null=True, blank=True)
    id_agent_signal = models.IntegerField(null=True, blank=True)
    statut = models.CharField(max_length=20, default='A_COMPLETER')
    date_planification = models.DateField(null=True, blank=True)
    id_agent_retour = models.IntegerField(null=True, blank=True)
    date_completion = models.DateTimeField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'objet_incomplet'


class ObjetPhoto(models.Model):
    id_photo = models.BigAutoField(primary_key=True)
    uuid_objet = models.CharField(max_length=254)
    nom_schema = models.CharField(max_length=20)
    nom_table = models.CharField(max_length=100)
    num_photo = models.SmallIntegerField()
    nom_fichier = models.CharField(max_length=255)
    chemin_relatif = models.TextField()
    hash_sha256 = models.CharField(max_length=64, null=True, blank=True)
    mime_type = models.CharField(max_length=100, null=True, blank=True)
    taille_octets = models.BigIntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    date_prise_reelle = models.DateTimeField(null=True, blank=True)
    date_upload = models.DateTimeField(null=True, blank=True)
    actif = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'objet_photo'

    def __str__(self):
        return f"{self.nom_schema}.{self.nom_table} {self.uuid_objet} photo {self.num_photo}"


class FondDePlan(models.Model):
    id_fdp = models.AutoField(primary_key=True)
    id_projet = models.IntegerField()
    nom = models.CharField(max_length=200, null=True, blank=True)
    type_source = models.CharField(max_length=50, null=True, blank=True)
    url_service = models.TextField(null=True, blank=True)
    date_maj = models.DateField(null=True, blank=True)
    actif = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'fond_de_plan'


class EvaluationAgent(models.Model):
    id_eval = models.AutoField(primary_key=True)
    id_agent = models.IntegerField(null=True, blank=True)
    periode = models.CharField(max_length=20, null=True, blank=True)
    nb_objets_collectes = models.IntegerField(default=0)
    nb_objets_corriges_bo = models.IntegerField(default=0)
    nb_objets_incomplets = models.IntegerField(default=0)
    taux_qualite = models.FloatField(null=True, blank=True)
    taux_completion = models.FloatField(null=True, blank=True)
    commentaire = models.TextField(null=True, blank=True)
    id_evaluateur = models.IntegerField(null=True, blank=True)
    date_evaluation = models.DateField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'evaluation_agent'


class StatistiqueConduite(models.Model):
    id_statistique_conduite = models.BigAutoField(primary_key=True)
    id_agent = models.IntegerField()
    jour = models.DateField()
    geom = models.MultiLineStringField(srid=26191, dim=3, null=True, blank=True)
    longueur_conduite_m = models.FloatField(default=0.0)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'statistique_conduite'

    def __str__(self):
        return f"Stat conduite agent={self.id_agent} jour={self.jour}"


class StatistiqueConduiteSegment(models.Model):
    id_statistique_conduite_segment = models.BigAutoField(primary_key=True)
    id_statistique_conduite = models.BigIntegerField()
    fid_regard_a = models.IntegerField()
    fid_regard_b = models.IntegerField()
    fid_regard_min = models.IntegerField()
    fid_regard_max = models.IntegerField()
    geom = models.LineStringField(srid=26191, dim=3)
    longueur_segment_m = models.FloatField(default=0.0)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'statistique_conduite_segment'

    def __str__(self):
        return (
            f"Segment conduite stat={self.id_statistique_conduite} "
            f"{self.fid_regard_min}-{self.fid_regard_max}"
        )


class SrmFieldOption(models.Model):
    id_option = models.BigAutoField(primary_key=True)
    table_schema = models.CharField(max_length=50)
    table_name = models.CharField(max_length=100)
    field_name = models.CharField(max_length=100)
    code_value = models.CharField(max_length=255)
    label_value = models.CharField(max_length=255)
    display_order = models.IntegerField(default=0)
    actif = models.BooleanField(default=True)
    created_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'srm_field_option'


class BasemapZone(models.Model):
    zone_id = models.CharField(primary_key=True, max_length=100)
    city_slug = models.CharField(max_length=100)
    nom = models.CharField(max_length=200)
    geom = models.MultiPolygonField(srid=4326, null=True, blank=True)
    bbox_west = models.FloatField()
    bbox_south = models.FloatField()
    bbox_east = models.FloatField()
    bbox_north = models.FloatField()
    center_latitude = models.FloatField()
    center_longitude = models.FloatField()
    min_zoom = models.IntegerField(default=11)
    max_zoom = models.IntegerField(default=19)
    actif = models.BooleanField(default=True)
    metadata_json = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'basemap_zone'


class BasemapPackage(models.Model):
    id_package = models.BigAutoField(primary_key=True)
    zone_id = models.CharField(max_length=100)
    city_slug = models.CharField(max_length=100)
    style = models.CharField(max_length=30)
    format = models.CharField(max_length=20)
    version = models.CharField(max_length=100)
    file_name = models.CharField(max_length=255)
    relative_path = models.TextField()
    size_bytes = models.BigIntegerField(null=True, blank=True)
    sha256 = models.CharField(max_length=64, null=True, blank=True)
    min_zoom = models.IntegerField(null=True, blank=True)
    max_zoom = models.IntegerField(null=True, blank=True)
    generated_at = models.DateTimeField(null=True, blank=True)
    source_name = models.CharField(max_length=255, null=True, blank=True)
    attribution = models.TextField(null=True, blank=True)
    tile_count = models.BigIntegerField(null=True, blank=True)
    metadata_json = models.JSONField(null=True, blank=True)
    actif = models.BooleanField(default=True)
    requires_wifi = models.BooleanField(default=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'basemap_package'


class AgentBasemapZone(models.Model):
    id_agent_basemap_zone = models.BigAutoField(primary_key=True)
    id_user = models.IntegerField()
    zone_id = models.CharField(max_length=100)
    actif = models.BooleanField(default=True)
    assigned_by = models.IntegerField(null=True, blank=True)
    assigned_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)
    metadata_json = models.JSONField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'agent_basemap_zone'
        unique_together = (('id_user', 'zone_id'),)


# =====================================================================
#  SCHÉMA EP — Eau Potable : PONCTUELS (tables 1 à 22)
# =====================================================================

class EpVanne(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_modele = models.CharField(max_length=254, null=True, blank=True)
    ep_marque = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_regard = models.CharField(max_length=254, null=True, blank=True)
    ep_sens_ferm = models.CharField(max_length=254, null=True, blank=True)
    ep_manoeuvre = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    ep_sectionnement = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."vanne"'

    def __str__(self):
        return f"Vanne {self.ep_num or self.fid}"


class EpVanneDeVidange(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_modele = models.CharField(max_length=254, null=True, blank=True)
    ep_marque = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."vanne_de_vidange"'

    def __str__(self):
        return f"Vanne de vidange {self.ep_num or self.fid}"


class EpVentouse(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_modele = models.CharField(max_length=254, null=True, blank=True)
    ep_marque = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_regard = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    ep_date_interv = models.DateField(null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."ventouse"'

    def __str__(self):
        return f"Ventouse {self.ep_num or self.fid}"


class EpHydrant(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."hydrant"'

    def __str__(self):
        return f"Hydrant {self.ep_num or self.fid}"


class EpBorneFontaine(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."borne_fontaine"'

    def __str__(self):
        return f"Borne fontaine {self.ep_num or self.fid}"


class EpBorneOnep(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    observation = models.TextField(null=True, blank=True)
    date_leve = models.DateField(null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."borne_onep"'

    def __str__(self):
        return f"Borne ONEP {self.fid}"


class EpBoucheCles(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    date_leve = models.DateField(null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_compteur_abonne = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."bouche_cles"'


class EpBoucheDarrosage(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_marque = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."bouche_darrosage"'


class EpCompteurAbonne(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    ref = models.CharField(max_length=254, null=True, blank=True)
    sect = models.CharField(max_length=254, null=True, blank=True)
    tour = models.CharField(max_length=254, null=True, blank=True)
    abon = models.CharField(max_length=254, null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    cin = models.CharField(max_length=254, null=True, blank=True)
    adresse = models.CharField(max_length=254, null=True, blank=True)
    num_contrat = models.CharField(max_length=254, null=True, blank=True)
    num_compteur = models.CharField(max_length=254, null=True, blank=True)
    type_cpt = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    type_abonnement = models.CharField(max_length=254, null=True, blank=True)
    etat_abonnement = models.CharField(max_length=254, null=True, blank=True)
    consommation = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    date_releve = models.DateField(null=True, blank=True)
    anne_fabr_compt = models.CharField(max_length=254, null=True, blank=True)
    anomalie_rdo = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    date_leve = models.DateField(null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    diametre_calibre_terrain = models.CharField(max_length=254, null=True, blank=True)
    diametre_conduite = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ancienne_police = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."compteur_abonne"'


class EpCompteurReseau(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_modele = models.CharField(max_length=254, null=True, blank=True)
    ep_marque = models.CharField(max_length=254, null=True, blank=True)
    ep_calibre = models.CharField(max_length=254, null=True, blank=True)
    ep_sourc_alim = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_regard = models.CharField(max_length=254, null=True, blank=True)
    ep_releve = models.CharField(max_length=254, null=True, blank=True)
    ep_res_deserv = models.CharField(max_length=254, null=True, blank=True)
    ep_n_serie = models.CharField(max_length=254, null=True, blank=True)
    ep_compt_fonction = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_mm = models.CharField(max_length=254, null=True, blank=True)
    ep_mm = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."compteur_reseau"'


class EpConeDeReduction(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_diam_in = models.CharField(max_length=254, null=True, blank=True)
    ep_diam_out = models.CharField(max_length=254, null=True, blank=True)
    ep_ref = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_dtae_pose = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."cone_de_reduction"'


class EpCentreTampon(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."centre_tampon"'


class EpNoeud(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."noeud"'


class EpObturateur(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."obturateur"'


class EpReducteurDePression(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_conduite = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."reducteur_de_pression"'

# =====================================================================
#  SCHÉMA EP — Eau Potable : suite des PONCTUELS + LINÉAIRES + SURFACIQUES
# =====================================================================

class EpForage(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    ep_debit = models.FloatField(null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."forage"'

    def __str__(self):
        return f"Forage {self.ep_num or self.fid}"


class EpPuit(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."puit"'

    def __str__(self):
        return f"Puits {self.ep_num or self.fid}"


class EpPompe(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_puissance = models.FloatField(null=True, blank=True)
    ep_debit = models.FloatField(null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."pompe"'

    def __str__(self):
        return f"Pompe {self.ep_num or self.fid}"


class EpReservoir(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_capacite = models.FloatField(null=True, blank=True)
    ep_cote_radier = models.FloatField(null=True, blank=True)
    ep_cote_trop_plein = models.FloatField(null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."reservoir"'

    def __str__(self):
        return f"Réservoir {self.ep_num or self.fid}"


class EpStationDePompage(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191,dim=3, null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_nb_pompes = models.IntegerField(null=True, blank=True)
    ep_capacite = models.FloatField(null=True, blank=True)
    ep_etat = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."station_de_pompage"'

    def __str__(self):
        return f"Station pompage {self.ep_num or self.fid}"


class EpRegard(models.Model):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    ep_agent = models.CharField(max_length=400, null=True, blank=True)
    ep_sect_com = models.CharField(max_length=400, null=True, blank=True)
    ep_statut = models.CharField(max_length=400, null=True, blank=True)
    ep_adresse = models.CharField(max_length=400, null=True, blank=True)
    ep_agent_crea = models.CharField(max_length=400, null=True, blank=True)
    sec_com = models.CharField(max_length=400, null=True, blank=True)
    sect_hydr = models.CharField(max_length=400, null=True, blank=True)
    zone = models.CharField(max_length=400, null=True, blank=True)
    uuid = models.UUIDField(null=True, blank=True, unique=True)
    z_radier = models.CharField(max_length=400, null=True, blank=True)
    z_surf = models.CharField(max_length=400, null=True, blank=True)
    ep_date_insertion = models.DateField(null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    id_province = models.IntegerField(null=True, blank=True)
    id_user_creat = models.IntegerField(null=True, blank=True)
    id_user_modif = models.IntegerField(null=True, blank=True)
    date_creation = models.DateTimeField(null=True, blank=True)
    date_modif = models.DateTimeField(null=True, blank=True)
    is_deleted = models.BooleanField(null=True, blank=True, default=False)
    is_validated = models.BooleanField(null=True, blank=True, default=False)
    id_user_valid = models.IntegerField(null=True, blank=True)
    date_validation = models.DateTimeField(null=True, blank=True)
    ep_section = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_tampon = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_rue = models.CharField(max_length=400, null=True, blank=True)
    ep_conf_plan = models.CharField(max_length=400, null=True, blank=True)
    ep_observation = models.CharField(max_length=400, null=True, blank=True)
    ep_anomalie = models.BooleanField(null=True, blank=True, default=False)
    mode_localisation = models.CharField(max_length=400, null=True, blank=True)
    echelon = models.CharField(max_length=400, null=True, blank=True)
    anomalie_tamp = models.CharField(max_length=400, null=True, blank=True)
    anomalie_regard = models.CharField(max_length=400, null=True, blank=True)
    GENRATRICE_SUP = models.FloatField(db_column='GENRATRICE_SUP', null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."regard"'

    def __str__(self):
        return f"Regard EP point {self.uuid or self.fid}"


class EpRegardMiroir(models.Model):
    fid = models.AutoField(primary_key=True)
    fid_regard_source = models.IntegerField(unique=True)
    geom = models.PolygonField(srid=26191, dim=3, null=True, blank=True)
    ep_agent = models.CharField(max_length=400, null=True, blank=True)
    ep_sect_com = models.CharField(max_length=400, null=True, blank=True)
    ep_statut = models.CharField(max_length=400, null=True, blank=True)
    ep_adresse = models.CharField(max_length=400, null=True, blank=True)
    ep_agent_crea = models.CharField(max_length=400, null=True, blank=True)
    sec_com = models.CharField(max_length=400, null=True, blank=True)
    sect_hydr = models.CharField(max_length=400, null=True, blank=True)
    zone = models.CharField(max_length=400, null=True, blank=True)
    uuid = models.UUIDField(null=True, blank=True, unique=True)
    z_radier = models.CharField(max_length=400, null=True, blank=True)
    z_surf = models.CharField(max_length=400, null=True, blank=True)
    ep_date_insertion = models.DateField(null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    id_province = models.IntegerField(null=True, blank=True)
    id_user_creat = models.IntegerField(null=True, blank=True)
    id_user_modif = models.IntegerField(null=True, blank=True)
    date_creation = models.DateTimeField(null=True, blank=True)
    date_modif = models.DateTimeField(null=True, blank=True)
    is_deleted = models.BooleanField(null=True, blank=True, default=False)
    is_validated = models.BooleanField(null=True, blank=True, default=False)
    id_user_valid = models.IntegerField(null=True, blank=True)
    date_validation = models.DateTimeField(null=True, blank=True)
    ep_section = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_tampon = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_rue = models.CharField(max_length=400, null=True, blank=True)
    ep_conf_plan = models.CharField(max_length=400, null=True, blank=True)
    ep_observation = models.CharField(max_length=400, null=True, blank=True)
    ep_anomalie = models.BooleanField(null=True, blank=True, default=False)
    mode_localisation = models.CharField(max_length=400, null=True, blank=True)
    echelon = models.CharField(max_length=400, null=True, blank=True)
    anomalie_tamp = models.CharField(max_length=400, null=True, blank=True)
    anomalie_regard = models.CharField(max_length=400, null=True, blank=True)
    GENRATRICE_SUP = models.FloatField(db_column='GENRATRICE_SUP', null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."regard_miroir"'

    def __str__(self):
        return f"Regard EP miroir {self.uuid or self.fid}"


class EpRegardEp(models.Model):
    fid = models.AutoField(primary_key=True)
    geom = models.PolygonField(srid=26191, dim=3, null=True, blank=True)
    ep_agent = models.CharField(max_length=400, null=True, blank=True)
    ep_sect_com = models.CharField(max_length=400, null=True, blank=True)
    ep_statut = models.CharField(max_length=400, null=True, blank=True)
    ep_adresse = models.CharField(max_length=400, null=True, blank=True)
    ep_agent_crea = models.CharField(max_length=400, null=True, blank=True)
    sec_com = models.CharField(max_length=400, null=True, blank=True)
    sect_hydr = models.CharField(max_length=400, null=True, blank=True)
    zone = models.CharField(max_length=400, null=True, blank=True)
    uuid = models.UUIDField(null=True, blank=True, unique=True)
    z_radier = models.CharField(max_length=400, null=True, blank=True)
    z_surf = models.CharField(max_length=400, null=True, blank=True)
    ep_date_insertion = models.DateField(null=True, blank=True)
    ep_coor_x = models.FloatField(null=True, blank=True)
    ep_coor_y = models.FloatField(null=True, blank=True)
    ep_coor_z = models.FloatField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    id_province = models.IntegerField(null=True, blank=True)
    id_user_creat = models.IntegerField(null=True, blank=True)
    id_user_modif = models.IntegerField(null=True, blank=True)
    date_creation = models.DateTimeField(null=True, blank=True)
    date_modif = models.DateTimeField(null=True, blank=True)
    is_deleted = models.BooleanField(null=True, blank=True, default=False)
    is_validated = models.BooleanField(null=True, blank=True, default=False)
    id_user_valid = models.IntegerField(null=True, blank=True)
    date_validation = models.DateTimeField(null=True, blank=True)
    ep_section = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ep_tampon = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_rue = models.CharField(max_length=400, null=True, blank=True)
    ep_conf_plan = models.CharField(max_length=400, null=True, blank=True)
    ep_observation = models.CharField(max_length=400, null=True, blank=True)
    ep_anomalie = models.BooleanField(null=True, blank=True, default=False)
    mode_localisation = models.CharField(max_length=400, null=True, blank=True)
    echelon = models.CharField(max_length=400, null=True, blank=True)
    anomalie_tamp = models.CharField(max_length=400, null=True, blank=True)
    anomalie_regard = models.CharField(max_length=400, null=True, blank=True)
    GENRATRICE_SUP = models.FloatField(db_column='GENRATRICE_SUP', null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."regard_ep"'

    def __str__(self):
        return f"Regard EP {self.uuid or self.fid}"


class EpAutreObjet(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    type_objet = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    date_leve = models.DateTimeField(null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    uuid = models.CharField(max_length=100, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    ep_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."autre_objet"'

    def __str__(self):
        return f"Autre objet EP {self.type_objet or self.fid}"


# ---------- EP LINÉAIRES ----------

class EpConduiteTerrain(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3,null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_mat = models.CharField(max_length=254, null=True, blank=True)
    ep_long_c = models.FloatField(null=True, blank=True)
    ep_long_r = models.FloatField(null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    ep_classe_conduite = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    zamont = models.FloatField(null=True, blank=True)
    zaval = models.FloatField(null=True, blank=True)
    pente = models.FloatField(null=True, blank=True)
    zalerte = models.FloatField(null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    ep_sect_hydro = models.CharField(max_length=254, null=True, blank=True)
    ep_etage_p = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    ep_date_interv = models.DateField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."ep_conduite_terrain"'

    def __str__(self):
        return f"Conduite terrain {self.ep_num or self.fid}"


class EpConduiteBureau(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3,null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_mat = models.CharField(max_length=254, null=True, blank=True)
    ep_long_c = models.FloatField(null=True, blank=True)
    ep_long_r = models.FloatField(null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    ep_classe_conduite = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    zamont = models.FloatField(null=True, blank=True)
    zaval = models.FloatField(null=True, blank=True)
    pente = models.FloatField(null=True, blank=True)
    zalerte = models.FloatField(null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_entreprise = models.CharField(max_length=254, null=True, blank=True)
    ep_ref_marche = models.CharField(max_length=254, null=True, blank=True)
    ep_sect_hydro = models.CharField(max_length=254, null=True, blank=True)
    ep_etage_p = models.CharField(max_length=254, null=True, blank=True)
    etage_aqua = models.CharField(max_length=254, null=True, blank=True)
    secteur_aqua = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    ep_date_interv = models.DateField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."ep_conduite_bureau"'

    def __str__(self):
        return f"Conduite bureau {self.ep_num or self.fid}"


class EpBranchement(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3,null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_diam = models.CharField(max_length=254, null=True, blank=True)
    ep_mat = models.CharField(max_length=254, null=True, blank=True)
    ep_long_c = models.FloatField(null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."branchement"'

    def __str__(self):
        return f"Branchement EP {self.ep_num or self.fid}"


class EpTraverse(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3,null=True, blank=True)
    ep_num = models.CharField(max_length=254, null=True, blank=True)
    ep_type = models.CharField(max_length=254, null=True, blank=True)
    ep_longueur = models.FloatField(null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    ref_rue = models.CharField(max_length=254, null=True, blank=True)
    ep_statut = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."traverse"'

    def __str__(self):
        return f"Traversée EP {self.ep_num or self.fid}"


# ---------- EP SURFACIQUE ----------

class EpPlanche(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PolygonField(srid=26191, dim=3,null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    code = models.CharField(max_length=254, null=True, blank=True)
    observation = models.CharField(max_length=254, null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."planche"'

    def __str__(self):
        return f"Planche {self.nom or self.code or self.fid}"


# =====================================================================
#  SCHÉMA ASS — Assainissement (9 tables)
# =====================================================================

class AssRegard(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    type_regard = models.CharField(max_length=254, null=True, blank=True)
    type_tampon = models.CharField(max_length=254, null=True, blank=True)
    typereseau = models.CharField(max_length=254, null=True, blank=True)
    classe_tampon = models.CharField(max_length=254, null=True, blank=True)
    forme = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    verrouille = models.CharField(max_length=254, null=True, blank=True)
    accessibilite = models.CharField(max_length=254, null=True, blank=True)
    rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    date_rehabilitation = models.DateField(null=True, blank=True)
    nature_corps = models.CharField(max_length=254, null=True, blank=True)
    presence_cunette = models.CharField(max_length=254, null=True, blank=True)
    cote_tampon = models.FloatField(null=True, blank=True)
    cote_radier = models.FloatField(null=True, blank=True)
    chute = models.CharField(max_length=254, null=True, blank=True)
    profondeur_radier = models.FloatField(null=True, blank=True)
    ass_coor_x = models.FloatField(null=True, blank=True)
    ass_coor_y = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_canalisation_aval = models.IntegerField(null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    elevation = models.FloatField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    ass_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_regard"'

    def __str__(self):
        return f"Regard ASS {self.fid}"


class AssRegardBranchement(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    type_tampon = models.CharField(max_length=254, null=True, blank=True)
    typereseau = models.CharField(max_length=254, null=True, blank=True)
    classe_tampon = models.CharField(max_length=254, null=True, blank=True)
    forme = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    verrouille = models.CharField(max_length=254, null=True, blank=True)
    accessibilite = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    date_rehabilitation = models.DateField(null=True, blank=True)
    nature_corps = models.CharField(max_length=254, null=True, blank=True)
    presence_cunette = models.CharField(max_length=254, null=True, blank=True)
    cote_tampon = models.FloatField(null=True, blank=True)
    cote_radier = models.FloatField(null=True, blank=True)
    profondeur_radier = models.FloatField(null=True, blank=True)
    ass_coor_x = models.FloatField(null=True, blank=True)
    ass_coor_y = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_branchement = models.IntegerField(null=True, blank=True)
    id_regard_branchement = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    ass_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_regard_branchement"'

    def __str__(self):
        return f"Regard branchement ASS {self.fid}"


class AssCanalisation(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    classe = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    nature = models.CharField(max_length=254, null=True, blank=True)
    typereseau = models.CharField(max_length=254, null=True, blank=True)
    reference = models.CharField(max_length=254, null=True, blank=True)
    rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    date_rehabilitation = models.DateField(null=True, blank=True)
    diametre = models.CharField(max_length=254, null=True, blank=True)
    largeur_base = models.FloatField(null=True, blank=True)
    profondeur_aval = models.FloatField(null=True, blank=True)
    profondeur_amont = models.FloatField(null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    type_ecoulement = models.CharField(max_length=254, null=True, blank=True)
    type_section = models.CharField(max_length=254, null=True, blank=True)
    type_conduite = models.CharField(max_length=254, null=True, blank=True)
    type_rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    protection_anticorrosion = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_canalisation = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_canalisation"'

    def __str__(self):
        return f"Canalisation ASS {self.fid}"


class AssCanalisationReutilisation(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    classe = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    nature = models.CharField(max_length=254, null=True, blank=True)
    reference = models.CharField(max_length=254, null=True, blank=True)
    rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    date_rehabilitation = models.DateField(null=True, blank=True)
    type_rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    diametre = models.CharField(max_length=254, null=True, blank=True)
    profondeur_aval = models.FloatField(null=True, blank=True)
    profondeur_amont = models.FloatField(null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    type_ecoulement = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_canalisation_reutilisation = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    ass_coor_x = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    ass_coor_y = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    ass_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_canalisation_reutilisation"'

    def __str__(self):
        return f"Canalisation réutilisation ASS {self.fid}"


class AssBranchement(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    classe = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    nature = models.CharField(max_length=254, null=True, blank=True)
    typereseau = models.CharField(max_length=254, null=True, blank=True)
    reference = models.CharField(max_length=254, null=True, blank=True)
    rehabilitation = models.CharField(max_length=254, null=True, blank=True)
    date_rehabilitation = models.DateField(null=True, blank=True)
    diametre = models.CharField(max_length=254, null=True, blank=True)
    emplacement = models.CharField(max_length=254, null=True, blank=True)
    type_activite = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_canalisation = models.IntegerField(null=True, blank=True)
    id_branchement = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_branchement"'

    def __str__(self):
        return f"Branchement ASS {self.fid}"


class AssBassin(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    type_bassin = models.CharField(max_length=254, null=True, blank=True)
    diametre_amont = models.CharField(max_length=254, null=True, blank=True)
    diametre_aval = models.CharField(max_length=254, null=True, blank=True)
    capacite = models.FloatField(null=True, blank=True)
    date_construction = models.DateField(null=True, blank=True)
    forme_bassin = models.CharField(max_length=254, null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    largeur = models.FloatField(null=True, blank=True)
    hauteur = models.FloatField(null=True, blank=True)
    cote_arrivee = models.FloatField(null=True, blank=True)
    cote_depart = models.FloatField(null=True, blank=True)
    cote_trop_plein = models.FloatField(null=True, blank=True)
    cote_radier = models.FloatField(null=True, blank=True)
    ass_coor_x = models.FloatField(null=True, blank=True)
    ass_coor_y = models.FloatField(null=True, blank=True)
    ass_coor_z = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_canalisation_depart = models.IntegerField(null=True, blank=True)
    id_bassin = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_bassin"'

    def __str__(self):
        return f"Bassin ASS {self.fid}"


class AssOuvrage(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    type_ouvrage = models.CharField(max_length=254, null=True, blank=True)
    capacite = models.FloatField(null=True, blank=True)
    date_construction = models.DateField(null=True, blank=True)
    accessibilite = models.CharField(max_length=254, null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    largeur = models.FloatField(null=True, blank=True)
    hauteur = models.FloatField(null=True, blank=True)
    cote_arrivee = models.FloatField(null=True, blank=True)
    pretraitement = models.CharField(max_length=254, null=True, blank=True)
    sortie = models.CharField(max_length=254, null=True, blank=True)
    ass_coor_x = models.FloatField(null=True, blank=True)
    ass_coor_y = models.FloatField(null=True, blank=True)
    ass_coor_z = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_canalisation_amont = models.IntegerField(null=True, blank=True)
    id_ouvrage = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_ouvrage"'

    def __str__(self):
        return f"Ouvrage ASS {self.fid}"


class AssEquipement(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    typereseau = models.CharField(max_length=254, null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    situation_equipement = models.CharField(max_length=254, null=True, blank=True)
    profondeur = models.FloatField(null=True, blank=True)
    cote_tn = models.FloatField(null=True, blank=True)
    ass_coor_x = models.FloatField(null=True, blank=True)
    ass_coor_y = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_regard = models.IntegerField(null=True, blank=True)
    id_ouvrage = models.IntegerField(null=True, blank=True)
    id_canalisation = models.IntegerField(null=True, blank=True)
    id_equipement = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    ass_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_equipement"'

    def __str__(self):
        return f"Équipement ASS {self.fid}"


class AssStation(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    etat = models.CharField(max_length=254, null=True, blank=True)
    type_station = models.CharField(max_length=254, null=True, blank=True)
    capacite = models.FloatField(null=True, blank=True)
    debit_nominal = models.FloatField(null=True, blank=True)
    date_construction = models.DateField(null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    largeur = models.FloatField(null=True, blank=True)
    nombre_pompes = models.IntegerField(null=True, blank=True)
    cote_arrivee = models.FloatField(null=True, blank=True)
    pretraitement = models.CharField(max_length=254, null=True, blank=True)
    sortie = models.CharField(max_length=254, null=True, blank=True)
    ass_coor_x = models.FloatField(null=True, blank=True)
    ass_coor_y = models.FloatField(null=True, blank=True)
    ass_coor_z = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_canalisation_amont = models.IntegerField(null=True, blank=True)
    id_station = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."asst_station"'

    def __str__(self):
        return f"Station ASS {self.nom or self.fid}"

# =====================================================================
#  SCHÉMA ELEC — Électricité (11 tables)
# =====================================================================

# ---------- PONCTUELS (avec géométrie) ----------

class ElecSupport(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_depart_hta = models.IntegerField(null=True, blank=True)
    id_depart_bt = models.IntegerField(null=True, blank=True)
    type_support = models.CharField(max_length=254, null=True, blank=True)
    elec_coor_x = models.FloatField(null=True, blank=True)
    elec_coor_y = models.FloatField(null=True, blank=True)
    console = models.CharField(max_length=254, null=True, blank=True)
    etat_support = models.CharField(max_length=254, null=True, blank=True)
    materiel_supp = models.CharField(max_length=254, null=True, blank=True)
    type_assemblage = models.CharField(max_length=254, null=True, blank=True)
    type_armement = models.CharField(max_length=254, null=True, blank=True)
    type_protection = models.CharField(max_length=254, null=True, blank=True)
    status = models.CharField(max_length=254, null=True, blank=True)
    mise_a_la_terre = models.CharField(max_length=254, null=True, blank=True)
    type_isolateur = models.CharField(max_length=254, null=True, blank=True)
    code_support = models.CharField(max_length=254, null=True, blank=True)
    lumineux = models.CharField(max_length=254, null=True, blank=True)
    hauteur_supp = models.FloatField(null=True, blank=True)
    type_mise_a_la_terre = models.CharField(max_length=254, null=True, blank=True)
    type_balise = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_support = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    elec_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."support"'

    def __str__(self):
        return f"Support {self.code_support or self.fid}"


class ElecPoste(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    nom_poste = models.CharField(max_length=254, null=True, blank=True)
    type_poste = models.CharField(max_length=254, null=True, blank=True)
    nature_poste = models.CharField(max_length=254, null=True, blank=True)
    elec_coor_x = models.FloatField(null=True, blank=True)
    elec_coor_y = models.FloatField(null=True, blank=True)
    coordonee_z_tn = models.FloatField(null=True, blank=True)
    etat_service = models.CharField(max_length=254, null=True, blank=True)
    tension = models.CharField(max_length=254, null=True, blank=True)
    tableau_ep = models.CharField(max_length=254, null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    nouveau_code_poste = models.CharField(max_length=254, null=True, blank=True)
    type_aeration = models.CharField(max_length=254, null=True, blank=True)
    depart = models.CharField(max_length=254, null=True, blank=True)
    telecommande = models.CharField(max_length=254, null=True, blank=True)
    support_communication = models.CharField(max_length=254, null=True, blank=True)
    nb_rames = models.IntegerField(null=True, blank=True)
    nb_depart_mt_dispo = models.IntegerField(null=True, blank=True)
    nb_depart_mt_en_service = models.IntegerField(null=True, blank=True)
    presence_ild = models.CharField(max_length=254, null=True, blank=True)
    detec_extinc_incendie = models.CharField(max_length=254, null=True, blank=True)
    tableau_bt = models.CharField(max_length=254, null=True, blank=True)
    nb_arrivees_ht = models.IntegerField(null=True, blank=True)
    nb_transfo_install = models.IntegerField(null=True, blank=True)
    compensation_energie = models.CharField(max_length=254, null=True, blank=True)
    date_mst = models.DateField(null=True, blank=True)
    puissance_garantie_ligne = models.IntegerField(null=True, blank=True)
    nb_travee_ligne = models.IntegerField(null=True, blank=True)
    nb_travee_transfo = models.IntegerField(null=True, blank=True)
    nb_emplacement_transfo = models.IntegerField(null=True, blank=True)
    compteur_ht = models.CharField(max_length=254, null=True, blank=True)
    compteur_mt = models.CharField(max_length=254, null=True, blank=True)
    compteur_bt = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    elec_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."poste"'

    def __str__(self):
        return f"Poste {self.nom_poste or self.fid}"


class ElecCoffretBt(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_depart_bt = models.IntegerField(null=True, blank=True)
    type_coffret = models.CharField(max_length=254, null=True, blank=True)
    elec_coor_x = models.FloatField(null=True, blank=True)
    elec_coor_y = models.FloatField(null=True, blank=True)
    miseterre_neutre = models.CharField(max_length=254, null=True, blank=True)
    statut_coffret = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    num_coffret = models.IntegerField(null=True, blank=True)
    code_depart = models.CharField(max_length=254, null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    num_transfo = models.CharField(max_length=254, null=True, blank=True)
    nbr_depart = models.IntegerField(null=True, blank=True)
    nbr_arrivees = models.IntegerField(null=True, blank=True)
    protection = models.CharField(max_length=254, null=True, blank=True)
    enveloppe_coffret = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_coffret_bt = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    elec_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."coffret_bt"'

    def __str__(self):
        return f"Coffret BT {self.num_coffret or self.fid}"


class ElecNoeudRaccord(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_troncon_bt = models.IntegerField(null=True, blank=True)
    id_depart_bt = models.IntegerField(null=True, blank=True)
    type_raccord = models.CharField(max_length=254, null=True, blank=True)
    elec_coor_x = models.FloatField(null=True, blank=True)
    elec_coor_y = models.FloatField(null=True, blank=True)
    marque_raccord = models.CharField(max_length=254, null=True, blank=True)
    modele_raccord = models.CharField(max_length=254, null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    num_serie = models.CharField(max_length=254, null=True, blank=True)
    mise_a_terre = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_noeud_raccord = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    elec_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."noeud_raccord"'

    def __str__(self):
        return f"Noeud raccord {self.fid}"


class ElecPointDesserte(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.PointField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_coffret_bt = models.IntegerField(null=True, blank=True)
    id_troncon_bt = models.IntegerField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    elec_coor_x = models.FloatField(null=True, blank=True)
    elec_coor_y = models.FloatField(null=True, blank=True)
    boite_coupure = models.CharField(max_length=254, null=True, blank=True)
    type_protection = models.CharField(max_length=254, null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    num_transfo = models.CharField(max_length=254, null=True, blank=True)
    tournee = models.CharField(max_length=254, null=True, blank=True)
    code_depart = models.CharField(max_length=254, null=True, blank=True)
    coffret = models.CharField(max_length=254, null=True, blank=True)
    position = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_point_desserte = models.IntegerField(null=True, blank=True)
    elevation = models.FloatField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    elec_coor_z = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)
    photo_3 = models.TextField(null=True, blank=True)
    photo_4 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."point_desserte"'

    def __str__(self):
        return f"Point desserte {self.nom or self.fid}"


# ---------- ATTRIBUTS (sans géométrie propre, liés à poste) ----------

class ElecTransformateur(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_cellule = models.IntegerField(null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    status_transfo = models.CharField(max_length=254, null=True, blank=True)
    puiss_transfo = models.CharField(max_length=254, null=True, blank=True)
    num_transfo = models.CharField(max_length=254, null=True, blank=True)
    tension_sec = models.IntegerField(null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    code_transfo = models.CharField(max_length=254, null=True, blank=True)
    numero_serie = models.CharField(max_length=254, null=True, blank=True)
    tension_primitive = models.CharField(max_length=254, null=True, blank=True)
    annee_fabrication = models.IntegerField(null=True, blank=True)
    date_mst = models.IntegerField(null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    refroidissement = models.CharField(max_length=254, null=True, blank=True)
    comptage = models.CharField(max_length=254, null=True, blank=True)
    ucc = models.FloatField(null=True, blank=True)
    bucholz = models.CharField(max_length=254, null=True, blank=True)
    nb_position_regleur = models.IntegerField(null=True, blank=True)
    nb_enroulement = models.IntegerField(null=True, blank=True)
    nb_prise = models.IntegerField(null=True, blank=True)
    commutable = models.CharField(max_length=254, null=True, blank=True)
    regleur_en_charge = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_transfo = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."transformateur"'

    def __str__(self):
        return f"Transformateur {self.num_transfo or self.fid}"


class ElecCellule(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_transfo = models.IntegerField(null=True, blank=True)
    nom = models.CharField(max_length=254, null=True, blank=True)
    numero_cellule = models.IntegerField(null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    num_serie = models.CharField(max_length=254, null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    moteur = models.CharField(max_length=254, null=True, blank=True)
    nom_depart = models.CharField(max_length=254, null=True, blank=True)
    type = models.CharField(max_length=254, null=True, blank=True)
    fonction = models.CharField(max_length=254, null=True, blank=True)
    nature_disjoncteur = models.CharField(max_length=254, null=True, blank=True)
    type_commande = models.CharField(max_length=254, null=True, blank=True)
    date_fabrication = models.DateField(null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_cellule = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."cellule"'

    def __str__(self):
        return f"Cellule {self.nom or self.fid}"


class ElecDepartBt(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_transfo = models.IntegerField(null=True, blank=True)
    id_coffret_bt = models.IntegerField(null=True, blank=True)
    nom_depart = models.CharField(max_length=254, null=True, blank=True)
    tension_bt = models.CharField(max_length=254, null=True, blank=True)
    nom_poste = models.CharField(max_length=254, null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    num_transfo = models.IntegerField(null=True, blank=True)
    numero_depart = models.IntegerField(null=True, blank=True)
    codedepart = models.CharField(max_length=254, null=True, blank=True)
    section_souterrain = models.IntegerField(null=True, blank=True)
    section_aerien = models.IntegerField(null=True, blank=True)
    neutre = models.FloatField(null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_depart_bt = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."depart_bt"'

    def __str__(self):
        return f"Départ BT {self.nom_depart or self.fid}"


class ElecDepartHta(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    nom_depart = models.CharField(max_length=254, null=True, blank=True)
    tension_hta = models.CharField(max_length=254, null=True, blank=True)
    nom_poste_source = models.CharField(max_length=254, null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    numero_depart = models.IntegerField(null=True, blank=True)
    code_depart = models.CharField(max_length=254, null=True, blank=True)
    section = models.IntegerField(null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    id_depart_hta = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."depart_hta"'

    def __str__(self):
        return f"Départ HTA {self.nom_depart or self.fid}"


# ---------- LINÉAIRES ----------

class ElecTronconBt(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_poste = models.IntegerField(null=True, blank=True)
    id_depart_bt = models.IntegerField(null=True, blank=True)
    techcable = models.CharField(max_length=254, null=True, blank=True)
    type_liaison = models.CharField(max_length=254, null=True, blank=True)
    section_conducteur = models.CharField(max_length=254, null=True, blank=True)
    mode_pose = models.CharField(max_length=254, null=True, blank=True)
    status_troncon = models.CharField(max_length=254, null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    date_mise_service = models.DateField(null=True, blank=True)
    code_poste = models.CharField(max_length=254, null=True, blank=True)
    num_transfo = models.IntegerField(null=True, blank=True)
    codedepart = models.CharField(max_length=254, null=True, blank=True)
    nbphases = models.CharField(max_length=254, null=True, blank=True)
    section_neutre = models.FloatField(null=True, blank=True)
    nu = models.CharField(max_length=254, null=True, blank=True)
    section_phase = models.FloatField(null=True, blank=True)
    arme = models.CharField(max_length=254, null=True, blank=True)
    cable_unipolaire = models.CharField(max_length=254, null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_troncon_bt = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."troncon_bt"'

    def __str__(self):
        return f"Tronçon BT {self.fid}"


class ElecTronconHta(SrmTrackedModel):
    fid = models.AutoField(primary_key=True)
    geom = models.LineStringField(srid=26191, dim=3, null=True, blank=True)
    objectid = models.IntegerField(null=True, blank=True)
    uuid = models.CharField(max_length=254, null=True, blank=True)
    id_depart_hta = models.IntegerField(null=True, blank=True)
    id_noeud_raccord = models.IntegerField(null=True, blank=True)
    status_troncon = models.CharField(max_length=254, null=True, blank=True)
    type_troncon = models.CharField(max_length=254, null=True, blank=True)
    section_conduct = models.CharField(max_length=254, null=True, blank=True)
    type_cable = models.CharField(max_length=254, null=True, blank=True)
    metal_conduct = models.CharField(max_length=254, null=True, blank=True)
    phasage_segment = models.CharField(max_length=254, null=True, blank=True)
    caracteristique = models.CharField(max_length=254, null=True, blank=True)
    technologie_utilisee = models.CharField(max_length=254, null=True, blank=True)
    neutre = models.CharField(max_length=254, null=True, blank=True)
    section_neutre = models.IntegerField(null=True, blank=True)
    type_mise_terre = models.CharField(max_length=254, null=True, blank=True)
    section_mise_terre = models.IntegerField(null=True, blank=True)
    tension = models.CharField(max_length=254, null=True, blank=True)
    postesource = models.CharField(max_length=254, null=True, blank=True)
    date_mise_en_service = models.DateField(null=True, blank=True)
    date_pose = models.DateField(null=True, blank=True)
    marque = models.CharField(max_length=254, null=True, blank=True)
    depart = models.CharField(max_length=254, null=True, blank=True)
    long_troncon = models.FloatField(null=True, blank=True)
    centre = models.CharField(max_length=254, null=True, blank=True)
    commentaire = models.CharField(max_length=254, null=True, blank=True)
    conformite_plan = models.CharField(max_length=254, null=True, blank=True)
    id_troncon_hta = models.IntegerField(null=True, blank=True)
    id_projet = models.IntegerField(null=True, blank=True)
    id_agent_crea = models.IntegerField(null=True, blank=True)
    id_mission = models.IntegerField(null=True, blank=True)
    id_planche = models.IntegerField(null=True, blank=True)
    id_commune = models.IntegerField(null=True, blank=True)
    mode_localisation = models.CharField(max_length=100, default='gnss')
    anomalie = models.BooleanField(default=False)
    type_anomalie = models.TextField(null=True, blank=True)
    photo_1 = models.TextField(null=True, blank=True)
    photo_2 = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"elec"."troncon_hta"'

    def __str__(self):
        return f"Tronçon HTA {self.fid}"
