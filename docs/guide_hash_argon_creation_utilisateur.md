# Guide simple - Creation utilisateur avec hash Argon2

Objectif: modifier la page de creation/modification utilisateur pour que le mot de passe ne soit jamais stocke en clair dans `public.utilisateur`.

La colonne officielle pour le stockage est:

```sql
public.utilisateur.mot_de_passe_hash
```

## 1. Principe

- React affiche un formulaire de creation utilisateur.
- React envoie le mot de passe saisi au backend Django.
- Django genere le hash Argon2.
- Django insere ou met a jour `public.utilisateur.mot_de_passe_hash`.
- Le mot de passe clair n'est jamais stocke.
- Le hash n'est jamais retourne au frontend.

Important: ne pas hasher dans React. Le hash doit etre fait cote Django.

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

## 3. Creation utilisateur cote Django

Utiliser `make_password` avant l'enregistrement:

```python
from django.contrib.auth.hashers import make_password

mot_de_passe_hash = make_password(mot_de_passe_recu)
```

Exemple minimal:

```python
Utilisateur.objects.create(
    login=login,
    nom=nom,
    prenom=prenom,
    role=role,
    actif=True,
    is_deleted=False,
    mot_de_passe_hash=make_password(mot_de_passe_recu),
)
```

## 4. Serializer DRF recommande

Le champ mot de passe doit etre en ecriture seulement:

```python
from django.contrib.auth.hashers import make_password
from rest_framework import serializers

class UtilisateurCreateSerializer(serializers.ModelSerializer):
    mot_de_passe = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = Utilisateur
        fields = [
            'id_user',
            'login',
            'nom',
            'prenom',
            'role',
            'actif',
            'is_deleted',
            'mot_de_passe',
        ]
        read_only_fields = ['id_user']

    def create(self, validated_data):
        mot_de_passe = validated_data.pop('mot_de_passe')
        validated_data['mot_de_passe_hash'] = make_password(mot_de_passe)
        return Utilisateur.objects.create(**validated_data)
```

Ne jamais inclure `mot_de_passe_hash` dans les champs retournes au frontend.

## 5. Modification utilisateur

En modification, ne changer le mot de passe que si un nouveau mot de passe est fourni:

```python
def update(self, instance, validated_data):
    mot_de_passe = validated_data.pop('mot_de_passe', None)

    for field, value in validated_data.items():
        setattr(instance, field, value)

    if mot_de_passe:
        instance.mot_de_passe_hash = make_password(mot_de_passe)

    instance.save()
    return instance
```

Si le champ mot de passe est vide dans la page React, Django garde l'ancien hash.

## 6. Cote React

React envoie le mot de passe saisi uniquement au moment de la creation ou du changement de mot de passe:

```javascript
await fetch("/api/utilisateurs/", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    login,
    nom,
    prenom,
    role,
    actif: true,
    mot_de_passe: password,
  }),
});
```

Pour une modification sans changement de mot de passe, ne pas envoyer `mot_de_passe`, ou l'envoyer vide et l'ignorer cote Django.

## 7. Creation directe en SQL

Si un responsable doit creer un utilisateur directement en SQL, il faut d'abord generer le hash:

```powershell
cd C:\Users\AnasDahou\Desktop\srm_collecte\API_GeoDjango\pprcollecte

..\..\srmenv\Scripts\python.exe manage.py generate_srm_password_hash "MotDePasse"
```

Puis inserer le hash:

```sql
INSERT INTO public.utilisateur (
    login,
    nom,
    prenom,
    role,
    actif,
    is_deleted,
    mot_de_passe_hash
)
VALUES (
    'nouveau.login',
    'Nom',
    'Prenom',
    'agent_mobile',
    true,
    false,
    'HASH_ARGON2_ICI'
);
```

Ne jamais inserer le mot de passe clair dans `mot_de_passe_hash`.

## 8. Reponse API attendue

La reponse ne doit contenir que les informations utiles:

```json
{
  "id_user": 12,
  "login": "nouveau.login",
  "nom": "Nom",
  "prenom": "Prenom",
  "role": "agent_mobile",
  "actif": true,
  "is_deleted": false
}
```

Ne jamais retourner:

- `mot_de_passe`
- `mot_de_passe_hash`
- le hash Argon2

## 9. Regles de securite

- Utiliser HTTPS en production.
- Hasher uniquement cote Django.
- Ne jamais stocker le mot de passe en clair.
- Ne jamais logger le mot de passe.
- Ne jamais logger le hash.
- Ne jamais exposer `mot_de_passe_hash` dans les serializers.
- En modification, ne remplacer le hash que si un nouveau mot de passe est fourni.
- Refuser la creation si le mot de passe est vide ou trop faible.
