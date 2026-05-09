BEGIN;

ALTER TABLE public.objet_photo
    DROP CONSTRAINT IF EXISTS objet_photo_num_photo_check;

ALTER TABLE public.objet_photo
    ADD CONSTRAINT objet_photo_num_photo_check
    CHECK (num_photo >= 1);

CREATE OR REPLACE FUNCTION public.objet_photo_prevent_new_extra_slots()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF current_setting('app.allow_legacy_photo_slots', true) = 'on' THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' AND NEW.num_photo > 4 THEN
        RAISE EXCEPTION
            'Maximum 4 photos autorise pour les nouvelles donnees (num_photo=%). Bypass maintenance: SET LOCAL app.allow_legacy_photo_slots=on',
            NEW.num_photo
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.num_photo > 4
       AND NEW.num_photo IS DISTINCT FROM OLD.num_photo THEN
        RAISE EXCEPTION
            'Maximum 4 photos autorise pour les nouvelles donnees (num_photo=%). Les anciennes photos >4 restent conservees si leur num_photo ne change pas',
            NEW.num_photo
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_objet_photo_prevent_new_extra_slots
    ON public.objet_photo;

CREATE TRIGGER trg_objet_photo_prevent_new_extra_slots
BEFORE INSERT OR UPDATE OF num_photo
ON public.objet_photo
FOR EACH ROW
EXECUTE FUNCTION public.objet_photo_prevent_new_extra_slots();

COMMIT;
