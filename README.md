# B525-SMSManager (BASH)
Fonctionne sur Huawei B525s-65a (fonctionne peut-être sur d'autres modèles si API similaires).

**Pour Windows** : voir [Version Windows](https://github.com/jibap/B525-Manager)\
**Pour Linux** : le fichier manage_b525.sh est utilisable en terminal

## Pré-requis Windows
### Pour avoir BASH sous Windows 10
* Installer la fonctionnalité "Sous-sytème Windows pour Linux" (WSL) via la commande (Win+R) : optionalfeatures
* Installer une distri Linux via le Microsoft Store ( [Ubuntu](https://www.microsoft.com/store/productId/9NBLGGH4MSV6) ou [Debian](https://www.microsoft.com/store/productId/9MSVKQC78PK6) )
* Vérifier que les paquets suivants sont bien installés : curl et wget (ce n'est pas le cas sur Debian)

```
sudo apt update
sudo apt install curl
sudo apt install wget
```
### Pour avoir BASH sous Windows 11
* Idem Windows 10 + installer également la fonctionnalité "Plateforme de machine virtuelle" lors de la première étape. (il est aussi possible d'activer WSL2 depuis le store ici : https://apps.microsoft.com/store/detail/windows-subsystem-for-linux/9P9TQF7MRM4R)
* Si WSL (depuis ajout de fonctionnalités) Il faut mettre à jour le noyau linux : https://learn.microsoft.com/fr-fr/windows/wsl/install-manual#step-4---download-the-linux-kernel-update-package  \

### Configuration
Il est nécessaire de renseigner l'entrée **ROUTER_PASSWORD** à minima, l'IP et le USER étant par défaut. 


## Historique
J'ai cherché en vain une petite appli facile à mettre en oeuvre qui permettrait sous Windows d'être notifié dès qu'un SMS arrive sur la box 4G... \
Je l'ai donc crée avec AutoHotKey et Bash en partant du travail de **oga83** du forum https://routeur4g.fr/ puis finalement [refait en Powershell](https://github.com/jibap/B525-Manager), le bash original de la première version est conservé ici. 
