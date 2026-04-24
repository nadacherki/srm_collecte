from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection


class Command(BaseCommand):
    help = (
        "Synchronise la taille du carre ep.regard_miroir depuis "
        "REGARD_MIROIR_SQUARE_SIZE_METERS et recalcule les miroirs existants."
    )

    def handle(self, *args, **options):
        raw_size = getattr(settings, 'REGARD_MIROIR_SQUARE_SIZE_METERS', 4.0)
        try:
            size_m = float(raw_size)
        except (TypeError, ValueError) as exc:
            raise CommandError(
                'REGARD_MIROIR_SQUARE_SIZE_METERS doit etre numerique.'
            ) from exc

        if size_m <= 0:
            raise CommandError(
                'REGARD_MIROIR_SQUARE_SIZE_METERS doit etre strictement positif.'
            )

        size_literal = f'{size_m:.6f}'

        with connection.cursor() as cursor:
            cursor.execute(
                f"""
                CREATE OR REPLACE FUNCTION public.regard_miroir_square_size_m()
                RETURNS double precision
                LANGUAGE sql
                AS $$
                    SELECT {size_literal}::double precision
                $$;
                """
            )
            cursor.execute(
                """
                DO $$
                BEGIN
                    IF EXISTS (
                        SELECT 1
                        FROM information_schema.tables
                        WHERE table_schema = 'ep'
                          AND table_name = 'regard_miroir'
                    ) AND EXISTS (
                        SELECT 1
                        FROM information_schema.tables
                        WHERE table_schema = 'ep'
                          AND table_name = 'regard'
                    ) THEN
                        UPDATE ep.regard
                        SET geom = ST_SetSRID(
                            ST_MakePoint(
                                ep_coor_x,
                                ep_coor_y,
                                COALESCE(ep_coor_z, 0.0)
                            ),
                            26191
                        )
                        WHERE (geom IS NULL OR ST_IsEmpty(geom))
                          AND ep_coor_x IS NOT NULL
                          AND ep_coor_y IS NOT NULL;

                        UPDATE ep.regard_miroir AS miroir
                        SET geom = public.build_regard_miroir_geom(
                            CASE
                                WHEN source.geom IS NOT NULL
                                     AND NOT ST_IsEmpty(source.geom)
                                    THEN source.geom
                                WHEN source.ep_coor_x IS NOT NULL
                                     AND source.ep_coor_y IS NOT NULL
                                    THEN ST_SetSRID(
                                        ST_MakePoint(
                                            source.ep_coor_x,
                                            source.ep_coor_y,
                                            COALESCE(source.ep_coor_z, 0.0)
                                        ),
                                        26191
                                    )
                                ELSE NULL
                            END
                        )
                        FROM ep.regard AS source
                        WHERE miroir.fid_regard_source = source.fid;
                    END IF;
                END;
                $$;
                """
            )

        self.stdout.write(
            self.style.SUCCESS(
                f'Taille regard_miroir synchronisee: {size_literal} m'
            )
        )
