Persistent
#Warn
#SingleInstance force ; Ecrase si instance en cours
#Include <GuiCtrlTips>
#Include <GuiEditListView>

#Include "*i version.txt" ; utilisé lors de la compilation
if !A_IsCompiled || !IsSet(currentVersion) { ; fallback si non compilé
    currentVersion := "AHK_DIRECT"
}

DllCall("AllocConsole")
WinHide("ahk_id " DllCall("GetConsoleWindow", "ptr"))

OnMessage(0x404, OnTrayClick) ; Capture les événements liés au Tray
OnMessage(0x404, ClicOnNotif) ; CLIC sur la notif pour ouvrir la GUI

SendMode("Input")  ;
SetWorkingDir(A_ScriptDir)

psShell := "" ; Initialisation de la variable globale pour eviter erreur onExit()
OnExit(ExitAppli)

#Include "*i updater.ahk" ; gestion des mises à jour

; IMPORT / EXPORT des fichiers annexes pour version compilée
DirCreate("medias")
FileInstall("medias\noSMS.ico", "medias\noSMS.ico", 1)
FileInstall("medias\more.ico", "medias\more.ico", 1)
FileInstall("medias\load.ico", "medias\load.ico", 1)
FileInstall("medias\net.ico", "medias\net.ico", 1)

FileInstall("B525-Manager.ps1", "B525-Manager.ps1", 1)

if !FileExist("config.ini") {
    FileInstall("config.ini", "config.ini")
}

; #### ##    ## #### ########
;  ##  ###   ##  ##     ##
;  ##  ####  ##  ##     ##
;  ##  ## ## ##  ##     ##
;  ##  ##  ####  ##     ##
;  ##  ##   ###  ##     ##
; #### ##    ## ####    ##

wifiStatus := 0
lastIcon := "noSMS"
data := {}
helpText :=
    "Cliquer sur une ligne pour afficher et pouvoir sélectionner le texte du SMS dans cette zone. Double-Clic pour répondre... "
refreshing := false
contactsArray := Array()
ignoreDestEdit := false

; ICONES
validIconID := "301"
outboxIconID := "195"
unreadIconID := "209"
enableWifiIconID := "53"
openWebPageIconID := "136"
sendSMSIconID := "215"
refreshIconID := "239"
deleteIconID := "32"
quitIconID := "132"
contactIconID := "161"
dateIconID := "250"
messageIconID := "157"
hideIconID := "176"
cancelIconID := "296"
settingsIconID := "315"
sendIconID := "195"
resetIconID := "271"
configFileIconID := "70"
helpIconID := "222"
moveUpIconID := "247"
moveDownIconID := "248"

; DETERMINE LA VERSION DE WINDOWS
objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" A_ComputerName "\root\cimv2")
for objOperatingSystem in objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
    windowsVersion := objOperatingSystem.Caption
; SI WINDOWS 10
if (InStr(windowsVersion, "10")) {
    validIconID := "297"
    unreadIconID := "321"
    dateIconID := "266"
    cancelIconID := "298"
    enableWifiIconID := "51"
    resetIconID := "240"
    settingsIconID := "317"
    configFileIconID := "72"
}

; Création d'une liste d'icones système pour la ListView
ImageListID := IL_Create(3)
IL_Add(ImageListID, "shell32.dll", validIconID)
IL_Add(ImageListID, "imageres.dll", outboxIconID)
IL_Add(ImageListID, "shell32.dll", unreadIconID)

; Ouverture du powershell permanent
psShell := ComObject("WScript.Shell").Exec("powershell -ExecutionPolicy Bypass -command -")

; Initialisation personnalisée, le cas échéant, des variables globales
default_ipRouter := "192.168.8.1"
ipRouter := IniRead("config.ini", "main", "ROUTER_IP", default_ipRouter)
if (!ipRouter || !ValidIP(ipRouter)) {
    ipRouter := default_ipRouter
}
default_username := "admin"
username := IniRead("config.ini", "main", "ROUTER_USERNAME", default_username)
if (!username || Type(username) != "String") {
    username := default_username
}
default_password := "adminBox"
password := IniRead("config.ini", "main", "ROUTER_PASSWORD", default_password)
if (!password || Type(password) != "String") {
    password := default_password
}

; Force les valeurs par défaut (y compris dans le config.ini) si invalide
; AUTO_WIFI_OFF_STATUS
default_autoWifiOffStatus := "0"
autoWifiOffStatus := IniRead("config.ini", "main", "AUTO_WIFI_OFF_STATUS", default_autoWifiOffStatus)
autoWifiOffStatus := autoWifiOffStatus + 0 ; force en entier
if (!autoWifiOffStatus || !IsBoolean(autoWifiOffStatus)) {
    autoWifiOffStatus := default_autoWifiOffStatus + 0 ; force en entier
    IniWrite(autoWifiOffStatus, "config.ini", "main", "AUTO_WIFI_OFF_STATUS")
}
; AUTO_WIFI_OFF
default_autoWifiOff := "19:00"
autoWifiOff := IniRead("config.ini", "main", "AUTO_WIFI_OFF", default_autoWifiOff)
if (!autoWifiOff || !RegExMatch(autoWifiOff, "^\d{2}:\d{2}$")) {
    autoWifiOff := default_autoWifiOff
    IniWrite(autoWifiOff, "config.ini", "main", "AUTO_WIFI_OFF")
}
; AUTO_WIFI_ON_STATUS
default_autoWifiOnStatus := "0"
autoWifiOnStatus := IniRead("config.ini", "main", "AUTO_WIFI_ON_STATUS", default_autoWifiOnStatus)
autoWifiOnStatus := autoWifiOnStatus + 0 ; force en entier
if (!autoWifiOnStatus || !IsBoolean(autoWifiOnStatus)) {
    autoWifiOnStatus := default_autoWifiOnStatus + 0 ; force en entier
    IniWrite(autoWifiOnStatus, "config.ini", "main", "AUTO_WIFI_ON_STATUS")
}
; AUTO_WIFI_ON
default_autoWifiOn := "09:00"
autoWifiOn := IniRead("config.ini", "main", "AUTO_WIFI_ON", default_autoWifiOn)
if (!autoWifiOn || !RegExMatch(autoWifiOn, "^\d{2}:\d{2}$")) {
    autoWifiOn := default_autoWifiOn
    IniWrite(autoWifiOn, "config.ini", "main", "AUTO_WIFI_ON")
}
default_loopDelay := "5m"
loopDelay := IniRead("config.ini", "main", "DELAY", default_loopDelay)
if (!loopDelay || !RegExMatch(loopDelay, "i)^\d+[smh]$")) {
    loopDelay := default_loopDelay
    IniWrite(loopDelay, "config.ini", "main", "DELAY")
}

SetTrayIcon("noSMS")

; CREATION DU TRAYMENU
; *********************
trayMenu := A_TrayMenu
trayMenu.Delete() ; Supprime les menus par défaut
trayMenu.add("Quitter l'application", ExitAppli)
trayMenu.add()
trayMenu.add("Activer le Wifi", SwitchWifi)
trayMenu.add("Envoyer un SMS", SendSMSGUIShow)
trayMenu.add()
trayMenu.add("Paramètres", ConfigGUIOpen)
if (IsSet(CheckForUpdate)) {
    trayMenu.add("Vérifier la mise à jour", CheckForUpdate)
} else {
    trayMenu.add()
}
trayMenu.add()
trayMenu.add("Ouvrir la page Web", OpenWebPage)
trayMenu.add("Ouvrir l'interface (double clic)", OpenListSMSGUI)
trayMenu.add()
trayMenu.add("Actualiser (clic droit)", Refresh)
trayMenu.Default := "10&"

trayMenu.SetIcon("1&", "shell32.dll", quitIconID)
trayMenu.SetIcon("3&", "ddores.dll", enableWifiIconID)
trayMenu.SetIcon("4&", "shell32.dll", sendSMSIconID)
trayMenu.SetIcon("6&", "shell32.dll", settingsIconID)
trayMenu.SetIcon("9&", "shell32.dll", openWebPageIconID)
trayMenu.SetIcon("12&", "shell32.dll", refreshIconID)

; ##       ####  ######  ########     ######  ##     ##  ######      ######   ##     ## ####
; ##        ##  ##    ##    ##       ##    ## ###   ### ##    ##    ##    ##  ##     ##  ##
; ##        ##  ##          ##       ##       #### #### ##          ##        ##     ##  ##
; ##        ##   ######     ##        ######  ## ### ##  ######     ##   #### ##     ##  ##
; ##        ##        ##    ##             ## ##     ##       ##    ##    ##  ##     ##  ##
; ##        ##  ##    ##    ##       ##    ## ##     ## ##    ##    ##    ##  ##     ##  ##
; ######## ####  ######     ##        ######  ##     ##  ######      ######    #######  ####

; CREATION DE LA GUI PRINCIPALE (LIST SMS)
; ****************************************
ListSMSGUI := Gui("")
ListSMSGUI.Title := "B525-Manager  [" currentVersion "]"

initTips(ListSMSGUI)

; BOUTONS DU HAUT
RefreshButton := ListSMSGUI.Add("Button", "x10 y8 w100 r2", A_Space . "Actualiser")
ReadAllButton := ListSMSGUI.Add("Button", "x+5 y8 w180 r2 Disabled", A_Space . "Tout marquer comme lu")
DeleteAllButton := ListSMSGUI.Add("Button", "x+5 y8 w130 r2 Disabled", A_Space . "Tout supprimer")
TextInfo := ListSMSGUI.Add("Text", "x+5 y20 w195 h20", "")
ContactsGUIOpenButton := ListSMSGUI.Add("Button", "x+5 y8 w35 r2 +0x40 +0x0C", A_Space)
ListSMSGUI.Tips.SetTip(ContactsGUIOpenButton, "Gestion des contacts")
ConfigGUIOpenButton := ListSMSGUI.Add("Button", "x+5 y8 w35 r2 +0x40 +0x0C", A_Space)
ListSMSGUI.Tips.SetTip(ConfigGUIOpenButton, "Configuration")

; TABLEAU DES SMS
LV_SMS := ListSMSGUI.Add("ListView", "section xs R10 w700  Grid AltSubmit -Hdr", ["", "contactName", "Time", "Message",
    "Index", "boxType", "phoneNumber"])

; DETAILS DES SMS
ListSMSGUI.Add("Picture", "section Icon" . contactIconID . " w16 h16", "shell32.dll")
FullNumeroEdit := ListSMSGUI.Add("Edit", "ReadOnly x+5 w150 h20")
ListSMSGUI.Add("Picture", "x+5 Icon" . dateIconID . " w16 h16", "shell32.dll")
FullDateText := ListSMSGUI.Add("Text", "x+5 w200 h20 vFullDate")
ListSMSGUI.Add("Picture", "section xs ICon" . messageIconID . " w16 h16", "shell32.dll")
FullMessageEdit := ListSMSGUI.Add("Edit", "ReadOnly x+5 w670 h50 ", helpText)

; BOUTONS DU BAS
openWebPageButton := ListSMSGUI.Add("Button", "section xs w150 r2", A_Space . "Page Web de la box 4G")
SwitchWifiButton := ListSMSGUI.Add("Button", "x+40 w140 r2", A_Space . "Activer le Wifi")
SendSMSButton := ListSMSGUI.Add("Button", "x+40 w140 r2", A_Space . "Envoyer un SMS")
HideGUIButton := ListSMSGUI.Add("Button", "x+40 w150 r2", "Cacher la fenêtre")

; ICONES DES BOUTONS
SetButtonIcon(RefreshButton, "shell32.dll", refreshIconID, 20)
SetButtonIcon(ReadAllButton, "shell32.dll", validIconID, 20)
SetButtonIcon(DeleteAllButton, "shell32.dll", deleteIconID, 20)
SetButtonIcon(ContactsGUIOpenButton, "shell32.dll", contactIconID, 20)
SetButtonIcon(ConfigGUIOpenButton, "shell32.dll", settingsIconID, 20)
SetButtonIcon(openWebPageButton, "shell32.dll", openWebPageIconID, 20)
SetButtonIcon(SwitchWifiButton, "ddores.dll", enableWifiIconID, 20)
SetButtonIcon(SendSMSButton, "shell32.dll", sendSMSIconID, 20)
SetButtonIcon(HideGUIButton, "imageres.dll", hideIconID, 20)

LV_SMS.SetImageList(ImageListID)  ; APPLIQUE LES ICONES DANS LA LISTE

; EVENEMENTS DES BOUTONS
RefreshButton.OnEvent("Click", Refresh)
ReadAllButton.OnEvent("Click", TagSMSAsReadButtonClick)
DeleteAllButton.OnEvent("Click", DeleteSMS)
ContactsGUIOpenButton.OnEvent("Click", ContactsGUIOpen)
ConfigGUIOpenButton.OnEvent("Click", ConfigGUIOpen)

openWebPageButton.OnEvent("Click", OpenWebPage)
SwitchWifiButton.OnEvent("Click", SwitchWifi)
SendSMSButton.OnEvent("Click", SendSMSGUIShow)
HideGUIButton.OnEvent("Click", ListSMSGUICLose)

; EVENEMENTS SUR LA LISTE
LV_SMS.OnEvent("Click", ListSMSClick)
LV_SMS.OnEvent("ContextMenu", ListSMSRightClick)
LV_SMS.OnEvent("DoubleClick", Reply)
ListSMSGUI.OnEvent("Close", ListSMSGUICLose)
ListSMSGUI.OnEvent("Escape", ListSMSGUICLose)

; Menu au clic-droit
ListSMS_RCMenu := Menu()  ; Création du menu contextuel

; Ajout des éléments avec leurs fonctions associées
ListSMS_RCMenu.Add("Répondre", Reply)
ListSMS_RCMenu.Add("Supprimer", DeleteSMS)
ListSMS_RCMenu.Add("Marquer comme lu", TagSMSAsReadButtonClick)
ListSMS_RCMenu.SetIcon("1&", "shell32.dll", cancelIconID)
ListSMS_RCMenu.SetIcon("2&", "shell32.dll", deleteIconID)
ListSMS_RCMenu.SetIcon("3&", "shell32.dll", validIconID)

;  ######  ######## ##    ## ########      ######  ##     ##  ######      ######   ##     ## ####
; ##    ## ##       ###   ## ##     ##    ##    ## ###   ### ##    ##    ##    ##  ##     ##  ##
; ##       ##       ####  ## ##     ##    ##       #### #### ##          ##        ##     ##  ##
;  ######  ######   ## ## ## ##     ##     ######  ## ### ##  ######     ##   #### ##     ##  ##
;       ## ##       ##  #### ##     ##          ## ##     ##       ##    ##    ##  ##     ##  ##
; ##    ## ##       ##   ### ##     ##    ##    ## ##     ## ##    ##    ##    ##  ##     ##  ##
;  ######  ######## ##    ## ########      ######  ##     ##  ######      ######    #######  ####

; GUI d'envoi de SMS
; *****************************

SendSMSGUI := Gui("")
SendSMSGUI.Title := "Envoi de SMS sur Box4G"

SendSMSGUI.Add("Text", , "Message:")
messageToDest := SendSMSGUI.Add("Edit", "w240 r5 ys")

SendSMSGUI.Add("Text", "section xs w65", "Destinataire :")
DDLContactChoice := SendSMSGUI.Add("DropDownList", "ys w200")
DDLContactChoice.OnEvent("Change", OnDDLContactChoiceChange)

SendSMSGUI.Add("Text", "section xs w65", "Numéro :")
numberDest := SendSMSGUI.Add("Edit", "ys w80 Limit10 Number")
numberDest.OnEvent("Change", OnDestNumberEdit)

SendSMSGUICancelButton := SendSMSGUI.Add("Button", "section xs  w150 r2", "Annuler")
SetButtonIcon(SendSMSGUICancelButton, "shell32.dll", cancelIconID, 20)
SendSMSGUICancelButton.OnEvent("Click", SendSMSGUIClose)

SendSMSGUISendButton := SendSMSGUI.Add("Button", "ys  w150 r2", "Envoi")
SetButtonIcon(SendSMSGUISendButton, "imageres.dll", sendIconID, 20)
SendSMSGUISendButton.OnEvent("Click", SendSMSGUISend)

; EXIT
SendSMSGUI.OnEvent("Close", SendSMSGUIClose)
SendSMSGUI.OnEvent("Escape", SendSMSGUIClose)

;  ######   #######  ##    ## ######## ####  ######       ######   ##     ## ####
; ##    ## ##     ## ###   ## ##        ##  ##    ##     ##    ##  ##     ##  ##
; ##       ##     ## ####  ## ##        ##  ##           ##        ##     ##  ##
; ##       ##     ## ## ## ## ######    ##  ##   ####    ##   #### ##     ##  ##
; ##       ##     ## ##  #### ##        ##  ##    ##     ##    ##  ##     ##  ##
; ##    ## ##     ## ##   ### ##        ##  ##    ##     ##    ##  ##     ##  ##
;  ######   #######  ##    ## ##       ####  ######       ######    #######  ####

ConfigGUI := Gui("")
ConfigGUI.Title := "Configuration"

initTips(ConfigGUI)

ConfigGUI.SetFont("w700", "Segoe UI")
ConfigGUI.Add("GroupBox", "w300 h110", "Connexion au routeur Huawei")
ConfigGUI.SetFont("w400", "Segoe UI")

ConfigGUI.Add("Text", "xs+80 ys+20", "Adresse IP :")
ipRouterEdit := ConfigGUI.Add("Edit", "w80 x+5 yp-3", ipRouter)
ipRouterHelp := ConfigGUI.Add("Button", "w16 h16 x+5 yp+3 +0x40 +0x0C", A_Space)
SetButtonIcon(ipRouterHelp, "shell32.dll", helpIconID, 20)
ConfigGUI.Tips.SetTip(ipRouterHelp, "par défaut : 192.168.8.1")

ConfigGUI.Add("Text", "xs+83 y+15", "Utilisateur :")
usernameEdit := ConfigGUI.Add("Edit", "w80 x+5 yp-3", username)
usernameHelp := ConfigGUI.Add("Button", "w16 h16 x+5 yp+3 +0x40 +0x0C", A_Space)
SetButtonIcon(usernameHelp, "shell32.dll", helpIconID, 20)
ConfigGUI.Tips.SetTip(usernameHelp, "par défaut : admin")

ConfigGUI.Add("Text", "xs+65 y+15", "Mot de passe :")
passwordEdit := ConfigGUI.Add("Edit", "w80 x+5 yp-3", password)
passwordHelp := ConfigGUI.Add("Button", "w16 h16 x+5 yp+3 +0x40 +0x0C", A_Space)
SetButtonIcon(passwordHelp, "shell32.dll", helpIconID, 20)
ConfigGUI.Tips.SetTip(passwordHelp, "par défaut : adminBox")

ConfigGUI.SetFont("w700", "Segoe UI")
ConfigGUI.Add("GroupBox", "section xs y130 w300 h110", "Options")
ConfigGUI.SetFont("w400", "Segoe UI")

ConfigGUI.Add("Text", "xs+10 ys+20", "Actualisation :")
delayEdit := ConfigGUI.Add("Edit", "w30 x+5 yp-3", loopDelay)
delayHelp := ConfigGUI.Add("Button", "w16 h16 x+5 yp+3 +0x40 +0x0C", A_Space)
SetButtonIcon(delayHelp, "shell32.dll", helpIconID, 20)
ConfigGUI.Tips.SetTip(delayHelp, "par défaut : 5m ▶ Période exprimée en s (secondes), m (minutes) ou h (heures)")

ConfigGUI.Add("Text", "xs+10 y+15", "Activation automatique du Wifi à ")
autoWifiOnEdit := ConfigGUI.Add("DateTime", "x+0 w50 yp-5 1", "HH:mm",)
autoWifiOnEdit.Value := TimeToDateTimeValue(autoWifiOn)
autoWifiOnStatusCB := ConfigGUI.Add("CheckBox", "x+10 yp+5", "Activé ")
autoWifiOnStatusCB.Value := autoWifiOnStatus

ConfigGUI.Add("Text", "xs+10 y+15", "Désactivation automatique du Wifi à ")
autoWifiOffEdit := ConfigGUI.Add("DateTime", "x+0 w50 yp-5 1", "HH:mm",)
autoWifiOffEdit.Value := TimeToDateTimeValue(autoWifiOff)
autoWifiOffStatusCB := ConfigGUI.Add("CheckBox", "x+10 yp+5", "Activé ")
autoWifiOffStatusCB.Value := autoWifiOffStatus

ConfigGUIResetButton := ConfigGUI.Add("Button", "section xs w35 y+20 r2 +0x40 +0x0C", A_Space)
ConfigGUI.Tips.SetTip(ConfigGUIResetButton, "Réinitialiser avec les valeurs par défaut")
SetButtonIcon(ConfigGUIResetButton, "imageres.dll", resetIconID, 20)
ConfigGUIResetButton.OnEvent("Click", ConfigGUIReset)

ConfigGUICancelButton := ConfigGUI.Add("Button", "section x+10 w100 r2", A_Space . "Annuler")
SetButtonIcon(ConfigGUICancelButton, "shell32.dll", cancelIconID, 20)
ConfigGUICancelButton.OnEvent("Click", ConfigGUIClose)

ConfigGUIValidButton := ConfigGUI.Add("Button", "x+10 ys  w100 r2", A_Space . "Enregistrer")
SetButtonIcon(ConfigGUIValidButton, "shell32.dll", validIconID, 20)
ConfigGUIValidButton.OnEvent("Click", ConfigGUIValid)

ConfigGUIOpenFileButton := ConfigGUI.Add("Button", "ys  w35 r2 +0x40 +0x0C", A_Space)
ConfigGUI.Tips.SetTip(ConfigGUIOpenFileButton, "Ouvrir le fichier de configuration")
SetButtonIcon(ConfigGUIOpenFileButton, "shell32.dll", configFileIconID, 20)
ConfigGUIOpenFileButton.OnEvent("Click", ConfigGUIOpenFile)

; ##       ####  ######  ########     ######   #######  ##    ## ########    ###     ######  ########  ######      ######   ##     ## ####
; ##        ##  ##    ##    ##       ##    ## ##     ## ###   ##    ##      ## ##   ##    ##    ##    ##    ##    ##    ##  ##     ##  ##
; ##        ##  ##          ##       ##       ##     ## ####  ##    ##     ##   ##  ##          ##    ##          ##        ##     ##  ##
; ##        ##   ######     ##       ##       ##     ## ## ## ##    ##    ##     ## ##          ##     ######     ##   #### ##     ##  ##
; ##        ##        ##    ##       ##       ##     ## ##  ####    ##    ######### ##          ##          ##    ##    ##  ##     ##  ##
; ##        ##  ##    ##    ##       ##    ## ##     ## ##   ###    ##    ##     ## ##    ##    ##    ##    ##    ##    ##  ##     ##  ##
; ######## ####  ######     ##        ######   #######  ##    ##    ##    ##     ##  ######     ##     ######      ######    #######  ####

EditContactsGUI := Gui(, "Gestion de contacts")

; --- Boutons ---
addContactButton := EditContactsGUI.AddButton("xm r2 w100", A_Space . "Ajouter")
SetButtonIcon(addContactButton, "shell32.dll", contactIconID, 20)
addContactButton.OnEvent("Click", (*) => AddAndSelectContact(LV_Contacts))

delContactButton := EditContactsGUI.AddButton("x+5 r2 w100", A_Space . "Supprimer")
SetButtonIcon(delContactButton, "shell32.dll", deleteIconID, 20)
delContactButton.OnEvent("Click", (*) => DeleteSelectedContact(LV_Contacts))

moveUpContactButton := EditContactsGUI.AddButton("x+20 w35 r2 +0x40 +0x0C", A_Space)
SetButtonIcon(moveUpContactButton, "shell32.dll", moveUpIconID, 20)
moveUpContactButton.OnEvent("Click", (*) => MoveContactRow(LV_Contacts, -1))

moveDownContactButton := EditContactsGUI.AddButton("x+5 w35 r2 +0x40 +0x0C", A_Space)
SetButtonIcon(moveDownContactButton, "shell32.dll", moveDownIconID, 20)
moveDownContactButton.OnEvent("Click", (*) => MoveContactRow(LV_Contacts, 1))

ContactHeaders := ["Nom", "Numéro"]
LV_Contacts := EditContactsGUI.AddListView("xs w300 r10 Grid -ReadOnly", ContactHeaders)

cancelContactButton := EditContactsGUI.Add("Button", "xs+50 w100 r2", A_Space . "Annuler")
SetButtonIcon(cancelContactButton, "shell32.dll", cancelIconID, 20)
cancelContactButton.OnEvent("Click", (*) => EditContactsGUI.Hide())

saveContactButton := EditContactsGUI.Add("Button", "x+10  w100 r2", A_Space . "Enregistrer")
SetButtonIcon(saveContactButton, "shell32.dll", validIconID, 20)
saveContactButton.OnEvent("Click", (*) => SaveContactsData(LV_Contacts))

; EXIT
EditContactsGUI.OnEvent("Close", (*) => EditContactsGUI.Hide())

; Attacher l'édition inline
EditInlineContactLV := LVEditInline(LV_Contacts)

; ######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######
; ##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ##
; ##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##
; ######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######
; ##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ##
; ##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ##
; ##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######

initTips(GUIObj) {
    GUIObj.Tips := GuiCtrlTips(GUIObj)
    GUIObj.Tips.SetBkColor(0xFFFFFF)
    GUIObj.Tips.SetTxColor(0x404040)
    GUIObj.Tips.SetMargins(4, 4, 4, 4)
}

IsBoolean(val) {
    return (val = 0 || val = 1)
}

DelayToMs(value) {
    value := Trim(value)
    if value {
        ; Regex avec unité obligatoire (s, m ou h)
        if RegExMatch(value, "i)^(?<num>\d+)(?<unit>[smh])$", &match) {
            num := Abs(Integer(match.num))
            unit := StrLower(match.unit)

            switch unit {
                case "h": return num * 3600000
                case "m": return num * 60000
                case "s": return num * 1000
            }
        }
    }
    return 300000
}

RefreshContactsArray() {
    global contactsArray
    contactsArray := [] ; Réinitialise le tableau

    iniList := IniRead("config.ini", "contacts", , "")
    if (iniList == "") { ; Pas de contacts configurés
        return
    }

    contacts := StrSplit(iniList, "`n")
    for _, contactLine in contacts {
        egalPos := InStr(contactLine, "=")
        if (egalPos <= 0)
            continue
        num := SubStr(contactLine, 1, egalPos - 1)
        name := SubStr(contactLine, egalPos + 1)
        contactsArray.Push({ num: num, name: name })
    }
}

OnTrayClick(wParam, lParam, msg, hwnd) {
    if (lParam == 0x201) { ; Clic gauche up
        SetTimer OnTraySingleClick, -250 ;
        return 1
    } else if (lParam == 0x203) { ; Double clic gauche
        SetTimer OnTraySingleClick, 0 ; Annule le Timer du simple clic
        ListSMSGUIOpen()
        return 1
    } else if (lParam == 0x205) { ; clic droit up
        Refresh()
        return 1
    }
    ; Retourne 0 pour laisser AHK gérer les autres messages (comme le clic droit par défaut)
    return 0
}

OnTraySingleClick() {
    trayMenu.Show()
}

; FONCTIONS POWERSHELL
SendToPS(command) {
    global psShell
    psShell.StdIn.WriteLine(command)
    psShell.StdIn.WriteLine("echo END_OF_COMMAND;")  ; Marqueur de fin

    output := ""
    while !psShell.StdOut.AtEndOfStream {
        line := psShell.StdOut.ReadLine()
        ; Ignorer les lignes contenant le préfixe de commande
        if line = "END_OF_COMMAND"
            break
        output .= line "`n"
    }
    return output
}

ClosePS(*) {  ; Fonction pour fermer proprement le PowerShell
    global psShell
    if IsSet(psShell) && IsObject(psShell) {
        try psShell.StdIn.WriteLine("exit")
        try psShell.Terminate()
        psShell := ""
    }
}

; Fonction qui permets de cliquer sur la notif Windows pour ouvrir la GUI
ClicOnNotif(wParam, lParam, msg, hwnd) {
    if (hwnd != A_ScriptHwnd)
        return
    if (lParam = 1029)
        ListSMSGUIOpen()
}

; Permet de valider une IP
ValidIP(IPAddress) {
    ; Expression régulière pour une adresse IPv4 valide
    RegEx :=
        "^\b(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$"

    ; Utilisation de RegExMatch pour tester l'adresse IP
    if (RegExMatch(IPAddress, RegEx)) {
        return true
    }
    return false
}

Utf8ToText(vUtf8) {
    if 1 {
        VarSetStrCapacity(&vTemp, StrPut(vUtf8, "CP0"))
        StrPut(vUtf8, StrPtr(vTemp), "CP0")
        return StrGet(StrPtr(vTemp), "UTF-8")
    }
    else
        return StrGet(&vUtf8, "UTF-8")
}

ConvertXMLtoArray(xmldata, rootNode) {
    xmldata := RegExReplace(xmldata, "\r")
    xmlObj := ComObject("MSXML2.DOMDocument.6.0")
    xmlObj.async := false
    xmlObj.loadXML(xmldata)
    nodes := xmlObj.selectNodes(rootNode)
    return nodes
}

; Fonction spéciale pour les GUI, permet d'afficher une icone dans un bouton
SetButtonIcon(Button, File, Index, Size := 16) {
    hIcon := LoadPicture(File, "h" . Size . " Icon" . Index, &_)
    ErrorLevel := SendMessage(0xF7, 1, hIcon, , "ahk_id " Button.hwnd)
}

ExitAppli(*) {
    ClosePS()
    ExitApp()
}

OpenWebPage(*) {
    Run("http://" ipRouter "/html/smsinbox.html")
}

SetTrayIcon(iconName) {
    if !iconName
        iconName := lastIcon
    iconFile := "medias\" . iconName . ".ico"
    TraySetIcon(iconFile)
}

CheckForWifiAutoSwitch() {
    currentTime := FormatTime(, "HHmm")
    autoWifiOffTime := StrReplace(autoWifiOff, ":", "")
    autoWifiOnTime := StrReplace(autoWifiOn, ":", "")
    isNightInterval := (autoWifiOffTime > autoWifiOnTime) ; VRAI si la coupure (OFF) traverse minuit
    
    ; --- Détermine si on est dans le créneau OFF ---
    if (isNightInterval) {
        isTimeForOff := (currentTime >= autoWifiOffTime) || (currentTime < autoWifiOnTime)
    } else {
        isTimeForOff := (currentTime >= autoWifiOffTime) && (currentTime < autoWifiOnTime)
    }

    ; --- Actions ---
    if (
        (wifiStatus = 1 && autoWifiOffStatus = 1 && isTimeForOff) ||
        (wifiStatus = 0 && autoWifiOnStatus = 1 && !isTimeForOff)
    ) {
        SwitchWifi()
    }
}

BoxIsReachable(ForceTrayTip) {
    global lastIcon
    ; Vérification BOX joignable
    cmd := "[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8; Test-Connection " . ipRouter . " -Count 1 -Quiet"
    result := SendToPS(cmd)

    if (!InStr(result, "True")) {
        noticeText := "La box 4G est injoignable, veuillez vérifier la connexion..."

        ; Désactive les boutons
        trayMenu.Disable("3&") ; Wifi
        trayMenu.Disable("4&") ; Envoi SMS

        ; actualisation de l'icone
        SetTrayIcon("net")
        lastIcon := "net"

        quiet := !GuiIsActive()
        if (!quiet || ForceTrayTip) {
            TrayTip(noticeText, "Erreur", 36)
        }
        A_IconTip := noticeText
        netStatus := False
    } else {
        trayMenu.Enable("3&") ; Wifi
        trayMenu.Enable("4&") ; Envoi SMS
        netStatus := True
    }

    SwitchWifiButton.Enabled := netStatus
    SendSMSButton.Enabled := netStatus
    ReadAllButton.Enabled := netStatus
    DeleteAllButton.Enabled := netStatus

    return netStatus
}

RunBoxCmd(command) {
    cmd := " " . A_WorkingDir . "\B525-Manager.ps1 " . command
    result := SendToPS(cmd)

    ; Gestion des erreurs
    if (InStr(result, "ERROR")) {
        ; Cas spécial où il y a une erreur de joignabilité
        if (InStr(result, "Router unreachable")) {
            BoxIsReachable(true)
        } else {
            errorText := "Une erreur est survenue : `n`n" . result
            ; Cas spécial où il y a une erreur de mot de passe, quitte l'application immédiatement
            if (InStr(result, "PASSWORD")) {
                errorText :=
                    "Le mot de passe configuré est incorrect !`n`nVeuillez vérifier le fichier `"config.ini`" `n `nNB : Le compte est peut-être aussi verrouillé suite à de trop nombreuses tentatives incorrectes..."
            }
            errorText := errorText . "`n`nL'éxécution du programme est annulée."
            MsgBox(errorText, "ERREUR !", 48)
            ExitApp()
        }
    }
    return result
}

GuiIsActive() {
    return WinActive("ahk_id " ListSMSGUI.Hwnd)
}

RefreshWifiStatus(force) {
    global wifiStatus
    if (force = True) {
        wifiStatus := RunBoxCmd("get-wifi")
        wifiStatus := Trim(wifiStatus, "`r`n")
    }

    ; Adaptation des labels du statut WIFI
    wifiLabelCmd := "Activer le WIFI"
    if (wifiStatus = 1) {
        wifiLabelCmd := "Désactiver le WIFI"
    }
    SwitchWifiButton.Text := wifiLabelCmd
    trayMenu.Rename("3&", wifiLabelCmd)
}

GetXMLValue(xml, pattern, default := 0) {
    local node
    return RegExMatch(xml, pattern, &node) ? node.1 : default
}

SwitchWifi(*) {
    if (BoxIsReachable(true)) {
        global wifiStatus

        SwitchWifiButton.Enabled := false
        trayMenu.Disable("3&") ; Wifi

        if (wifiStatus = 1) {
            TrayTip("Désactivation du WIFI...", "BOX 4G", 36)
            RunBoxCmd("deactivate-wifi")
        } else {
            TrayTip("Activation du WIFI...", "BOX 4G", 36)
            RunBoxCmd("activate-wifi")
        }
        Sleep(5000) ; laisse le temps au wifi de changer de statut

        SwitchWifiButton.Enabled := true
        trayMenu.Enable("3&") ; Wifi

        RefreshWifiStatus(true)
        BoxIsReachable(false)
    }
}

TimeToDateTimeValue(timeStr) {
    ; timeStr doit être au format HH:mm
    if !RegExMatch(timeStr, "^\d{2}:\d{2}$")
        throw Error("Format d'heure invalide : " timeStr)

    hh := SubStr(timeStr, 1, 2)
    mm := SubStr(timeStr, 4, 2)
    return A_YYYY . A_MM . A_DD . hh . mm . "00"
}

DateTimeValueToTime(dateTimeValue) {
    ; dateTimeValue est du type YYYYMMDDHHMMSS
    return SubStr(dateTimeValue, 9, 2) ":" SubStr(dateTimeValue, 11, 2)
}

IsPhoneNumber(number) {
    number := Trim(number)
    return RegExMatch(number, "^\d+$")
}

; ########  ######## ######## ########  ########  ######  ##     ##
; ##     ## ##       ##       ##     ## ##       ##    ## ##     ##
; ##     ## ##       ##       ##     ## ##       ##       ##     ##
; ########  ######   ######   ########  ######    ######  #########
; ##   ##   ##       ##       ##   ##   ##             ## ##     ##
; ##    ##  ##       ##       ##    ##  ##       ##    ## ##     ##
; ##     ## ######## ##       ##     ## ########  ######  ##     ##

Refresh(*) {
    global data
    global wifiStatus
    global lastIcon
    global refreshing

    ; Annule si refresh déjà en cours
    if (refreshing) {
        return
    }

    ; Nettoyage
    data := {}
    LV_SMS.Delete() ; Vide la liste des sms
    ClearFullSMS()
    ; Init
    tooltipTitle := "Aucun nouveau message"
    lastIcon := "noSMS"

    ; Vérifie si la box est joignable
    if (!BoxIsReachable(false)) {
        return
    }

    ; GO REFRESH
    refreshing := true
    quiet := !GuiIsActive()

    RefreshButton.Enabled := false
    DeleteAllButton.Enabled := false
    ReadAllButton.Enabled := false

    SetTrayIcon("load")

    if (!quiet) {
        TextInfo.Value := "Actualisation, merci de patienter..."
    }

    RefreshContactsArray()

    try {
        ; Récupération de tous les comptes de la boite et du statut du wifi
        SMSCountsXML := RunBoxCmd("get-count All")

        wifiStatus := GetXMLValue(SMSCountsXML, "<wifiStatus>(\d+)</wifiStatus>")
        data.unreadSMSCount := GetXMLValue(SMSCountsXML, "<LocalUnread>(\d+)</LocalUnread>")
        data.inboxSMSCount := GetXMLValue(SMSCountsXML, "<LocalInbox>(\d+)</LocalInbox>")
        data.outboxSMSCount := GetXMLValue(SMSCountsXML, "<LocalOutbox>(\d+)</LocalOutbox>")

        RefreshWifiStatus(False)

        ; INBOX
        if (data.inboxSMSCount > 0) {
            inboxSMSXML := RunBoxCmd("get-sms 1")
            inboxSMSNodes := ConvertXMLtoArray(inboxSMSXML, "//response/Messages/Message")
            data.inboxSMSList := inboxSMSNodes
        }
        ; OUTBOX
        if (data.outboxSMSCount > 0) {
            outboxSMSXML := RunBoxCmd("get-sms 2")
            outboxSMSNodes := ConvertXMLtoArray(outboxSMSXML, "//response/Messages/Message")
            data.outboxSMSList := outboxSMSNodes
        }

    } finally {
        tooltipUnread := ""
        if (data.inboxSMSCount > 0 || data.outboxSMSCount > 0) {
            DeleteAllButton.Enabled := True

            ; Préparation de l'infobulle & de l'icone
            if (data.unreadSMSCount > 0) {
                tooltipUnread := " ⭐ " data.unreadSMSCount " non lu" (data.unreadSMSCount > 1 ? "s" : "")
                ReadAllButton.Enabled := True
                ; actualisation de l'icone AVANT CreateSmsList() pour avoir la bonne icone
                lastIcon := "more"
                SetTrayIcon(lastIcon)
            }

            ; Création de la liste
            if (data.inboxSMSCount > 0) {
                CreateSmsList(1, data.inboxSMSList)
            }
            if (data.outboxSMSCount > 0) {
                CreateSmsList(2, data.outboxSMSList)
            }
        }

        ; actualisation de l'infobulle de l'icone
        A_IconTip := data.inboxSMSCount " reçu" (data.inboxSMSCount > 1 ? "s" : "") tooltipUnread "`n" data.outboxSMSCount " envoyé" (
            data.outboxSMSCount > 1 ? "s" : "")

        ; Redimenssionnement auto
        LV_SMS.ModifyCol()
        ; Tri par date
        LV_SMS.ModifyCol(3, "SortDesc")
        LV_SMS.ModifyCol(5, 0)
        LV_SMS.ModifyCol(6, 0)
        LV_SMS.ModifyCol(7, 0)

        ; désélectionner toutes les lignes
        LV_SMS.Modify(0, "-Select")

        RefreshButton.Enabled := true

        ; Si l'icone n'a pas changé
        if (lastIcon != "more") {
            lastIcon := "noSMS"
            SetTrayIcon(lastIcon)
        }
        if (!quiet) {
            TextInfo.Value := ""
        }
        CheckForWifiAutoSwitch()
        refreshing := false
    }
}

; ##       ####  ######  ########   ######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######
; ##        ##  ##    ##    ##      ##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ##
; ##        ##  ##          ##      ##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##
; ##        ##   ######     ##      ######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######
; ##        ##        ##    ##      ##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ##
; ##        ##  ##    ##    ##      ##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ##
; ######## ####  ######     ##      ##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######

ListSMSGUIOpen() {
    ListSMSGUI.Show()
}

ListSMSGUICLose(*) {
    ListSMSGUI.Hide()
}

ClearFullSMS() {
    FullNumeroEdit.Text := ""
    FullDateText.Text := ""
    FullMessageEdit.Text := helpText
}

CreateSmsList(boxType, SMSList) {
    if (SMSList.Length) {
        messages := SMSList.item(0)
        while messages {
            iconID := boxType
            indexMessage := messages.getElementsByTagName("Index").item[0].text
            phoneNumber := messages.getElementsByTagName("Phone").item[0].text
            phoneNumber := StrReplace(phoneNumber, "+", "")
            phoneNumber := StrReplace(phoneNumber, 33, 0)
            ; Recherche du nom dans les contacts
            contactName := GetContactNameByNumber(phoneNumber)
            dateMessage := messages.getElementsByTagName("Date").item[0].text
            dateMessage := "Le " . SubStr(dateMessage, 1, 10) . "  à  " . SubStr(dateMessage, 12, 19)
            contentMessage := Utf8ToText(messages.getElementsByTagName("Content").item[0].text)
            ; Check si le message est "unread", icone spéciale + traytip
            if (messages.getElementsByTagName("Smstat").item[0].text = 0) {
                iconID := "3"
                ; Si le message est trop long (max 120 traytip Windows) alors on coupe et ...
                if (StrLen(contentMessage) > 120) {
                    contentMessageTT := SubStr(contentMessage, 1, 120) "..."
                } else {
                    contentMessageTT := contentMessage
                }

                if !WinExist("ahk_id " ListSMSGUI.Hwnd) {
                    ; affichage d'une notification pour chaque message si interface non affichée
                    TrayTip(contentMessageTT, "SMS Box4G : " contactName, 36)
                }
            }
            contentMessage := StrReplace(contentMessage, "`n", A_Space " ↳ " A_Space)
            LV_SMS.Add("Icon" . iconID " Select ", , contactName, dateMessage, contentMessage, indexMessage, iconID,
                phoneNumber)
            messages := SMSList.nextNode
        }
    }
}

OpenListSMSGUI(*) {
    ListSMSGUIOpen()
}

ListSMSRightClick(LV_SMS, SelectedRowNumber, *) {
    selectedRowsCount := LV_SMS.GetCount("S")
    if (selectedRowsCount > 1) {
        return ; Pas de menu contextuel si plusieurs lignes sélectionnées
    }
    if (SelectedRowNumber > 0) {
        SMSType := LV_SMS.GetText(SelectedRowNumber, 6)
        ; Adaptation du menu en fonction du type de message
        ; 1 = inbox, 2 = outbox, 3 = inbox unread
        if (SMSType == 3) {
            ListSMS_RCMenu.Enable("Marquer comme lu")
        } else {
            ListSMS_RCMenu.Disable("Marquer comme lu")
        }
        if (SMSType == 2) {
            ListSMS_RCMenu.Disable("Répondre")
        } else {
            ListSMS_RCMenu.Enable("Répondre")
        }
        ListSMS_RCMenu.Show()
    }
}

ListSMSClick(LV_SMS, SelectedRowNumber) {
    selectedRowsCount := LV_SMS.GetCount("S")
    if (selectedRowsCount > 0) {
        DeleteAllButton.Text := "Supprimer la sélection"
        ReadAllButton.Text := "Marquer la sélection comme lue"
    } else {
        DeleteAllButton.Text := "Tout supprimer"
        ReadAllButton.Text := "Tout marquer comme lu"
    }
    if (selectedRowsCount != 1) {
        ClearFullSMS()
    }
    else {
        ; récupère les données de la ligne cliquée
        longNumero := LV_SMS.GetText(SelectedRowNumber, 2)
        longDate := LV_SMS.GetText(SelectedRowNumber, 3)
        longText := LV_SMS.GetText(SelectedRowNumber, 4)

        ; met à jour les champs d'affichage complet
        FullNumeroEdit.Text := longNumero
        FullDateText.Text := longDate
        longText := StrReplace(longText, A_Space " ↳ " A_Space, "`r`n")
        FullMessageEdit.Text := longText
    }
}

Reply(*) {
    TagSMSAsRead(false)
    ; Si des contacts sont configurés, désactivation de la liste des contacts si réponse directe
    if (contactsArray.Length) {
        DDLContactChoice.Enabled := False
        DDLContactChoice.Text := ""
    }
    SelectedRowNumber := LV_SMS.GetNext(0, "F")  ; Récupère la ligne sélectionnée
    if (SelectedRowNumber > 0) {
        phoneNumber := LV_SMS.GetText(SelectedRowNumber, 7)
        numberDest.Text := phoneNumber
        SetDDLContactChoiceByNumber(phoneNumber)
    }
    numberDest.Enabled := False
    SendSMSGUI.Show()
    messageToDest.focus()
}

DeleteSMS(*) {
    listOfIndex := []
    selectedRowsCount := LV_SMS.GetCount("S") ; récupère les lignes sélectionnées

    if (selectedRowsCount = 0) {
        msg :=
            "Aucun message n'a été sélectionné donc tous les messages vont être supprimés définitivement, c'est sûr ?"
    } else {
        RowNumber := 0
        loop selectedRowsCount {
            RowNumber := LV_SMS.GetNext(RowNumber)
            index := LV_SMS.GetText(RowNumber, 5)
            listOfIndex.push(index)
        }
        if (selectedRowsCount = 1) {
            msg := "Ce message sera supprimé définitivement, c'est sûr ?"
        } else {
            msg := listOfIndex.Length " messages seront supprimés définitivement, c'est sûr ?"
        }
    }

    ; Confirmation avant suppression
    msgResult := MsgBox(msg, "ATTENTION !", 49)

    if (msgResult = "OK") {
        TextInfo.Value := "Suppression en cours..."
        if (listOfIndex.length = 0) {
            RunBoxCmd("delete-all")
        } else {
            loop listOfIndex.Length {
                RunBoxCmd("delete-sms " listOfIndex[A_Index])
            }
        }
        TextInfo.Value := ""
        Refresh()
    }
}

TagSMSAsReadButtonClick(*) {
    TagSMSAsRead(true)
}

TagSMSAsRead(doRefresh := true) {
    listOfIndex := []
    selectedRowsCount := LV_SMS.GetCount("S")

    if (selectedRowsCount > 0) {
        RowNumber := 0
        loop selectedRowsCount {
            RowNumber := LV_SMS.GetNext(RowNumber)
            boxType := LV_SMS.GetText(RowNumber, 6)
            if (boxType = 3) { ; Vérifie qu'ils sont bien en non-lus, sinon le Powershell bug
                index := LV_SMS.GetText(RowNumber, 5)
                listOfIndex.push(index)
            }
        }
    }

    TextInfo.Value := "Marquage en cours..."
    if (selectedRowsCount = 0) {
        RunBoxCmd("read-all")
    } else {
        loop listOfIndex.Length {
            RunBoxCmd("read-sms " listOfIndex[A_Index])
        }
    }
    TextInfo.Value := ""
    if (doRefresh) {
        Refresh()
    }
}

;   ######  ##     ##  ######     ######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######
;  ##    ## ###   ### ##    ##    ##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ##
;  ##       #### #### ##          ##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##
;   ######  ## ### ##  ######     ######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######
;        ## ##     ##       ##    ##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ##
;  ##    ## ##     ## ##    ##    ##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ##
;   ######  ##     ##  ######     ##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######

SendSMSGUIShow(*) {
    if (BoxIsReachable(true)) {
        RefreshContactsArray()
        if (contactsArray.Length) {
            itemsForDDL := [] ; array simple pour remplir la dropdownlist

            for _, contactObj in contactsArray {
                itemsForDDL.Push(contactObj.name)
            }

            DDLContactChoice.Delete()
            DDLContactChoice.Add(itemsForDDL)

            ; Init
            DDLContactChoice.Enabled := True
            DDLContactChoice.Value := 1
            OnDDLContactChoiceChange()
        } else {
            DDLContactChoice.Enabled := False
            DDLContactChoice.Value := 0
            numberDest.Text := ""
        }
        numberDest.Enabled := True
        SendSMSGUI.Show()
        messageToDest.focus()
    }
}

OnDestNumberEdit(*) {
    ; Cherche si un contact a le numéro saisi pour l'afficher en DDL
    num := numberDest.Text
    SetDDLContactChoiceByNumber(num)
}

OnDDLContactChoiceChange(*) {
    ; Remplit le numéro du contact choisi
    id := DDLContactChoice.Value
    if id {
        numberDest.Text := contactsArray[id].num
    }
}

FindContactByNumber(phoneNumber) {
    global contactsArray
    for id, contact in contactsArray {
        if contact.num = phoneNumber
            return { id: id, contact: contact }
    }
    return false
}

SetDDLContactChoiceByNumber(phoneNumber) {
    result := FindContactByNumber(phoneNumber)
    DDLContactChoice.Value := result ? result.id : ""
}

GetContactNameByNumber(phoneNumber) {
    result := FindContactByNumber(phoneNumber)
    return result ? Utf8ToText(result.contact.name) : phoneNumber
}

SendSMSGUIClose(*) {
    SendSMSGUI.Hide()
}

SendSMSGUISend(*) {
    global messageToDest
    SendSMSGUI.Submit("0")
    if (!messageToDest.Text) {
        MsgBox("Aucun message saisi !!", "Erreur", 48)
        return
    }

    if (!numberDest.Text) {
        MsgBox("Aucun numéro saisi !!", "Erreur", 48)
        return
    }

    if (DDLContactChoice.Text != "") {
        dest := "à " . DDLContactChoice.Text
    } else {
        dest := "au " . numberDest.Text
    }

    msgResult := MsgBox("Le message suivant va être envoyé " dest " : `n`n « " messageToDest.Text " » `n `n Confirmer l'envoi ?",
        "Confirmation", 33)
    if (msgResult = "OK") {
        SendSMSGUI.Hide()
        ; Passe par un fichier texte temporaire pour forcer l'UTF-8
        tempFile := "sms.txt"
        if (FileExist(tempFile)) {
            FileDelete tempFile
        }
        FileAppend messageToDest.Text, tempFile, "`n UTF-8"
        sendReturn := RunBoxCmd("send-sms `"" tempFile "`" `"" numberDest.Text "`"")
        if (InStr(sendReturn, "<response>OK</response>")) {
            messageToDest.Text := ""
            SendSMSGUI.Hide()
            TextInfo.Value := "Le message a bien été envoyé !"
            Sleep(2000)
            Refresh()
            TextInfo.Value := ""
        } else {
            MsgBox("Le message n'a pas pu être envoyé. `n Veuillez vérifier votre saisie...", "ERREUR", 48)
            SendSMSGUI.Show()
        }
    }
}

;  ######   #######  ##    ## ########    ######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######
; ##    ## ##     ## ###   ## ##          ##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ##
; ##       ##     ## ####  ## ##          ##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##
; ##       ##     ## ## ## ## ######      ######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######
; ##       ##     ## ##  #### ##          ##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ##
; ##    ## ##     ## ##   ### ##          ##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ##
;  ######   #######  ##    ## ##          ##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######

ConfigGUIOpen(*) {
    ipRouterEdit.Value := ipRouter
    usernameEdit.Value := username
    passwordEdit.Value := password
    delayEdit.Value := loopDelay
    autoWifiOffEdit.Value := TimeToDateTimeValue(autoWifiOff)
    autoWifiOffStatusCB.Value := autoWifiOffStatus
    autoWifiOnEdit.Value := TimeToDateTimeValue(autoWifiOn)
    autoWifiOnStatusCB.Value := autoWifiOnStatus

    ConfigGUI.Show()
    ConfigGUICancelButton.Focus()
}

ConfigGUIReset(*) {
    msgResult := MsgBox("Tous la configuration va être réinitialisée aux valeurs par défaut.`n Confirmer ?",
        "Confirmation", 33)
    if (msgResult = "OK") {
        ipRouterEdit.Value := default_ipRouter
        usernameEdit.Value := default_username
        passwordEdit.Value := default_password
        delayEdit.Value := default_loopDelay
        autoWifiOffEdit.Value := TimeToDateTimeValue(default_autoWifiOff)
        autoWifiOffStatusCB.Value := default_autoWifiOffStatus
        autoWifiOnEdit.Value := TimeToDateTimeValue(default_autoWifiOn)
        autoWifiOnStatusCB.Value := default_autoWifiOnStatus
    }
}

ConfigGUIClose(*) {
    ConfigGUI.Hide()
}

ConfigGUIValid(*) {
    global ipRouter, username, password, loopDelay, autoWifiOff, autoWifiOffStatus, autoWifiOn, autoWifiOnStatus

    tmpIP := ipRouterEdit.Value
    tmpUsername := usernameEdit.Value
    tmpPassword := passwordEdit.Value
    tmpDelay := Trim(delayEdit.Value)
    tmpAutoWifiOff := DateTimeValueToTime(autoWifiOffEdit.Value)
    tmpAutoWifiOn := DateTimeValueToTime(autoWifiOnEdit.Value)

    ; Vérifications bloquantes
    if (!ValidIP(tmpIP)) {
        MsgBox("Adresse IP invalide !", "Erreur", 48)
        return
    }

    if (!tmpUsername) {
        MsgBox("Nom d'utilisateur vide !", "Erreur", 48)
        return
    }

    if (!tmpPassword) {
        MsgBox("Mot de passe vide !", "Erreur", 48)
        return
    }

    if (!RegExMatch(tmpDelay, "i)^\d+[smh]$")) {
        MsgBox("La période doit être de la forme '5s', '5m' ou '5h'.", "Erreur", 48)
        return
    }

    if (!RegExMatch(tmpAutoWifiOff, "^\d{2}:\d{2}$")) {
        MsgBox("L'heure de désactivation doit être au format HH:MM.", "Erreur", 48)
        return
    }

    if (!RegExMatch(tmpAutoWifiOn, "^\d{2}:\d{2}$")) {
        MsgBox("L'heure de d'activation doit être au format HH:MM.", "Erreur", 48)
        return
    }

    ipRouter := tmpIP
    username := tmpUsername
    password := tmpPassword
    loopDelay := tmpDelay
    autoWifiOff := tmpAutoWifiOff
    autoWifiOffStatus := autoWifiOffStatusCB.Value + 0
    autoWifiOn := tmpAutoWifiOn
    autoWifiOnStatus := autoWifiOnStatusCB.Value + 0

    IniWrite(ipRouter, "config.ini", "main", "ROUTER_IP")
    IniWrite(username, "config.ini", "main", "ROUTER_USERNAME")
    IniWrite(password, "config.ini", "main", "ROUTER_PASSWORD")
    IniWrite(loopDelay, "config.ini", "main", "DELAY")
    IniWrite(autoWifiOff, "config.ini", "main", "AUTO_WIFI_OFF")
    IniWrite(autoWifiOffStatus, "config.ini", "main", "AUTO_WIFI_OFF_STATUS")
    IniWrite(autoWifiOn, "config.ini", "main", "AUTO_WIFI_ON")
    IniWrite(autoWifiOnStatus, "config.ini", "main", "AUTO_WIFI_ON_STATUS")

    ConfigGUI.Hide()
}

ConfigGUIOpenFile(*) {
    Run("config.ini")
}

;  ######   #######  ##    ## ########    ###     ######  ########  ######     ######## ##     ## ##    ##  ######
; ##    ## ##     ## ###   ##    ##      ## ##   ##    ##    ##    ##    ##    ##       ##     ## ###   ## ##    ##
; ##       ##     ## ####  ##    ##     ##   ##  ##          ##    ##          ##       ##     ## ####  ## ##
; ##       ##     ## ## ## ##    ##    ##     ## ##          ##     ######     ######   ##     ## ## ## ## ##
; ##       ##     ## ##  ####    ##    ######### ##          ##          ##    ##       ##     ## ##  #### ##
; ##    ## ##     ## ##   ###    ##    ##     ## ##    ##    ##    ##    ##    ##       ##     ## ##   ### ##    ##
;  ######   #######  ##    ##    ##    ##     ##  ######     ##     ######     ##        #######  ##    ##  ######

ContactsGUIOpen(*) {
    LV_Contacts.Delete()
    RefreshContactsArray()

    if (contactsArray.Length > 0) {
        for _, contactObj in contactsArray {
            LV_Contacts.Add("", contactObj.name, contactObj.num)
        }
        LV_Contacts.ModifyCol(1, "AutoHdr")
        LV_Contacts.ModifyCol(2, "AutoHdr")
    }

    EditContactsGUI.Show()
}

; --- Fonctions helpers ---
DeleteSelectedContact(LV_Contacts) {
    Row := LV_Contacts.GetNext()
    if Row
        LV_Contacts.Delete(Row)
}

MoveContactRow(LV_Contacts, Dir) {
    Row := LV_Contacts.GetNext()
    if !Row
        return
    NewRow := Row + Dir
    if NewRow < 1 || NewRow > LV_Contacts.GetCount()
        return
    contact := [LV_Contacts.GetText(Row, 1), LV_Contacts.GetText(Row, 2)]
    LV_Contacts.Delete(Row)
    LV_Contacts.Insert(NewRow, "", contact*)
    LV_Contacts.Modify(NewRow, "Select Focus")
    LV_Contacts.Focus()
}

SaveContactsData(LV_Contacts) {
    IniDelete("config.ini", "contacts")

    saveError := "Saisie invalide :`n`n"
    errorCount := 0

    contactsCount := LV_Contacts.GetCount()

    if (contactsCount = 0) {
        IniWrite("", "config.ini", "contacts")
    }
    else {
        ; Replace INI
        loop contactsCount {
            Row := A_Index
            name := LV_Contacts.GetText(Row, 1)
            num := LV_Contacts.GetText(Row, 2)
            if (!name || !num || !IsPhoneNumber(num)) {
                saveError .= name " - " num "`n"
                errorCount++
                continue
            }
            IniWrite(name, "config.ini", "contacts", num)
        }
    }

    if (errorCount > 0) {
        MsgBox(saveError)
    } else {
        EditContactsGUI.Hide()
    }
}

AddAndSelectContact(LV_Contacts) {
    LV_Contacts.Modify(0, "-Select")  ; désélectionne toutes les lignes
    NewRow := LV_Contacts.Insert(1, "Vis", "Nouveau") ; Ajouter une nouvelle ligne
    LV_Contacts.ModifyCol(1, "AutoHdr")
    LV_Contacts.ModifyCol(2, "AutoHdr")
    LV_Contacts.Modify(NewRow, "Select Focus") ; sélectionne la ligne
    LV_Contacts.Focus()
}

; ########  ##     ## ##    ##
; ##     ## ##     ## ###   ##
; ##     ## ##     ## ####  ##
; ########  ##     ## ## ## ##
; ##   ##   ##     ## ##  ####
; ##    ##  ##     ## ##   ###
; ##     ##  #######  ##    ##

loop {
    Refresh()
    Sleep(DelayToMs(loopDelay))
}
