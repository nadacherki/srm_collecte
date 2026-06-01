"""
Alignement prod du contrat formulaire mobile avec les decisions metier.

Decisions:
- ep.ep_hydrant.codinsee n'est pas obligatoire.
- ep.ep_regard_point.ep_agent est obligatoire mais rempli automatiquement.
- ep.ep_regard_point.generatrice_supp est obligatoire et lie a la profondeur.
- ep.ep_regard_point.retour_terrain est un choix lie a l'anomalie, pas un
  champ obligatoire global.

Les contraintes ep_agent / generatrice_supp sont ajoutees en NOT VALID pour ne
pas injecter de fausses valeurs dans l'historique. Elles bloquent les nouvelles
lignes incoherentes et les mises a jour de lignes incoherentes, sans forcer un
backfill arbitraire sur les anciennes donnees.
"""

from django.db import migrations


FORWARD_SQL = r"""
-- codinsee: non obligatoire selon decision metier.
ALTER TABLE ep.ep_hydrant
    ALTER COLUMN codinsee DROP NOT NULL;

UPDATE public.attribut_config_mobile
   SET nullable = true
 WHERE nom_metier = 'ep'
   AND nom_table = 'ep_hydrant'
   AND nom_champ = 'codinsee';

-- ep_agent: obligatoire, auto-rempli cote mobile.
UPDATE public.attribut_config_mobile
   SET nullable = false,
       valeur_par_defaut = 'ETAFAT'
 WHERE nom_metier = 'ep'
   AND nom_table = 'ep_regard_point'
   AND nom_champ = 'ep_agent';

ALTER TABLE ep.ep_regard_point
    ALTER COLUMN ep_agent SET DEFAULT 'ETAFAT';

ALTER TABLE ep.ep_regard_point
    DROP CONSTRAINT IF EXISTS srm_nn_8884bbcc54df019e;

ALTER TABLE ep.ep_regard_point
    ADD CONSTRAINT srm_nn_8884bbcc54df019e
    CHECK (ep_agent IS NOT NULL AND btrim(ep_agent) <> '') NOT VALID;

-- generatrice_supp: obligatoire, mais pas de backfill arbitraire.
UPDATE public.attribut_config_mobile
   SET nullable = false
 WHERE nom_metier = 'ep'
   AND nom_table = 'ep_regard_point'
   AND nom_champ = 'generatrice_supp';

ALTER TABLE ep.ep_regard_point
    DROP CONSTRAINT IF EXISTS srm_nn_bab851c546748e18;

ALTER TABLE ep.ep_regard_point
    ADD CONSTRAINT srm_nn_bab851c546748e18
    CHECK (generatrice_supp IS NOT NULL) NOT VALID;

-- retour_terrain: lie a l'anomalie, donc facultatif globalement.
UPDATE public.attribut_config_mobile
   SET nullable = true,
       valeur_par_defaut = NULL
 WHERE nom_metier = 'ep'
   AND nom_table = 'ep_regard_point'
   AND nom_champ = 'retour_terrain';

ALTER TABLE ep.ep_regard_point
    ALTER COLUMN retour_terrain DROP NOT NULL;

ALTER TABLE ep.ep_regard_point
    DROP CONSTRAINT IF EXISTS srm_nn_40e4ca0bae139e24;

ALTER TABLE ep.ep_regard_point
    DROP CONSTRAINT IF EXISTS srm_req_40e4ca0bae139e24;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0059_metier_retour_terrain"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
