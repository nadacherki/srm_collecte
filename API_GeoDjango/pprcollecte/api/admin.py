from django.contrib import admin

from .models import ObjetPhoto


@admin.register(ObjetPhoto)
class ObjetPhotoAdmin(admin.ModelAdmin):
    list_display = (
        'id_photo',
        'nom_schema',
        'nom_table',
        'uuid_objet',
        'contexte_photo',
        'id_intervention_anomalie',
        'num_photo',
        'date_upload',
    )
    list_filter = (
        'nom_schema',
        'nom_table',
        'contexte_photo',
        'id_intervention_anomalie',
        'actif',
    )
    search_fields = ('uuid_objet', 'chemin_relatif', 'nom_fichier')
    ordering = (
        'nom_schema',
        'nom_table',
        'uuid_objet',
        'contexte_photo',
        'id_intervention_anomalie',
        'num_photo',
    )
    readonly_fields = ('id_photo', 'date_upload')

    def has_add_permission(self, request):
        return False

    def has_view_permission(self, request, obj=None):
        return super().has_view_permission(request, obj)

    def has_change_permission(self, request, obj=None):
        return obj is None and super().has_change_permission(request, obj)

    def has_delete_permission(self, request, obj=None):
        return False
