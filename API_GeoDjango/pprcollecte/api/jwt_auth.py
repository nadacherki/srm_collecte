"""Authentification JWT custom pour SRM Collecte.

Le projet n'utilise PAS `django.contrib.auth` (le modele Utilisateur est
managed=False sur une table externe). Pour eviter d'introduire le contrib
auth juste pour `simplejwt`, on code un JWT minimal sur PyJWT.

Format des tokens (HS256, signe par DJANGO_SECRET_KEY) :
    {
        "user_id": <int>,         # id_user de la table public.utilisateur
        "login": "<str>",         # pour les logs et le debug
        "role": "<str>",
        "type": "access" | "refresh",
        "iat": <epoch>,
        "exp": <epoch>,
    }

Le header HTTP attendu est `Authorization: Bearer <access_token>`.
Le refresh se fait sur POST /api/auth/refresh/ avec le refresh token.
"""

from __future__ import annotations

import datetime
import logging
from typing import Optional, Tuple

import jwt
from django.conf import settings
from rest_framework import authentication, exceptions

from .models import Utilisateur


logger = logging.getLogger(__name__)


def _access_lifetime() -> datetime.timedelta:
    minutes = int(getattr(settings, "JWT_ACCESS_LIFETIME_MINUTES", 15))
    return datetime.timedelta(minutes=minutes)


def _refresh_lifetime() -> datetime.timedelta:
    days = int(getattr(settings, "JWT_REFRESH_LIFETIME_DAYS", 7))
    return datetime.timedelta(days=days)


def _now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


def _build_token(
    *,
    user: Utilisateur,
    token_type: str,
    lifetime: datetime.timedelta,
) -> str:
    now = _now()
    payload = {
        "user_id": user.id_user,
        "login": user.login,
        "role": user.role,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + lifetime).timestamp()),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def generate_token_pair(user: Utilisateur) -> dict:
    """Genere un couple (access, refresh) signe pour l'utilisateur donne."""
    return {
        "access": _build_token(
            user=user, token_type="access", lifetime=_access_lifetime()
        ),
        "refresh": _build_token(
            user=user, token_type="refresh", lifetime=_refresh_lifetime()
        ),
        "access_expires_in": int(_access_lifetime().total_seconds()),
        "refresh_expires_in": int(_refresh_lifetime().total_seconds()),
        "token_type": "Bearer",
    }


def decode_token(token: str, *, expected_type: str = "access") -> dict:
    """Decode et valide un JWT. Leve AuthenticationFailed sur erreur."""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=["HS256"],
            options={"require": ["exp", "iat", "user_id", "type"]},
        )
    except jwt.ExpiredSignatureError:
        raise exceptions.AuthenticationFailed("Token expire.")
    except jwt.InvalidTokenError as exc:
        raise exceptions.AuthenticationFailed(f"Token invalide : {exc}")
    if payload.get("type") != expected_type:
        raise exceptions.AuthenticationFailed(
            f"Type de token incorrect (attendu : {expected_type})."
        )
    return payload


def refresh_access_token(refresh_token: str) -> dict:
    """Genere un nouvel access token a partir d'un refresh valide."""
    payload = decode_token(refresh_token, expected_type="refresh")
    try:
        user = Utilisateur.objects.get(id_user=payload["user_id"])
    except Utilisateur.DoesNotExist:
        raise exceptions.AuthenticationFailed("Utilisateur introuvable.")
    if not user.actif or user.is_deleted:
        raise exceptions.AuthenticationFailed("Compte inactif ou supprime.")
    return {
        "access": _build_token(
            user=user, token_type="access", lifetime=_access_lifetime()
        ),
        "access_expires_in": int(_access_lifetime().total_seconds()),
        "token_type": "Bearer",
    }


class SrmJWTAuthentication(authentication.BaseAuthentication):
    """Authentication class DRF.

    Lit le header `Authorization: Bearer <access_token>`, valide la
    signature et l'expiration, puis attache l'instance Utilisateur a
    `request.user`. Si pas de header, retourne None (la decision
    autoriser/refuser revient aux permission_classes en aval).
    """

    keyword = "Bearer"

    def authenticate(
        self, request
    ) -> Optional[Tuple[Utilisateur, dict]]:
        auth = authentication.get_authorization_header(request)
        if not auth:
            return None
        parts = auth.split()
        if len(parts) != 2 or parts[0].lower() != self.keyword.lower().encode():
            return None
        token = parts[1].decode("utf-8", errors="strict")
        payload = decode_token(token, expected_type="access")
        try:
            user = Utilisateur.objects.get(id_user=payload["user_id"])
        except Utilisateur.DoesNotExist:
            raise exceptions.AuthenticationFailed("Utilisateur introuvable.")
        if not user.actif or user.is_deleted:
            raise exceptions.AuthenticationFailed("Compte inactif ou supprime.")
        # Convention DRF : injecter is_authenticated=True comme attribut
        # dynamique (Utilisateur n'herite pas d'AbstractBaseUser).
        user.is_authenticated = True
        return (user, payload)

    def authenticate_header(self, request) -> str:
        return self.keyword
