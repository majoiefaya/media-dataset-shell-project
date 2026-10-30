#!/bin/bash

DIR=$(cd "$(dirname "$0")" && pwd)
LOG="$DIR/logs/scraping.log"
SETTINGS="$DIR/config/settings.conf"
URLS="$DIR/config/urls.conf"

afficher_aide() {
    echo "Usage : $0 OPTION"
    echo "  --fetch-html       télécharger les pages de config/urls.conf"
    echo "  --extract-links    extraire les liens multimédia"
    echo "  --download-media   télécharger et classer les médias"
    echo "  --build-index      créer index/media_index.csv"
    echo "  --prepare-dataset répartir en train/val/test"
    echo "  --stats            créer le rapport de statistiques"
    echo "  --all              tout faire dans l'ordre"
    echo "  --help             afficher cette aide"
}

journaliser() {
    echo "[$(date '+%F %T')] $1 $2" >> "$LOG"
}

initialiser() {
    mkdir -p "$DIR/raw_html" "$DIR/index" "$DIR/logs" "$DIR/reports"
    mkdir -p "$DIR/downloads/images" "$DIR/downloads/videos"
    mkdir -p "$DIR/downloads/audio" "$DIR/downloads/others"
    mkdir -p "$DIR/dataset/train" "$DIR/dataset/val" "$DIR/dataset/test"
}

recuperer_html() {
    local n=0
    local url
    local fichier

    while IFS= read -r url || [ -n "$url" ]; do
        if [ -z "$url" ] || [ "${url:0:1}" = "#" ]; then
            continue
        fi

        n=$((n + 1))
        fichier="$DIR/raw_html/page_$(printf '%03d' "$n").html"

        if curl -sf --max-time 15 -o "$fichier" "$url"; then
            echo -e "\e[32m[OK]\e[0m $url"
            journaliser INFO "Page téléchargée : $(basename "$fichier")"
        else
            echo -e "\e[31m[ERREUR]\e[0m $url"
            journaliser ERROR "Échec du téléchargement : $url"
            rm -f "$fichier"
        fi

        sleep "$REQUEST_DELAY"
    done < "$URLS"
}

extraire_liens() {
    local liens="$DIR/index/media_links.txt"
    local motif='https?://[^" ]+\.(jpg|jpeg|png|gif|webp|mp4|webm|ogv|mp3|wav|ogg)'

    grep -Eohi "$motif" "$DIR"/raw_html/*.html 2>/dev/null \
        | sort -u > "$liens"

    local nb
    nb=$(wc -l < "$liens")

    if [ "$nb" -eq 0 ]; then
        echo "Aucun lien multimédia trouvé"
        journaliser ERROR "Aucun lien multimédia trouvé"
        return 1
    fi

    echo "$nb liens multimédia extraits dans index/media_links.txt"
    journaliser INFO "$nb liens multimédia extraits"
}

telecharger_medias() {
    local url
    local nom
    local ext
    local dossier
    local attendu
    local cible
    local type
    local somme
    local nb=0

    local empreintes="$DIR/index/sha256.txt"
    local sources="$DIR/index/sources.txt"

    > "$empreintes"
    > "$sources"

    while IFS= read -r url; do
        if [ "$nb" -ge "$MAX_FILES" ]; then
            break
        fi

        nom=$(basename "$url")
        ext=$(echo "${nom##*.}" | tr '[:upper:]' '[:lower:]')

        case "$ext" in
            jpg|jpeg|png|gif|webp)
                dossier="images"
                attendu="image"
                ;;
            mp4|webm|ogv)
                dossier="videos"
                attendu="video"
                ;;
            mp3|wav|ogg)
                dossier="audio"
                attendu="audio"
                ;;
            *)
                dossier="others"
                attendu="application"
                ;;
        esac

        cible="$DIR/downloads/$dossier/$nom"

        if ! curl -sf --max-time 15 -o "$cible" "$url"; then
	    echo -e "\e[31m[ERREUR]\e[0m $nom : téléchargement impossible"
            journaliser ERROR "Téléchargement impossible : $url"
            rm -f "$cible"
            continue
        fi

        type=$(file -b --mime-type "$cible")

        case "$type" in
            "$attendu"/*)
                ;;
            *)
		echo -e "\e[31m[REFUS]\e[0m $nom : type réel $type"
                journaliser ERROR "Type refusé pour $nom : $type"
                rm -f "$cible"
                continue
                ;;
        esac

        somme=$(sha256sum "$cible" | cut -d' ' -f1)

        if grep -q "$somme" "$empreintes"; then
            echo "[DOUBLON] $nom"
            journaliser INFO "Doublon ignoré : $nom"
            rm -f "$cible"
            continue
        fi

        echo "$somme $dossier/$nom" >> "$empreintes"
        echo "$dossier/$nom;$url" >> "$sources"
	echo -e "\e[32m[OK]\e[0m $dossier/$nom"
        nb=$((nb + 1))
    done < "$DIR/index/media_links.txt"

    echo "$nb fichiers téléchargés"
    journaliser INFO "$nb fichiers téléchargés"
}

construire_index() {
    local index="$DIR/index/media_index.csv"
    local chemin
    local url
    local nom
    local type
    local ext
    local taille
    local id=0

    echo "id,filename,path,type,extension,size_bytes,source_url" > "$index"

    while IFS=';' read -r chemin url; do
        id=$((id + 1))

        nom=$(basename "$chemin")
        type=$(dirname "$chemin")
        ext=$(echo "${nom##*.}" | tr '[:upper:]' '[:lower:]')
        taille=$(stat -c %s "$DIR/downloads/$chemin")

        echo "$id,$nom,downloads/$chemin,$type,$ext,$taille,$url" >> "$index"
    done < "$DIR/index/sources.txt"

    tail -n +2 "$index" | jq -Rn '
        [inputs
        | split(",")
        | {
            id: (.[0] | tonumber),
            filename: .[1],
            path: .[2],
            type: .[3],
            extension: .[4],
            size_bytes: (.[5] | tonumber),
            source_url: .[6]
        }]
    ' > "$DIR/index/media_index.json"

    echo "Index JSON créé : index/media_index.json"

    echo "Index créé : index/media_index.csv ($id fichiers)"
    journaliser INFO "Index CSV créé avec $id fichiers"
}

preparer_dataset() {
    local melange="$DIR/index/melange.txt"
    local total
    local nb_val
    local nb_test
    local nb_train

    rm -f "$DIR"/dataset/train/* "$DIR"/dataset/val/* "$DIR"/dataset/test/*

    tail -n +2 "$DIR/index/media_index.csv" \
        | cut -d, -f3 \
        | shuf > "$melange"

    total=$(wc -l < "$melange")
    nb_val=$((total * VAL_RATIO / 100))
    nb_test=$((total * TEST_RATIO / 100))
    nb_train=$((total - nb_val - nb_test))

    copier_lot() {
        local dossier="$1"
        local fichier
        while IFS= read -r fichier; do
            [ -n "$fichier" ] && cp "$DIR/$fichier" "$DIR/dataset/$dossier/"
        done
    }

    head -n "$nb_train" "$melange" | copier_lot train
    tail -n +$((nb_train + 1)) "$melange" \
        | head -n "$nb_val" \
        | copier_lot val
    tail -n +$((nb_train + nb_val + 1)) "$melange" \
        | copier_lot test

    echo "Dataset : train =$nb_train val =$nb_val test =$nb_test"
    journaliser INFO "Dataset préparé : train=$nb_train val=$nb_val test=$nb_test"
}

statistiques() {
    local rapport="$DIR/reports/dataset_report.txt"
    local total=0
    local doublons
    local erreurs

    {
        echo "RAPPORT DU DATASET - $(date '+%F %T')"
        echo "Paramètres : MAX_FILES=$MAX_FILES ratios=$TRAIN_RATIO/$VAL_RATIO/$TEST_RATIO"
        echo
        echo "Fichiers par type :"

        for type in images videos audio others; do
            local nombre
            nombre=$(find "$DIR/downloads/$type" -maxdepth 1 -type f | wc -l)
            echo "  $type : $nombre"
            total=$((total + nombre))
        done

        echo "Total : $total fichiers"
        echo
        echo "Répartition :"

        for ensemble in train val test; do
            local nombre
            nombre=$(find "$DIR/dataset/$ensemble" -maxdepth 1 -type f | wc -l)
            echo "  $ensemble : $nombre"
        done

        doublons=$(grep -c 'Doublon ignoré' "$LOG" || true)
        erreurs=$(grep -c 'ERROR' "$LOG" || true)

        echo
        echo "Doublons ignorés : $doublons"
        echo "Erreurs : $erreurs"
    } > "$rapport"

    cat "$rapport"
}

charger_parametres() {
    if [ ! -r "$SETTINGS" ] || [ ! -r "$URLS" ]; then
        echo "Erreur : fichiers de configuration manquants dans config/"
        exit 2
    fi

    source "$SETTINGS"

    if [ $((TRAIN_RATIO + VAL_RATIO + TEST_RATIO)) -ne 100 ]; then
        echo "Erreur : TRAIN_RATIO + VAL_RATIO + TEST_RATIO doit valoir 100"
        exit 2
    fi
}

if [ "$#" -eq 0 ]; then
    afficher_aide
    exit 1
fi

initialiser
charger_parametres

case "$1" in
    --fetch-html) recuperer_html ;;
    --extract-links) extraire_liens ;;
    --download-media) telecharger_medias ;;
    --build-index) construire_index ;;
    --prepare-dataset) preparer_dataset ;;
    --stats) statistiques ;;
    --all)
    recuperer_html
    extraire_liens || { echo "Aucun lien : arrêt"; exit 3; }
    telecharger_medias
    construire_index
    preparer_dataset
    statistiques
    ;;
    --help) afficher_aide ;;
    *)
        echo "Option inconnue : $1"
        afficher_aide
        exit 1
        ;;
esac
