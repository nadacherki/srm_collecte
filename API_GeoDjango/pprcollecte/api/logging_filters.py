"""Filtre de logging : caviarde les secrets dans les messages de log.

Empeche qu'un JWT, un cookie de session ou un header X-User-Id se
retrouvent en clair dans les logs (fichier, stdout, agregateur). S'applique
a tous les handlers via la config LOGGING.
"""

import logging
import re


# Motifs de secrets a masquer. Compiles une fois.
_PATTERNS = [
    # Authorization: Bearer <token>  /  "Authorization": "Bearer ..."
    (re.compile(r'(?i)(authorization["\']?\s*[:=]\s*["\']?\s*bearer\s+)[^\s"\',]+'),
     r'\1***REDACTED***'),
    # Bearer eyJ... isole (token JWT)
    (re.compile(r'(?i)\bbearer\s+[A-Za-z0-9._-]{20,}'),
     'Bearer ***REDACTED***'),
    # JWT brut (3 segments base64url) hors contexte
    (re.compile(r'\beyJ[A-Za-z0-9._-]{20,}\b'),
     '***JWT_REDACTED***'),
    # Cookie / Set-Cookie
    (re.compile(r'(?i)(cookie["\']?\s*[:=]\s*["\']?)[^\r\n"\']+'),
     r'\1***REDACTED***'),
    # X-User-Id (header legacy, ne doit pas fuiter ni etre trace)
    (re.compile(r'(?i)(x[-_]user[-_]id["\']?\s*[:=]\s*["\']?)\d+'),
     r'\1***'),
    # mot_de_passe / password en clair dans un payload logge
    (re.compile(r'(?i)("?(?:mot_de_passe|password)"?\s*[:=]\s*"?)[^\s"\',}]+'),
     r'\1***REDACTED***'),
]


class SensitiveDataFilter(logging.Filter):
    """Reecrit `record.msg`/`record.args` pour masquer les secrets."""

    def _scrub(self, value):
        if not isinstance(value, str):
            return value
        for pattern, repl in _PATTERNS:
            value = pattern.sub(repl, value)
        return value

    def filter(self, record):
        try:
            if isinstance(record.msg, str):
                record.msg = self._scrub(record.msg)
            if record.args:
                if isinstance(record.args, dict):
                    record.args = {
                        k: self._scrub(v) for k, v in record.args.items()
                    }
                else:
                    record.args = tuple(
                        self._scrub(a) for a in record.args
                    )
        except Exception:
            # Un filtre de log ne doit jamais casser l'application.
            pass
        return True
