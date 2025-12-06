<img src="medias/noSMS.ico" width="200px"/>

# B525-Manager
Fonctionne sur Huawei B525s-65a (fonctionne peut-être sur d'autres modèles si API similaires).

**Pour Windows : Notification dès qu'un SMS arrive et UI gestionnaire de SMS (suppression, envoi...) + Interrupteur WIFI direct + auto-Off** \
**Pour Linux** : voir [Bash Version branch](https://github.com/jibap/B525-Manager/tree/Bash-version)

## Projet
J'ai cherché en vain une petite appli facile à mettre en oeuvre qui permettrait sous Windows d'être notifié dès qu'un SMS arrive sur la box 4G... \
Je l'ai donc crée avec **AutoHotKey et Bash** en partant du travail de **oga83** du forum https://routeur4g.fr/, puis comme le bash ne peut s'éxécuter sur Windows de façon silencieuse, j'ai finalement réécrit le script en **Powershell**, qui cette fois ne s'accapare pas le focus.

#### AutoHotkey ?
Il est possible d'éxécuter mon appli **sans AutoHotKey** en utilisant [la version compilée (.exe)](https://github.com/jibap/B525-Manager/releases/latest), sinon vous devrez installer le logiciel : [https://www.autohotkey.com/download/ahk-install.exe](https://www.autohotkey.com/download/ahk-v2.exe) (NB: script écrit en V2 donc ne fonctionne pas en V1)

## Mise en oeuvre
L'application fonctionne comme un logiciel portable, une fois les fichiers récupérés, il faut donc les placer à un endroit de votre arborescence où il pourront rester sans déranger (pas dans le dossier des téléchargements quoi !!!) 

* <ins>Si vous n'avez pas le logiciel AHK installé</ins> : téléchargez et exécutez le [B525-Manager.exe](https://github.com/jibap/B525-Manager/releases/latest) qui fera une extraction des fichiers annexes (script powershell, icones, config)
* <ins>Si vous utilisez déjà AHK</ins> (ou que vous préférez ne pas utiliser le .exe proposé) : téléchargez [l'archive du dépot](https://github.com/jibap/B525-Manager/archive/refs/heads/main.zip), dézippez, copiez les librairies utilisées (AppData\Local\Programs\AutoHotkey\v2\Lib), complétez le fichier config.ini selon les directives indiquées plus bas et exécutez le B525-Manager.ahk pour le lancer. 

> Pour que l'application se lance au démarrage de l'ordi, pensez à la rajouter en tâche planifiée ou au dossier "Démarrage" de Windows (shell:startup)


## Configuration
Une interface de configuration est accessible depuis l'icone du logiciel dans la zone de notification : \
<img width="336" height="267" alt="image" src="https://github.com/user-attachments/assets/b5265365-c3a5-4263-ba1f-a7a177bbc14f" />

il faut renseigner au moins le mot de passe pour que la connexion fonctionne : \
<img width="406" height="397" alt="image" src="https://github.com/user-attachments/assets/358654a2-2472-4d5a-8e6b-630da9325f40" />

Un "répertoire de contacts" est également proposé dans l'interface principale et dans le formulaire d'envoi de SMS et le premier numéro de la liste sera préselectionné par défaut (pratique dans mon cas car je communique par SMS via ma box 4G, toujours vers le même numéro) : \
<img width="406" height="390" alt="image" src="https://github.com/user-attachments/assets/a98e89fe-77d2-4639-a998-7e1c12569b58" />
<img width="425" height="267" alt="image" src="https://github.com/user-attachments/assets/e9d6d307-2417-456f-9f9a-6723eb8fd4d9" />

Une fois le logiciel en cours d'exécution, une icône s'affiche au niveau de la zone de notification de Windows (à côté de l'horloge). \
<img width="290" height="68" alt="image" src="https://github.com/user-attachments/assets/ad28a7f2-357c-44d3-b17f-6fcde13de707" />

## Usage
* **Un survol de l'icone** affiche un infobulle récapitulatif (nb de messages non lus, reçus et envoyés)\
<img width="111" height="131" alt="image" src="https://github.com/user-attachments/assets/c00847a8-5f48-40f8-8cf7-1e8a5e892a2c" />
<img width="156" height="122" alt="image" src="https://github.com/user-attachments/assets/4b4e834a-319b-4238-83f6-446b5a122aed" />


* **Un clic droit** sur l'icone lance un refresh forcé pour relever les SMS

* **Un clic** sur l'icone affiche un menu contextuel permettant de quitter l'appli, actualiser le statut, afficher l'interface d'envoi de SMS, **activer ou désactiver le wifi**, ouvrir la configuration
<img width="336" height="267" alt="image" src="https://github.com/user-attachments/assets/b5265365-c3a5-4263-ba1f-a7a177bbc14f" />

* **Un double clic** sur l'icone affiche l'interface de gestion des SMS : une liste de tous les SMS présents sur la box\
<img width="914" height="473" alt="image" src="https://github.com/user-attachments/assets/9f14fa16-abed-4f1b-bb92-24fd2bc0d754" />

* Dans la liste, il est possible de faire une **sélection multiple** ou **un clic-droit** pour effectuer les actions telles que : supprimer, marquer comme lu ou **répondre** (double-clic sur une ligne pour répondre directement)
<img width="650" height="238" alt="image" src="https://github.com/user-attachments/assets/4949efcf-2d60-466d-9dde-e283347c257a" />




## Comportement
* L'icone de la marque Huawei est blanche si aucun nouveau message. <img src="medias/noSMS.ico" width="20px"/>
* L'icone passe au rouge quand une interrogation de la box est en cours. <img src="medias/load.ico" width="20px" />
* L'icone change pour une bulle de citation avec "..." pour indiquer qu'un nouveau message est présent. <img src="medias/more.ico" width="20px"/>

A chaque actualisation (5 minutes par défaut), le logiciel vérifie si de nouveaux SMS sont arrivés, si c'est le cas, une notification Windows apparaîtra pour chaque nouveau message (très utile pour les code de double authentification e-commerce !)\
<img width="466" height="220" alt="image" src="https://github.com/user-attachments/assets/98f21efd-8e45-4974-8e72-cec9f2ecc744" />

