BEGIN;

ALTER TABLE public.objet_photo
    ADD COLUMN IF NOT EXISTS date_prise_reelle TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS objet_photo_date_prise_reelle_idx
    ON public.objet_photo (date_prise_reelle DESC)
    WHERE date_prise_reelle IS NOT NULL;

COMMIT;
