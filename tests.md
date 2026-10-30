# Tests du projet

Les captures d’écran ci-dessous montrent les commandes exécutées et leurs résultats.

## T1 Sans argument ou option inconnue

### Lancement sans argument

![Aide affichée sans argument](image-1.png)

### Option inconnue

![Option inconnue et aide](image-2.png)

![Suite du résultat de l’option inconnue](image-3.png)

### Vérification avec l’option `--stats`

![Résultat de l’option stats](image-4.png)

![Contenu du dossier du projet](image-5.png)

## T2 Ratios dont la somme ne vaut pas 100

La valeur de `TEST_RATIO` a été remplacée provisoirement par `20`, puis remise à `15`.

![Modification temporaire du ratio](image-8.png)

![Message d’erreur obtenu](image-6.png)

![Code de retour obtenu](image-7.png)

La configuration a ensuite été remise à sa valeur initiale.

### Vérification de `MAX_FILES`

La variable a été affichée temporairement dans la fonction `statistiques`, puis la ligne de test a été retirée.

![Valeur affichée pour MAX_FILES](image-9.png)

## T3 Page absente

![Échec de la page absente](image-10.png)

![Résultat du téléchargement des pages](image-11.png)

Le journal contient deux lignes `INFO` et une ligne `ERROR`.

![Vérification du journal](image-12.png)

Serveur arrêté avec `Ctrl+C` : les trois téléchargements échouent. Le serveur est ensuite relancé.

![Résultat avec le serveur arrêté](image-13.png)

## T4 Lien répété, PDF et lien relatif

![Extraction des liens](image-14.png)

![Contenu du fichier des liens](image-15.png)

## T5 Fichier `faux.jpg`

![Fichier faux.jpg refusé](image-18.png)

## T6 Doublon `copie_album.png`

![Doublon détecté](image-19.png)

## T7 `MAX_FILES=3`

![Configuration de MAX_FILES à 3](image-20.png)

![Résultat du téléchargement limité à 3 fichiers](image-21.png)

## T8 Serveur arrêté avec `--all`

![Résultat de --all avec le serveur arrêté](image-22.png)

![Code de retour obtenu](image-23.png)

