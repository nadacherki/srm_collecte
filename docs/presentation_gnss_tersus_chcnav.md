# Application SRM Collecte : compatibilite GNSS double recepteur (Tersus / CHCNAV)

> Document de cadrage destine au Product Management. Objectif : expliquer
> simplement pourquoi l'application gere deux familles de recepteurs GPS de
> precision, comment elle calcule la coordonnee finale, et ce que fait
> concretement l'agent sur le terrain. Sert de base a une presentation
> visuelle.

---

## 1. Le principe : un recepteur de reference, une bascule possible

L'application de collecte se connecte a un recepteur GNSS de precision
(le boitier GPS centimetrique que l'agent porte sur sa canne). Sur le
marche, deux familles de materiel sont utilisees, chacune avec son propre
logiciel constructeur de terrain :

| Famille de recepteur | Logiciel constructeur associe |
|----------------------|-------------------------------|
| **Tersus** (modele OSCAR)     | **Nuwa**     |
| **CHCNAV**                    | **LandStar** |

**Choix par defaut de l'application : Tersus OSCAR.** C'est le materiel
reellement deploye sur le terrain, donc l'app demarre directement configuree
pour lui, sans manipulation.

**Bascule possible :** si l'agent travaille avec un recepteur CHCNAV, il le
selectionne dans l'application (un simple choix "Marque du recepteur :
Tersus / CHCNAV"). L'application adapte alors automatiquement tous ses
calculs au comportement CHCNAV.

> A retenir : une seule application, compatible avec les deux ecosystemes
> terrain. L'agent garde son materiel et ses habitudes ; l'app s'adapte.

---

## 2. Pourquoi deux cas separes (Nuwa vs LandStar) ont du etre developpes

A premiere vue, les deux familles font la meme chose : transformer un signal
satellite en une coordonnee precise (X, Y, et altitude Z) dans le systeme
marocain. **Le coeur du calcul est identique.** Mais il existe des differences
concretes qui imposent de traiter chaque marque a part, sinon on introduit une
erreur de quelques centimetres sur l'altitude, invisible mais reelle.

### Les points de difference cles

| Sujet | Tersus (Nuwa) | CHCNAV (LandStar) |
|-------|---------------|-------------------|
| **Modeles d'antenne** | OSCAR, AX3702, LUKA, TS20... | i89, X16... |
| **Constantes geometriques de l'antenne** | propres a Tersus | propres a CHCNAV |
| **Regle de calcul de la hauteur** | une convention | une autre convention |

**L'analogie la plus simple :** c'est comme deux regles graduees dont le zero
n'est pas place au meme endroit. Mesurer avec la regle Tersus en appliquant la
convention CHCNAV (ou l'inverse) donne un resultat decale de quelques
centimetres. Pour le metier (reseaux d'eau, profondeurs, raccordements), cette
precision compte.

**Exemple concret :** pour une meme hauteur de canne saisie (par exemple
1,80 m), la facon dont chaque marque ramene la position de l'antenne vers le
point au sol n'est pas la meme. Si on appliquait la formule d'une marque aux
donnees de l'autre, l'altitude serait fausse de facon systematique.

> C'est pour cela que l'application embarque deux "moteurs de calcul" distincts,
> chacun fidele a sa marque, plus un catalogue d'antennes dedie par marque. Le
> choix de la marque dans l'app declenche automatiquement le bon moteur.

Ces conventions n'ont pas ete inventees : elles ont ete verifiees directement
dans les logiciels constructeurs (Nuwa et LandStar) pour garantir que notre
application produit exactement le meme resultat que l'outil d'origine.

---

## 3. Le parcours de l'agent sur le terrain, etape par etape

Le travail se fait en deux temps : une **preparation** sur le carnet du
constructeur (Nuwa ou LandStar), puis la **collecte** dans notre application.

### Phase A : preparation (sur le carnet constructeur)

1. L'agent allume la **base** (le recepteur fixe) et le **rover** (le
   recepteur mobile sur la canne).
2. Il installe la base sur un **point connu** et saisit ses coordonnees
   officielles, plus la hauteur de la base.
3. Il configure le **rover** (notamment la hauteur de sa canne).

> A ce stade, la base et le rover dialoguent par radio : la base "corrige"
> en permanence la position du rover pour atteindre une precision
> centimetrique.

### Phase B : collecte (dans notre application)

4. L'agent ouvre notre application et se connecte au rover en **Bluetooth**.
5. La marque est deja sur **Tersus OSCAR** par defaut (ou il bascule en
   CHCNAV). Il saisit la **hauteur de sa canne** (par exemple 1,80 m).
6. Il se deplace et collecte ses points. A chaque mesure, l'application
   calcule et enregistre la coordonnee finale.

### Le voyage d'une coordonnee (le flux, etape par etape)

```
   [Satellites GPS]
          │  signaux
          ▼
   [Rover sur la canne]  ◄───── corrections radio ───── [Base sur point connu]
          │  position de l'antenne (precision cm)
          │  envoyee par Bluetooth
          ▼
   [Notre application]
          │
          ├─ 1. Recoit la position mondiale (latitude / longitude / altitude)
          │
          ├─ 2. La convertit dans le systeme marocain (Merchich, X / Y / Z)
          │
          ├─ 3. Retranche la hauteur de la canne pour obtenir le point AU SOL
          │      (selon la convention de la marque selectionnee)
          │
          └─ 4. Enregistre la coordonnee finale du point collecte
```

**Point important explique simplement :** le rover ne connait que la position
de son antenne, en haut de la canne. Pour obtenir le point reel au sol (la
pointe de la canne), l'application retranche la hauteur de la canne. C'est une
operation locale au rover, qui reste exacte quelle que soit la situation du
terrain : point en hauteur, point en contrebas, forte pente. La seule
condition pratique est que **la canne soit tenue droite** (a la verticale).

> Resultat attendu : la coordonnee obtenue dans notre application est la meme
> que celle qu'aurait donnee le carnet constructeur. Verifie et valide.

---

## 4. Conclusion

- **Une seule application, deux ecosystemes.** L'app prend Tersus OSCAR comme
  reference par defaut et bascule en CHCNAV sur simple selection. L'agent ne
  change pas son materiel ni ses habitudes.
- **Le meme resultat que l'outil constructeur.** Les calculs ont ete alignes
  marque par marque pour produire des coordonnees identiques a celles de Nuwa
  et de LandStar. La precision metier est preservee.
- **Robuste sur le terrain.** Le calcul de l'altitude reste juste dans toutes
  les situations de relief, du moment que la canne est verticale.
- **Benefice metier.** L'application reprend la chaine de mesure professionnelle
  des recepteurs de precision et l'integre directement dans la collecte SRM,
  sans intermediaire et sans perte de qualite.

> En une phrase : l'application parle nativement le langage des deux recepteurs
> GPS de precision du terrain, et restitue la coordonnee marocaine exacte, prete
> a etre collectee.
