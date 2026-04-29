BEGIN;

ALTER TABLE public.objet_photo
    ADD COLUMN IF NOT EXISTS date_prise_reelle TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS date_upload TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS objet_photo_date_prise_reelle_idx
    ON public.objet_photo (date_prise_reelle DESC)
    WHERE date_prise_reelle IS NOT NULL;

CREATE INDEX IF NOT EXISTS objet_photo_date_upload_idx
    ON public.objet_photo (date_upload DESC)
    WHERE date_upload IS NOT NULL;

COMMIT;
