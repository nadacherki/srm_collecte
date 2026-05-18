"""Socle de tests automatises du perimetre securite (P0/P1/P2).

Tous DB-free (SimpleTestCase / APIRequestFactory) -> deterministes et
rapides en CI. Couvre : JWT, redaction des logs, machine a etats
anomalie, resolution d'identite (anti X-User-Id), scope admin.

Lancer : python manage.py test api.test_security
"""

import logging
import time
import types

import jwt
from django.test import SimpleTestCase, override_settings
from rest_framework import exceptions
from rest_framework.test import APIRequestFactory

from .jwt_auth import generate_token_pair, decode_token
from .logging_filters import SensitiveDataFilter
from .serializers import InterventionAnomalieTerrainSerializer
from . import views


def _fake_user(id_user=17, login="nada", role="admin"):
    return types.SimpleNamespace(id_user=id_user, login=login, role=role)


@override_settings(SECRET_KEY="unit-test-secret-key-0123456789abcdef0123456789abcdef")
class JwtAuthTests(SimpleTestCase):
    def test_roundtrip_access_claims(self):
        pair = generate_token_pair(_fake_user())
        payload = decode_token(pair["access"], expected_type="access")
        self.assertEqual(payload["user_id"], 17)
        self.assertEqual(payload["login"], "nada")
        self.assertEqual(payload["type"], "access")

    def test_access_rejected_as_refresh(self):
        pair = generate_token_pair(_fake_user())
        with self.assertRaises(exceptions.AuthenticationFailed):
            decode_token(pair["access"], expected_type="refresh")

    def test_tampered_signature_rejected(self):
        pair = generate_token_pair(_fake_user())
        tampered = pair["access"][:-3] + "AAA"
        with self.assertRaises(exceptions.AuthenticationFailed):
            decode_token(tampered, expected_type="access")

    def test_foreign_secret_rejected(self):
        # Token signe avec une autre cle -> refuse.
        forged = jwt.encode(
            {"user_id": 1, "type": "access", "iat": int(time.time()),
             "exp": int(time.time()) + 60, "login": "x", "role": "admin"},
            "attacker-secret",
            algorithm="HS256",
        )
        with self.assertRaises(exceptions.AuthenticationFailed):
            decode_token(forged, expected_type="access")

    def test_expired_token_rejected(self):
        now = int(time.time())
        expired = jwt.encode(
            {"user_id": 1, "type": "access", "iat": now - 120,
             "exp": now - 60, "login": "x", "role": "admin"},
            "unit-test-secret-key-0123456789abcdef0123456789abcdef",
            algorithm="HS256",
        )
        with self.assertRaises(exceptions.AuthenticationFailed):
            decode_token(expired, expected_type="access")


class SensitiveDataFilterTests(SimpleTestCase):
    def setUp(self):
        self.f = SensitiveDataFilter()

    def _msg(self, raw):
        rec = logging.LogRecord("t", logging.INFO, "", 0, raw, None, None)
        self.f.filter(rec)
        return rec.getMessage()

    def test_bearer_redacted(self):
        out = self._msg("Authorization: Bearer eyJhbGciOiJI.payload.sig")
        self.assertNotIn("eyJhbGciOiJI", out)
        self.assertIn("REDACTED", out)

    def test_cookie_redacted(self):
        self.assertIn("REDACTED", self._msg('Cookie: sessionid=topsecret'))

    def test_x_user_id_masked(self):
        self.assertNotIn("=17", self._msg("X-User-Id=17 path=/api/x"))

    def test_password_redacted(self):
        out = self._msg('payload mot_de_passe=Hunter2 fin')
        self.assertNotIn("Hunter2", out)


class AnomalieStateMachineTests(SimpleTestCase):
    def setUp(self):
        self.s = InterventionAnomalieTerrainSerializer()

    def _instance(self, statut):
        inst = types.SimpleNamespace(
            statut=statut, etat_terrain=None,
            commentaire_terrain=None, id_user_terrain=None,
        )
        inst.save = lambda *a, **k: None
        return inst

    def test_rank_is_monotone(self):
        r = self.s._rank
        self.assertLess(r("signale"), r("terrain_traite"))
        self.assertLess(r("terrain_traite"), r("cloture"))
        self.assertEqual(r("zzz-inconnu"), max(self.s._STATUT_RANK.values()))

    def test_forward_transition_allowed(self):
        inst = self._instance("signale")
        self.s.update(inst, {"etat_terrain": "traite"})
        self.assertEqual(inst.statut, "terrain_traite")

    def test_terminal_state_locked(self):
        inst = self._instance("cloture")
        with self.assertRaises(exceptions.ValidationError):
            self.s.update(inst, {"etat_terrain": "traite"})

    def test_no_regression_on_en_attente(self):
        # etat_terrain=en_attente ne doit pas retrograder un statut avance.
        inst = self._instance("terrain_traite")
        self.s.update(inst, {"etat_terrain": "en_attente"})
        self.assertEqual(inst.statut, "terrain_traite")


class IdentityResolutionTests(SimpleTestCase):
    """Le shim X-User-Id est supprime : seul le JWT (request.user)
    identifie l'agent. Un header X-User-Id force doit etre ignore."""

    def setUp(self):
        self.factory = APIRequestFactory()

    def test_jwt_user_resolved(self):
        req = self.factory.get("/api/x")
        req.user = _fake_user(id_user=42)
        self.assertEqual(views._resolve_request_user_id(req), 42)

    def test_spoofed_x_user_id_ignored(self):
        req = self.factory.get("/api/x", HTTP_X_USER_ID="1")
        req.user = None
        self.assertIsNone(views._resolve_request_user_id(req))

    def test_no_identity_returns_none(self):
        req = self.factory.get("/api/x")
        req.user = None
        self.assertIsNone(views._resolve_request_user_id(req))

    def test_admin_role_detected(self):
        for role, expected in (
            ("admin", True), ("superadmin", True),
            ("editeur_terrain", False), ("project_manager", False),
            (None, False),
        ):
            req = self.factory.get("/api/x")
            req.user = _fake_user(role=role)
            self.assertEqual(views._request_is_admin(req), expected, role)
