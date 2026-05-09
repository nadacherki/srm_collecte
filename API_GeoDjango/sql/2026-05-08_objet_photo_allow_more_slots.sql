BEGIN;

ALTER TABLE public.objet_photo
    DROP CONSTRAINT IF EXISTS objet_photo_num_photo_check;

ALTER TABLE public.objet_photo
    ADD CONSTRAINT objet_photo_num_photo_check
    CHECK (num_photo >= 1);

COMMIT;
