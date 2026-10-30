# Projet B-Constitution d’un dataset multimédia

## Le but

Le script `media_dataset_builder.sh` récupère les médias du site de test local, les classe par type, vérifie leur contenu, élimine les doublons, crée un index CSV et répartit les fichiers entre `train`, `val` et `test`.

## Lancement du serveur

Depuis le dossier du projet, démarrer le serveur local :

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory site_test
```

Laisser ce terminal ouvert pendant l’utilisation du script. Les pages sont accessibles aux adresses `http://127.0.0.1:8000/page1.html` et `http://127.0.0.1:8000/gallery.html`.

## Options

Lancer les commandes depuis un autre terminal, dans le dossier du projet.

Avant de pouvoir exécuter le script, lui donner l’autorisation d’exécution avec cette commande :

```bash
chmod +x media_dataset_builder.sh
```

- `./media_dataset_builder.sh --fetch-html` : télécharge les pages HTML.
- `./media_dataset_builder.sh --extract-links` : extrait les liens des médias.
- `./media_dataset_builder.sh --download-media` : télécharge, vérifie et classe les médias, puis ignore les doublons.
- `./media_dataset_builder.sh --build-index` : crée l’index CSV.
- `./media_dataset_builder.sh --prepare-dataset` : répartit les fichiers entre `train`, `val` et `test`.
- `./media_dataset_builder.sh --stats` : affiche les statistiques.
- `./media_dataset_builder.sh --all` : enchaîne toutes les étapes.
- `./media_dataset_builder.sh --help` : affiche l’aide.

## Site de test et pièges

Le site contient deux pages HTML, des images et un son. Il comprend aussi plusieurs cas de test :

- `copie_album.png` est une copie exacte de `album.png` pour tester la détection des doublons ;
- `faux.jpg` contient du texte malgré son extension d’image, pour tester la vérification du type réel ;
- `cours.pdf` doit être ignoré, car ce n’est pas un média pris en charge ;
- `absente.png` est référencé, mais n’existe pas, pour tester la gestion des erreurs ;
- un lien relatif doit être ignoré ;
- `logo.png` apparaît plusieurs fois pour tester la suppression des liens répétés.

## Limites

Le script est destiné au site de test local `127.0.0.1` et ne doit pas être utilisé sur un site réel sans autorisation. Il reconnaît uniquement les extensions multimédias prévues dans le script. Le découpage dépend du nombre de fichiers valides, des ratios configurés et du mélange aléatoire.
