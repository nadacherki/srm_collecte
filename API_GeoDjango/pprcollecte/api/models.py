"""
ModÃ¨les Django pour la base de donnÃ©es SIG SRM.

IMPORTANT : managed = False sur tous les modÃ¨les car les tables existent dÃ©jÃ 
dans la base sig_srm. Django ne crÃ©e ni ne modifie les tables â€” il les lit.

Organisation :
  - SchÃ©ma public : Utilisateur, Commune, Zone, synchronisation, etc.
  - SchÃ©ma ep     : Eau Potable (27 tables)
  - SchÃ©ma ass    : Assainissement (9 tables)
  - SchÃ©ma elec   : Ã‰lectricitÃ© (11 tables)

Toutes les gÃ©omÃ©tries sont en EPSG:26191 (Merchich Nord).
"""

from django.contrib.gis.db import models

from .metrics_models import (
    MetricAgentJour,
    MetricAgentSemaine,
    MetricAgentMois,
    MetricAgentTablePeriod,
    MetricAgentPeriod,
    MetricAgentResume,
    MetricAgentPublicJour,
    MetricAgentPublicSemaine,
    MetricAgentPublicMois,
    MetricAgentPublicResume,
)


class SrmTrackedModel(models.Model):
    class Meta:
        abstract = True


# =====================================================================
#  SCHÃ‰MA PUBLIC â€” Tables de gestion (8 tables)
# =====================================================================

class Utilisateur(models.Model):
    id_user = models.AutoField(primary_key=True)
    login = models.CharField(max_length=100, unique=True)
    mot_de_passe_hash = models.CharField(max_length=255, null=True, blank=True)
    nom = models.CharField(max_length=200, null=True, blank=True)
    prenom = models.CharField(max_length=200, null=True, blank=True)
    actif = models.BooleanField(default=True)
    date_creation = models.DateField(null=True, blank=True)
    dernier_login = models.DateTimeField(null=True, blank=True)
    nb_objets_collectes_total = models.IntegerField(default=0)
    role = models.CharField(max_length=20, default='viewer_mobile')
    is_deleted = models.BooleanField(default=False)

    class Meta:
        managed = False
        db_table = 'utilisateur'

    @property
    def nom_complet(self):
        return ' '.join(part for part in (self.prenom, self.nom) if part) or self.login

    def __str__(self):
        return f"{self.nom_complet} ({self.login})"


class Commune(models.Model):
    fid = models.IntegerField(primary_key=True)
    geom = models.MultiPolygonField(srid=26191, null=True, blank=True)
    code_provi = models.CharField(max_length=100, null=True, blank=True)
    code_regio = models.CharField(max_length=100, null=True, blank=True)
    nom = models.CharField(max_length=255, null=True, blank=True)
    nom_arabe = models.CharField(max_length=255, null=True, blank=True)
    id_province = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'commune_oriental'

    def __str__(self):
        return self.nom or str(self.fid)


class Zone(models.Model):
    id_zone = models.AutoField(primary_key=True)
    geom = models.PolygonField(srid=26191, null=True, blank=True)
    nom_zone = models.CharField(max_length=254)
    etat = models.CharField(max_length=50, default='active', null=True, blank=True)
    date_debut = models.DateTimeField(null=True, blank=True)
    date_cloture = models.DateTimeField(null=True, blank=True)
    id_user_creat = models.IntegerField(null=True, blank=True)
    id_user_cloture = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'zone'

    def __str__(self):
        return self.nom_zone or str(self.id_zone)

    @property
    def zone_id(self):
        return f"zone_{self.id_zone}"

    @property
    def city_slug(self):
        return "oujda"

    @property
    def nom(self):
        return self.nom_zone

    @property
    def min_zoom(self):
        return 11

    @property
    def max_zoom(self):
        return 19

    def _geom_4326(self):
        if self.geom is None:
            return None
        geom = self.geom.clone()
        geom.transform(4326)
        return geom

    @property
    def bbox_west(self):
        geom = self._geom_4326()
        return geom.extent[0] if geom is not None else 0

    @property
    def bbox_south(self):
        geom = self._geom_4326()
        return geom.extent[1] if geom is not None else 0

    @property
    def bbox_east(self):
        geom = self._geom_4326()
        return geom.extent[2] if geom is not None else 0

    @property
    def bbox_north(self):
        geom = self._geom_4326()
        return geom.extent[3] if geom is not None else 0

    @property
    def center_latitude(self):
        geom = self._geom_4326()
        return geom.point_on_surface.y if geom is not None else 0

    @property
    def center_longitude(self):
        geom = self._geom_4326()
        return geom.point_on_surface.x if geom is not None else 0


class ZoneUtilisateur(models.Model):
    id = models.AutoField(primary_key=True)
    id_zone = models.IntegerField()
    id_user = models.IntegerField()
    date_affectation = models.DateTimeField(null=True, blank=True)
    actif = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'zone_utilisateur'
        unique_together = (('id_zone', 'id_user'),)

    def __str__(self):
        return f"user={self.id_user} zone={self.id_zone}"


class HistoriqueAction(models.Model):
    id = models.AutoField(primary_key=True)
    nom_table = models.CharField(max_length=100)
    id_objet = models.IntegerField()
    action = models.CharField(max_length=50)
    source = models.CharField(max_length=20, default='bureau')
    id_user = models.IntegerField(null=True, blank=True)
    nom_user = models.CharField(max_length=255, null=True, blank=True)
    date_action = models.DateTimeField()
    old_data = models.JSONField(null=True, blank=True)
    new_data = models.JSONField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'historique_action'


class ObjetIncomplet(models.Model):
    id_incomplet = models.AutoField(primary_key=True)
    nom_table = models.CharField(max_length=255)
    id_objet = models.IntegerField()
    detail_raison = models.TextField(null=True, blank=True)
    date_signalement = models.DateTimeField(null=True, blank=True)
    id_agent_incomplet = models.IntegerField(null=True, blank=True)
    statut = models.CharField(max_length=20, default='A_COMPLETER')
    date_completion = models.DateTimeField(null=True, blank=True)
    id_agent_completement = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'objet_incomplet'


class InterventionAnomalie(models.Model):
    id = models.AutoField(primary_key=True)
    id_objet = models.IntegerField()
    nom_classe = models.CharField(max_length=100)
    nom_table = models.CharField(max_length=255)
    uuid_objet = models.CharField(max_length=254, null=True, blank=True)
    retour_terrain = models.BooleanField(default=False)
    statut = models.CharField(max_length=50, default='signale')
    responsable_actuel = models.CharField(max_length=50, default='exploitant')
    etat_exploitant = models.CharField(max_length=50, default='en_attente')
    commentaire_exploitant = models.TextField(null=True, blank=True)
    date_exploitant = models.DateTimeField(null=True, blank=True)
    id_user_exploitant = models.IntegerField(null=True, blank=True)
    etat_terrain = models.CharField(max_length=50, default='en_attente')
    commentaire_terrain = models.TextField(null=True, blank=True)
    date_terrain = models.DateTimeField(null=True, blank=True)
    id_user_terrain = models.IntegerField(null=True, blank=True)
    etat_bureau = models.CharField(max_length=50, default='en_attente')
    commentaire_bureau = models.TextField(null=True, blank=True)
    date_bureau = models.DateTimeField(null=True, blank=True)
    id_user_bureau = models.IntegerField(null=True, blank=True)
    date_creation = models.DateTimeField(null=True, blank=True)
    date_cloture = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'intervention_anomalie'

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
    id_agent_crea = models.IntegerField(null=True, blank=True)
    date_prise_reelle = models.DateTimeField(null=True, blank=True)
    date_upload = models.DateTimeField(null=True, blank=True)
    actif = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = 'objet_photo'

    def __str__(self):
        return f"{self.nom_schema}.{self.nom_table} {self.uuid_objet} photo {self.num_photo}"


class SyncSession(models.Model):
    id_sync_session = models.BigAutoField(primary_key=True)
    sync_uuid = models.CharField(max_length=64, unique=True)
    id_agent = models.IntegerField(null=True, blank=True)
    device_id = models.CharField(max_length=128, null=True, blank=True)
    app_version = models.CharField(max_length=64, null=True, blank=True)
    statut = models.CharField(max_length=30, default='manifest_received')
    total_items = models.IntegerField(default=0)
    total_attachments = models.IntegerField(default=0)
    received_items = models.IntegerField(default=0)
    received_attachments = models.IntegerField(default=0)
    failed_items = models.IntegerField(default=0)
    started_at = models.DateTimeField(null=True, blank=True)
    last_activity_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    metadata_json = models.JSONField(null=True, blank=True)
    last_error = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'sync_session'

    def __str__(self):
        return f"Sync {self.sync_uuid} ({self.statut})"


class SyncSessionItem(models.Model):
    id_sync_item = models.BigAutoField(primary_key=True)
    sync_session = models.ForeignKey(
        SyncSession,
        db_column='id_sync_session',
        related_name='items',
        on_delete=models.CASCADE,
    )
    client_item_uuid = models.CharField(max_length=128, null=True, blank=True)
    nom_schema = models.CharField(max_length=30)
    nom_table = models.CharField(max_length=100)
    uuid_objet = models.CharField(max_length=254)
    local_id = models.BigIntegerField(null=True, blank=True)
    operation = models.CharField(max_length=30, default='upsert')
    payload_hash = models.CharField(max_length=64, null=True, blank=True)
    statut = models.CharField(max_length=30, default='pending')
    attempts = models.IntegerField(default=0)
    last_error = models.TextField(null=True, blank=True)
    received_at = models.DateTimeField(null=True, blank=True)
    last_activity_at = models.DateTimeField(null=True, blank=True)
    response_pk = models.CharField(max_length=128, null=True, blank=True)
    response_uuid = models.CharField(max_length=254, null=True, blank=True)
    payload_summary_json = models.JSONField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'sync_session_item'

    def __str__(self):
        return f"{self.sync_session.sync_uuid} {self.nom_schema}.{self.nom_table} {self.uuid_objet}"


class SyncSessionAttachment(models.Model):
    id_sync_attachment = models.BigAutoField(primary_key=True)
    sync_session = models.ForeignKey(
        SyncSession,
        db_column='id_sync_session',
        related_name='attachments',
        on_delete=models.CASCADE,
    )
    nom_schema = models.CharField(max_length=30)
    nom_table = models.CharField(max_length=100)
    uuid_objet = models.CharField(max_length=254)
    photo_slot = models.SmallIntegerField()
    local_path = models.TextField(null=True, blank=True)
    sha256 = models.CharField(max_length=64, null=True, blank=True)
    taille_octets = models.BigIntegerField(null=True, blank=True)
    statut = models.CharField(max_length=30, default='pending')
    attempts = models.IntegerField(default=0)
    last_error = models.TextField(null=True, blank=True)
    received_at = models.DateTimeField(null=True, blank=True)
    last_activity_at = models.DateTimeField(null=True, blank=True)
    remote_path = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'sync_session_attachment'

    def __str__(self):
        return (
            f"{self.sync_session.sync_uuid} {self.nom_schema}.{self.nom_table} "
            f"{self.uuid_objet} photo {self.photo_slot}"
        )


class EpStatistiqueConduite(models.Model):
    id_statistique_conduite = models.BigAutoField(primary_key=True)
    id_agent = models.IntegerField()
    jour = models.DateField()
    geom = models.MultiLineStringField(srid=26191, dim=3, null=True, blank=True)
    longueur_conduite_m = models.FloatField(default=0.0)
    created_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."statistique_conduite"'

    def __str__(self):
        return f"Stat conduite EP agent={self.id_agent} jour={self.jour}"


class EpStatistiqueConduiteSegment(models.Model):
    id_statistique_conduite_segment = models.BigAutoField(primary_key=True)
    id_statistique_conduite = models.BigIntegerField()
    fid_regard_a = models.IntegerField()
    fid_regard_b = models.IntegerField()
    fid_regard_min = models.IntegerField()
    fid_regard_max = models.IntegerField()
    geom = models.LineStringField(srid=26191, dim=3)
    longueur_segment_m = models.FloatField(default=0.0)
    created_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."statistique_conduite_segment"'

    def __str__(self):
        return (
            f"Segment conduite EP stat={self.id_statistique_conduite} "
            f"{self.fid_regard_min}-{self.fid_regard_max}"
        )


class AssStatistiqueConduite(models.Model):
    id_statistique_conduite = models.BigAutoField(primary_key=True)
    id_agent = models.IntegerField()
    jour = models.DateField()
    geom = models.MultiLineStringField(srid=26191, dim=3, null=True, blank=True)
    longueur_conduite_m = models.FloatField(default=0.0)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ass"."statistique_conduite"'

    def __str__(self):
        return f"Stat conduite ASS agent={self.id_agent} jour={self.jour}"


class AssStatistiqueConduiteSegment(models.Model):
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
        db_table = '"ass"."statistique_conduite_segment"'

    def __str__(self):
        return (
            f"Segment conduite ASS stat={self.id_statistique_conduite} "
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


class ListeChoix(models.Model):
    """Source de verite des listes de choix (enumeres) cote SRM.

    L'endpoint /api/srm-field-options/ projette ces lignes au format attendu
    par le mobile (cf. ListeChoixAsFieldOptionSerializer).
    """
    id = models.AutoField(primary_key=True)
    attribut_config_mobile_id = models.IntegerField()
    nom_metier = models.CharField(max_length=50)
    nom_table = models.CharField(max_length=100)
    nom_champ = models.CharField(max_length=100)
    liste_choix_alias = models.CharField(max_length=255, null=True, blank=True)
    liste_choix_valeur = models.CharField(max_length=255, null=True, blank=True)
    liste_choix_ordre = models.IntegerField(null=True, blank=True)
    liste_choix_actif = models.BooleanField(null=True, blank=True)
    contraintes = models.TextField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'liste_choix'


# =====================================================================
#  SCHÃ‰MA EP â€” Eau Potable : PONCTUELS (tables 1 Ã  22)
# =====================================================================

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
    generatrice_supp = models.FloatField(null=True, blank=True)
    ep_profondeur = models.FloatField(null=True, blank=True)
    longueur = models.FloatField(null=True, blank=True)
    largeur = models.FloatField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = '"ep"."ep_regard_point"'

    def __str__(self):
        return f"Regard EP point {self.uuid or self.fid}"

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
    id_agent_crea = models.IntegerField(null=True, blank=True)
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
        db_table = '"asst"."ASS_REGARD"'

    def __str__(self):
        return f"Regard ASS {self.fid}"
