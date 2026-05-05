# Guide simple - Login avec hash Argon2

Objectif: remplacer l'ancienne verification en texte clair par une verification securisee avec un hash Argon2 stocke dans `public.utilisateur`.

## 1. Principe

- React envoie le `login` et le mot de passe saisi au backend Django.
- Django ne compare pas le mot de passe avec du texte clair.
- Django compare le mot de passe recu avec le hash stocke dans:

```sql
public.utilisateur.mot_de_passe_hash
```

Le hash ne doit jamais etre retourne au frontend.

## 2. Configuration Django

Dans `settings.py`, verifier que Argon2 est active:

```python
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.Argon2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher',
    'django.contrib.auth.hashers.BCryptSHA256PasswordHasher',
]
```

Installer le support Argon2 si necessaire:

```powershell
pip install argon2-cffi
```

## 3. Generer un hash

Depuis le dossier backend:

```powershell
cd C:\Users\AnasDahou\Desktop\srm_collecte\API_GeoDjango\pprcollecte

..\..\srmenv\Scripts\python.exe manage.py generate_srm_password_hash "MotDePasse"
```

La commande retourne un hash de ce type:

```text
argon2$argon2id$v=19$m=102400,t=2,p=8$...
```

## 4. Mettre a jour la table utilisateur

Exemple:

```sql
UPDATE public.utilisateur
SET mot_de_passe_hash = 'HASH_ARGON2_ICI'
WHERE login = 'anas';
```

Important:

- Ne pas stocker le mot de passe en clair.
- Ne pas utiliser une ancienne colonne `mot_de_passe`.
- La colonne officielle est `mot_de_passe_hash`.

## 5. Verification dans Django

Dans la vue login, utiliser `check_password`:

```python
from django.contrib.auth.hashers import check_password

mot_de_passe_valide = check_password(
    mot_de_passe_recu,
    user.mot_de_passe_hash,
)
```

La logique minimale:

```python
if not user.actif:
    refuser_login

if user.is_deleted:
    refuser_login

if not user.mot_de_passe_hash:
    refuser_login

if not check_password(mot_de_passe_recu, user.mot_de_passe_hash):
    refuser_login
```

## 6. Cote React

React envoie uniquement le login et le mot de passe saisi:

```javascript
await fetch("/api/login/", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    login,
    mot_de_passe: password,
  }),
});
```

React ne doit jamais recevoir ni afficher:

- `mot_de_passe_hash`
- le hash Argon2
- le mot de passe stocke

## 7. Reponse attendue du backend

En cas de succes, retourner seulement les informations utiles:

```json
{
  "success": true,
  "user": {
    "id_user": 1,
    "login": "anas",
    "nom": "Nom",
    "prenom": "Prenom",
    "role": "admin"
  }
}
```

En cas d'erreur:

```json
{
  "error": "Login ou mot de passe incorrect"
}
```

## 8. Regles de securite

- Utiliser HTTPS en production.
- Ne jamais exposer `mot_de_passe_hash` dans les serializers.
- Ne jamais logger le mot de passe.
- Ne jamais logger le hash.
- Desactiver le login si `actif = false`.
- Refuser le login si `is_deleted = true`.
- Generer les nouveaux mots de passe uniquement avec Django/Argon2.
