from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase

from .serializers import PhotoUploadSerializer


class PhotoUploadSerializerTests(SimpleTestCase):
    def _payload(self, uploaded_file):
        return {
            "schema_name": "ep",
            "table_name": "ep_vanne",
            "uuid_objet": "uuid-photo",
            "photo_slot": 1,
            "file": uploaded_file,
        }

    def test_accepts_valid_small_jpg(self):
        uploaded_file = SimpleUploadedFile(
            "photo.jpg",
            b"\xff\xd8\xff\x00\x01\x02\xff\xd9",
            content_type="image/jpeg",
        )
        serializer = PhotoUploadSerializer(data=self._payload(uploaded_file))

        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data["photo_context"], "collecte_initiale")

    def test_accepts_contextual_anomaly_photo(self):
        uploaded_file = SimpleUploadedFile(
            "photo.jpg",
            b"\xff\xd8\xff\x00\x01\x02\xff\xd9",
            content_type="image/jpeg",
        )
        payload = self._payload(uploaded_file)
        payload["photo_context"] = "anomalie_avant"
        serializer = PhotoUploadSerializer(data=payload)

        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data["photo_context"], "anomalie_avant")

    def test_rejects_unknown_photo_context(self):
        uploaded_file = SimpleUploadedFile(
            "photo.jpg",
            b"\xff\xd8\xff\x00\x01\x02\xff\xd9",
            content_type="image/jpeg",
        )
        payload = self._payload(uploaded_file)
        payload["photo_context"] = "slot_libre"
        serializer = PhotoUploadSerializer(data=payload)

        self.assertFalse(serializer.is_valid())
        self.assertIn("photo_context", serializer.errors)

    def test_rejects_truncated_jpg(self):
        uploaded_file = SimpleUploadedFile(
            "photo.jpg",
            b"\xff\xd8\xff\x00\x01\x02",
            content_type="image/jpeg",
        )
        serializer = PhotoUploadSerializer(data=self._payload(uploaded_file))

        self.assertFalse(serializer.is_valid())
        self.assertIn("file", serializer.errors)

    def test_rejects_oversized_photo(self):
        payload = (
            b"\xff\xd8\xff"
            + (b"\x00" * (PhotoUploadSerializer.max_photo_bytes + 1))
            + b"\xff\xd9"
        )
        uploaded_file = SimpleUploadedFile(
            "photo.jpg",
            payload,
            content_type="image/jpeg",
        )
        serializer = PhotoUploadSerializer(data=self._payload(uploaded_file))

        self.assertFalse(serializer.is_valid())
        self.assertIn("file", serializer.errors)
