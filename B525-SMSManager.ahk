Persistent 
#Warn
#SingleInstance force ; Force erase previous instance
OnExit(ExitAppli)


DllCall("AllocConsole")
WinHide("ahk_id " DllCall("GetConsoleWindow", "ptr"))

SendMode("Input")  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir(A_ScriptDir)  ; Ensures a consistent starting directory.

OnMessage(0x404, clicOnNotif) ; CLIC sur la notif pour ouvrir la GUI
OnMessage(0x404, OnTrayClick) ; Capture les événements liés au Tray

psShell := "" ; Initialisation de la variable globale pour eviter erreur onExit()

; IMPORT / EXPORT des fichiers annexes pour version compilée
DirCreate("medias")
FileInstall("medias\noSMS.ico", "medias\noSMS.ico", 1)
FileInstall("medias\more.ico", "medias\more.ico", 1)
FileInstall("medias\load.ico", "medias\load.ico", 1)
FileInstall("medias\net.ico", "medias\net.ico", 1)

FileInstall("manage_sms.ps1", "manage_sms.ps1", 1)
FileInstall("version.txt", "version.txt", 1)
FileInstall("updater.cmd", "updater.cmd", 1)

if !FileExist("config.ini") {
	FileInstall("config_sample.ini", "config.ini")
}

#Include "version.txt"


  ; ###   #   #   ###   #####
  ;  #    #   #    #      #
  ;  #    ##  #    #      #
  ;  #    # # #    #      #
  ;  #    #  ##    #      #
  ;  #    #   #    #      #
  ; ###   #   #   ###     #


wifiStatus := 0
lastIcon := "noSMS"
data := {}
helpText := "Cliquer sur une ligne pour afficher et pouvoir sélectionner le texte du SMS dans cette zone. Double-Clic pour répondre... "
refreshing := false

; ICONS
validIconID := "301"
outboxIconID := "195"
unreadIconID := "209"
enableWifiIconID := "53"
openWebPageIconID := "136"
sendSMSIconID := "215"
refreshIconID := "239"
deleteIconID := "32"
quitIconID := "132"
numeroIconID := "Icon161"
dateIconID := "Icon250"
messageIconID := "Icon157"
hideIconID := "176"
cancelIconID := "296"
settingsIconID := "315"
sendIconID := "195"

; GET WINDOWS VERSION
objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" A_ComputerName "\root\cimv2")
For objOperatingSystem in objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
   windowsVersion := objOperatingSystem.Caption
; IF WINDOWS 10
if(InStr(windowsVersion, "10")){
	validIconID := "297"
	unreadIconID := "321"
	dateIconID := "Icon266"
	cancelIconID := "298"
	enableWifiIconID := "51"
}

; Création d'une liste d'icones système pour la ListView
ImageListID := IL_Create(3)
IL_Add(ImageListID, "shell32.dll", validIconID)
IL_Add(ImageListID, "imageres.dll", outboxIconID)
IL_Add(ImageListID, "shell32.dll", unreadIconID)

; Ouverture du powershell permanent
psShell := ComObject("WScript.Shell").Exec("powershell -ExecutionPolicy Bypass -command -")

; Initialisation personnalisée, le cas échéant, des variables globales
ipRouter := IniRead("config.ini", "main", "ROUTER_IP")
if(!ipRouter || !ValidIP(ipRouter)){
	ipRouter := "192.168.8.1" ; Default IP
}
loopDelay := IniRead("config.ini", "main", "DELAY")
if(!loopDelay || !RegExMatch(loopDelay, "^\d+$")){
	loopDelay := "300000" ; Default Loop delay for check
}else{
	loopDelay := loopDelay * 1000
}

setTrayIcon("noSMS")

; CREATION DU TRAYMENU
; *********************
trayMenu:= A_TrayMenu
trayMenu.Delete() ; Delete the standard items.
trayMenu.add("Quitter l'application", ExitAppli)
trayMenu.add()
trayMenu.add("Activer le Wifi", SwitchWifi)
trayMenu.add("Envoyer un SMS", SendSMSGUIShow)
trayMenu.add()
trayMenu.add("Paramètres", openSettings)
trayMenu.add("Vérifier la mise à jour", checkForUpdate)
trayMenu.add()
trayMenu.add("Ouvrir la page Web", openWebPage)
trayMenu.add("Ouvrir l'interface (double clic)", OpenListSMSGUI)
trayMenu.add()
trayMenu.add("Actualiser (clic droit)", refresh)
trayMenu.Default := "Ouvrir l'interface (double clic)"

trayMenu.SetIcon("1&", "shell32.dll", quitIconID)
trayMenu.SetIcon("3&", "ddores.dll", enableWifiIconID)
trayMenu.SetIcon("4&", "shell32.dll", sendSMSIconID)
trayMenu.SetIcon("6&", "shell32.dll", settingsIconID)
trayMenu.SetIcon("9&", "shell32.dll", openWebPageIconID)
trayMenu.SetIcon("12&", "shell32.dll", refreshIconID)


; #      #            #        ##   #  #   ##  			  ##   #  #  ###
; #                   #       #  #  ####  #  # 			 #  #  #  #   #
; #     ##     ###   ###       #    ####   #   			 #     #  #   #
; #      #    ##      #         #   #  #    #  			 # ##  #  #   #
; #      #      ##    #       #  #  #  #  #  # 			 #  #  #  #   #
; ####  ###   ###      ##      ##   #  #   ##  			  ###   ##   ###

; CREATION DE LA GUI PRINCIPALE (LIST SMS)
; ****************************************
ListSMSGUI := Gui("")
ListSMSGUI.Title := "B525-Manager  [" currentVersion "]"

; Top Buttons
RefreshButton := ListSMSGUI.Add("Button", "x10 y8 w100 r2", A_Space . "Actualiser")
ReadAllButton := ListSMSGUI.Add("Button", "x+5 y8 w200 r2 Disabled", A_Space . "Tout marquer comme lu")
DeleteAllButton := ListSMSGUI.Add("Button", "x+5 y8 w150 r2 Disabled", A_Space . "Tout supprimer")
TextInfo := ListSMSGUI.Add("Text", "x+5 y20 w195 h20", "")
openSettingsButton := ListSMSGUI.Add("Button", "x+5 y8 w35 r2", A_Space)

; List View
LV_SMS := ListSMSGUI.Add("ListView", "section xs R10 w700  Grid AltSubmit -Hdr", ["", "contactName", "Time", "Message", "Index", "boxType", "phoneNumber"])

; SMS Details
ListSMSGUI.Add("Picture", "section " . numeroIconID . " w16 h16", "shell32.dll")
FullNumeroEdit := ListSMSGUI.Add("Edit", "ReadOnly x+5 w150 h20")
ListSMSGUI.Add("Picture", "x+5 " . dateIconID . " w16 h16", "shell32.dll")
FullDateText := ListSMSGUI.Add("Text", "x+5 w200 h20 vFullDate")
ListSMSGUI.Add("Picture", "section xs " . messageIconID . " w16 h16", "shell32.dll")
FullMessageEdit := ListSMSGUI.Add("Edit", "ReadOnly x+5 w670 h50 ", helpText)

; Bottom buttons
openWebPageButton := ListSMSGUI.Add("Button", "section xs w150 r2", A_Space . "Page Web de la box 4G")
SwitchWifiButton := ListSMSGUI.Add("Button", "x+40 w140 r2", A_Space . "Activer le Wifi")
SendSMSButton := ListSMSGUI.Add("Button", "x+40 w140 r2", A_Space . "Envoyer un SMS")
HideGUIButton := ListSMSGUI.Add("Button", "x+40 w150 r2", "Cacher la fenêtre")

; BUTTONS ICONS
SetButtonIcon(RefreshButton, "shell32.dll", refreshIconID, 20)
SetButtonIcon(ReadAllButton, "shell32.dll", validIconID, 20)
SetButtonIcon(DeleteAllButton, "shell32.dll", deleteIconID, 20)
SetButtonIcon(openSettingsButton, "shell32.dll", settingsIconID, 20)
SetButtonIcon(openWebPageButton, "shell32.dll", openWebPageIconID, 20)
SetButtonIcon(SwitchWifiButton, "ddores.dll", enableWifiIconID, 20)
SetButtonIcon(SendSMSButton, "shell32.dll", sendSMSIconID, 20)
SetButtonIcon(HideGUIButton, "imageres.dll", hideIconID, 20)

LV_SMS.SetImageList(ImageListID)  ; Assign the above ImageList to the current ListView.

; BUTTONS EVENTS 
RefreshButton.OnEvent("Click", refresh)
ReadAllButton.OnEvent("Click", tagSMSAsRead)
DeleteAllButton.OnEvent("Click", deleteSMS)
openSettingsButton.OnEvent("Click", openSettings)

openWebPageButton.OnEvent("Click", openWebPage)
SwitchWifiButton.OnEvent("Click", SwitchWifi)
SendSMSButton.OnEvent("Click", SendSMSGUIShow)
HideGUIButton.OnEvent("Click", ListSMSGUICLose)

; GUI EVENTS
LV_SMS.OnEvent("Click", ListSMSClick)
LV_SMS.OnEvent("ContextMenu", ListSMSRightClick)
LV_SMS.OnEvent("DoubleClick", reply)
ListSMSGUI.OnEvent("Close", ListSMSGUICLose)
ListSMSGUI.OnEvent("Escape", ListSMSGUICLose)

; Menu au clic-droit
ListSMS_RCMenu := Menu()  ; Création du menu contextuel

; Ajout des éléments avec leurs fonctions associées
ListSMS_RCMenu.Add("Répondre", reply)
ListSMS_RCMenu.Add("Supprimer", deleteSMS)
ListSMS_RCMenu.Add("Marquer comme lu", tagSMSAsRead)
ListSMS_RCMenu.SetIcon("1&", "shell32.dll", cancelIconID)
ListSMS_RCMenu.SetIcon("2&", "shell32.dll", deleteIconID)
ListSMS_RCMenu.SetIcon("3&", "shell32.dll", validIconID)


;  ###                     #   ###   #   #   ###  			  ###   #   #   ###
; #   #                    #  #   #  #   #  #   # 			 #   #  #   #    #
; #       ###   # ##    ## #  #      ## ##  #     			 #      #   #    #
;  ###   #   #  ##  #  #  ##   ###   # # #   ###  			 #      #   #    #
;     #  #####  #   #  #   #      #  #   #      # 			 #  ##  #   #    #
; #   #  #      #   #  #  ##  #   #  #   #  #   # 			 #   #  #   #    #
;  ###    ###   #   #   ## #   ###   #   #   ###  			  ###    ###    ###

; GUI d'envoi de SMS
; *****************************

SendSMSGUI := Gui("")
SendSMSGUI.Title := "Envoi de SMS sur Box4G"

SendSMSGUI.Add("Text", , "Message:")
messageToDest := SendSMSGUI.Add("Edit", "w240 r5 ys")
SendSMSGUI.Add("Text", "section xs w65", "Destinataire :")

contactsList := Array()

iniList := IniRead("config.ini", "contacts")
contactsArray := StrSplit(Utf8ToText(iniList),"`n")

; REFORMAT CONTACTS LIST
if(contactsArray.Length){
	Loop contactsArray.Length
	{
		contactLine := contactsArray[A_Index]
		egalPos := InStr(contactLine, "=")
    	contactsList.push(SubStr(contactLine, egalPos + 1) . " (" . SubStr(contactLine, 1, egalPos - 1) . ")") 
	}
	DDLContactChoice := SendSMSGUI.Add("DropDownList", "ys w200", contactsList)
	DDLContactChoice.OnEvent("Change", ChangeContact)
	SendSMSGUI.Add("Text", "section xs w65", "Numéro :")
}

numberDest := SendSMSGUI.Add("Edit", "ys w80 Limit10 Number")

CancelButton := SendSMSGUI.Add("Button", "section xs  w150 r2", "Annuler")
EnvoiButton := SendSMSGUI.Add("Button", "ys  w150 r2", "Envoi")

; ICONS
SetButtonIcon(CancelButton, "shell32.dll", cancelIconID, 20)
SetButtonIcon(EnvoiButton, "imageres.dll", sendIconID, 20)

; EVENTS
CancelButton.OnEvent("Click", SendSMSGUIGuiClose)
EnvoiButton.OnEvent("Click", SendSMSGUIButtonEnvoi)
SendSMSGUI.OnEvent("Close", SendSMSGUIGuiClose)
SendSMSGUI.OnEvent("Escape", SendSMSGUIGuiClose)

; #####   ###   #   #   ###   #####   ###    ###   #   #   ###
; #      #   #  #   #  #   #    #      #    #   #  #   #  #   #
; #      #   #  ##  #  #        #      #    #   #  ##  #  #
; ####   #   #  # # #  #        #      #    #   #  # # #   ###
; #      #   #  #  ##  #        #      #    #   #  #  ##      #
; #      #   #  #   #  #   #    #      #    #   #  #   #  #   #
; #       ###   #   #   ###     #     ###    ###   #   #   ###

lastClickTime := 0

OnTrayClick(wParam, lParam, msg, hwnd) {
	global trayMenu, lastClickTime
	
    switch lParam {
        case 0x201: ; clic gauche
            now := A_TickCount
            if (now - lastClickTime < 400) {
                ; double clic
                ListSMSGUIOpen()
                lastClickTime := 0
                return
            }
			lastClickTime := now
			SetTimer(WaitForDoubleClick, -400)
        case 0x204:
		case 0x205: ; clic droit up
            refresh()
            return true
    }
}

WaitForDoubleClick(*){
	global trayMenu, lastClickTime
	if(!guiIsActive() || lastClickTime == 0){
		trayMenu.Show()
		lastClickTime := 0
	}
}

; POWERSHELL FUNCTIONS
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
    if (psShell) {
		try {
			psShell.StdIn.WriteLine("exit")  ; Ferme la session PowerShell
		} catch {
			; Ignore l'erreur si PS est déjà en train de se fermer
		}
		try {
			psShell.Terminate()
		} catch {
			; Ignore si déjà fermé
		}
		psShell := ""  ; Libère l'objet
    }
}

; Fonction qui permets de cliquer sur la notif Windows pour ouvrir la GUI
clicOnNotif(wParam, lParam, msg, hwnd){
	if (hwnd != A_ScriptHwnd)
		return
	if (lParam = 1029)
		ListSMSGUIOpen()
}

; Permet de valider une IP
ValidIP(IPAddress){
	; Expression régulière pour une adresse IPv4 valide
    RegEx := "^\b(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$"

    ; Utilisation de RegExMatch pour tester l'adresse IP
    if (RegExMatch(IPAddress, RegEx)) {
        return true
    }
    return false
}

Utf8ToText(vUtf8){
  if 1
  {
    VarSetStrCapacity(&vTemp, StrPut(vUtf8, "CP0"))
    StrPut(vUtf8, StrPtr(vTemp), "CP0")
    return StrGet(StrPtr(vTemp), "UTF-8")
  }
  else
    return StrGet(&vUtf8, "UTF-8")
}

convertXMLtoArray(xmldata , rootNode){
	xmldata := RegExReplace(xmldata, "\r")
	xmlObj := ComObject("MSXML2.DOMDocument.6.0")
	xmlObj.async := false
	xmlObj.loadXML(xmldata)
	nodes := xmlObj.selectNodes(rootNode)
	return nodes
}

; Fonction spéciale pour les GUI, permet d'afficher une icone dans un bouton
SetButtonIcon(Button, File, Index, Size := 16) {
    hIcon := LoadPicture(File,"h" . Size . " Icon" . Index,&_)
    ErrorLevel := SendMessage(0xF7, 1, hIcon, , "ahk_id " Button.hwnd)
}

openSettings(*){
	Run("config.ini")
}

ExitAppli(*){
	ClosePS()
	ExitApp()
}

openWebPage(*) {
 	Run("http://" ipRouter "/html/smsinbox.html")
}

setTrayIcon(iconName){
	if !iconName
		iconName := lastIcon
	iconFile := "medias\" . iconName . ".ico"
	TraySetIcon(iconFile)
}

checkForWifiAutoOff(){
	; If Wifi enabled
	if(wifiStatus = 1){
		; check if wifi off is set
		autoWifiOff := IniRead("config.ini", "main", "AUTO_WIFI_OFF")
		if (autoWifiOff && RegExMatch(autoWifiOff, "^\d{2}:\d{2}$")) {
		    ; Récupérer l'heure actuelle
		    currentTime := FormatTime(, "HHmm")
		    autoWifiOffTime := StrReplace(autoWifiOff, ":", "")
		    if (currentTime >= autoWifiOffTime) {
		     	SwitchWifi()
		    }
		}
	}
}

boxIsReachable(ForceTrayTip){
	Global lastIcon
	; Vérification BOX joignable
	cmd := "[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8; Test-Connection " . ipRouter . " -Count 1 -Quiet"	
	result := SendToPS(cmd)

	if(!InStr(result, "True")){	
		noticeText := "La box 4G est injoignable, veuillez vérifier la connexion..."
		
		; Disable buttons 
		trayMenu.Disable("3&") ; Wifi
		trayMenu.Disable("4&") ; Send SMS

		; actualisation de l'icone 
		setTrayIcon("net")
		lastIcon := "net"

		quiet := !guiIsActive()
		if(!quiet || ForceTrayTip){	
			TrayTip(noticeText, "Erreur", 36)
		}
		A_IconTip := noticeText
		netStatus := False
	}else{
		trayMenu.Enable("3&") ; Wifi
		trayMenu.Enable("4&") ; Send SMS
		netStatus := True
	}

	SwitchWifiButton.Enabled := netStatus
	SendSMSButton.Enabled := netStatus
	ReadAllButton.Enabled := netStatus
	DeleteAllButton.Enabled := netStatus

	return netStatus
}

runBoxCmd(command){
	cmd := " " . A_WorkingDir . "\manage_sms.ps1 " . command
	result := SendToPS(cmd)

	; Gestion des erreurs
	if(InStr(result, "ERROR")){
		; Cas spécial où il y a une erreur de joignabilité
		if(InStr(result, "Router unreachable")){
			boxIsReachable(true)
		}else{
			errorText := "Une erreur est survenue : `n`n" . result
			; Cas spécial où il y a une erreur de mot de passe, quitte l'application immédiatement
			if(InStr(result, "PASSWORD")){
				errorText := "Le mot de passe configuré est incorrect !`n`nVeuillez vérifier le fichier `"config.ini`" `n `nNB : Le compte est peut-être aussi verrouillé suite à de trop nombreuses tentatives incorrectes..."
			}
			errorText := errorText . "`n`nL'éxécution du programme est annulée."
			MsgBox(errorText, "ERREUR !", 48)
			ExitApp()
		}
	}
	return result
}

guiIsActive(){
	return WinActive("ahk_id " ListSMSGUI.Hwnd)
}

refreshWifiStatus(force){
	Global wifiStatus
	if(force = True){
		wifiStatus := runBoxCmd("get-wifi")
		wifiStatus := Trim(wifiStatus, "`r`n")
	}

	; Adaptation des labels du statut WIFI
	wifiLabelCmd := "Activer le WIFI"
	if(wifiStatus = 1){
		wifiLabelCmd := "Désactiver le WIFI"
	}
	SwitchWifiButton.Text := wifiLabelCmd
	trayMenu.Rename("3&", wifiLabelCmd)
}

GetXMLValue(xml, pattern, default := 0) {
    local node
    return RegExMatch(xml, pattern, &node) ? node.1 : default
}

refresh(*){
	Global data
	Global wifiStatus
	Global lastIcon
	Global refreshing

	; Prevent refresh in use
	if(refreshing){
		return
	}

	; Clean data
	data := {}
	LV_SMS.Delete() ; clear the table
	clearFullSMS()
	; Init
	tooltipTitle := "Aucun nouveau message"
	lastIcon := "noSMS"

	; Check for network first
	if(!boxIsReachable(false)){
		return 
	}

	; NETWORK IS OK => GO REFRESH
	refreshing := true
	quiet := !guiIsActive()

	RefreshButton.Enabled := false
	DeleteAllButton.Enabled := false
	ReadAllButton.Enabled := false

	setTrayIcon("load")
	
	if(!quiet){
		TextInfo.Value := "Actualisation, merci de patienter..."
	}
	
	
	try {
		; Récupération de tous les comptes de la boite et du statut du wifi
		SMSCountsXML := runBoxCmd("get-count All")

		wifiStatus := GetXMLValue(SMSCountsXML, "<wifiStatus>(\d+)</wifiStatus>")
		data.unreadSMSCount := GetXMLValue(SMSCountsXML, "<LocalUnread>(\d+)</LocalUnread>")
		data.inboxSMSCount := GetXMLValue(SMSCountsXML, "<LocalInbox>(\d+)</LocalInbox>")
		data.outboxSMSCount := GetXMLValue(SMSCountsXML, "<LocalOutbox>(\d+)</LocalOutbox>")
		
		refreshWifiStatus(False)

		; INBOX
		if(data.inboxSMSCount > 0){
			inboxSMSXML := runBoxCmd("get-sms 1") 
			inboxSMSNodes := convertXMLtoArray(inboxSMSXML, "//response/Messages/Message")
			data.inboxSMSList := inboxSMSNodes
		}
		; OUTBOX
		if(data.outboxSMSCount > 0){
			outboxSMSXML := runBoxCmd("get-sms 2")
			outboxSMSNodes := convertXMLtoArray(outboxSMSXML, "//response/Messages/Message")
			data.outboxSMSList := outboxSMSNodes
		}		
		
	} finally {
		tooltipUnread := ""
		if(data.inboxSMSCount > 0 || data.outboxSMSCount > 0){
			DeleteAllButton.Enabled := True

			; TOOLTIP UPDATE
			If (data.unreadSMSCount > 0){
				tooltipUnread := " ⭐ " data.unreadSMSCount " non lu" (data.unreadSMSCount > 1 ? "s" : "")
				ReadAllButton.Enabled := True
				; actualisation de l'icone BEFORE createSmSlist() TO HAVE GOOD ICON
				lastIcon := "more"
				setTrayIcon(lastIcon)
			}

			; Création de la liste
			if(data.inboxSMSCount > 0){
				createSmsList(1,data.inboxSMSList)
			}
			if(data.outboxSMSCount > 0){
				createSmsList(2,data.outboxSMSList)
			}
		}

		; actualisation de l'infobulle de l'icone
		A_IconTip := data.inboxSMSCount " reçu" (data.inboxSMSCount > 1 ? "s" : "")  tooltipUnread "`n" data.outboxSMSCount " envoyé" (data.outboxSMSCount > 1 ? "s" : "")


		; Auto-size
		LV_SMS.ModifyCol()
		; Sort by Date  
		LV_SMS.ModifyCol(3, "SortDesc")
		LV_SMS.ModifyCol(5, 0)
		LV_SMS.ModifyCol(6, 0)
		LV_SMS.ModifyCol(7, 0)

		; désélectionner toutes les lignes
		LV_SMS.Modify(0, "-Select")  

		RefreshButton.Enabled := true
		
		; If lastIcon has not changed 
		if(lastIcon != "more"){
			lastIcon := "noSMS"
			setTrayIcon(lastIcon)
		}
		if(!quiet){
			TextInfo.Value := ""
		}
		checkForWifiAutoOff()
		refreshing := false
	}
}

SwitchWifi(*){
	if(boxIsReachable(true)){
		Global wifiStatus
		
		SwitchWifiButton.Enabled := false
		trayMenu.Disable("3&") ; Wifi

		if(wifiStatus = 1){
			TrayTip("Désactivation du WIFI...", "BOX 4G", 36)
			runBoxCmd("deactivate-wifi")
		}else{
			TrayTip("Activation du WIFI...", "BOX 4G", 36)
			runBoxCmd("activate-wifi")
		}
		Sleep(5000) ; laisse le temps au wifi de changer de statut

		SwitchWifiButton.Enabled := true
		trayMenu.Enable("3&") ; Wifi

		refreshWifiStatus(true)
		boxIsReachable(false)
	}
}


; #      #            #        ##   #  #   ##  			  ##   #  #  ###
; #                   #       #  #  ####  #  # 			 #  #  #  #   #
; #     ##     ###   ###       #    ####   #   			 #     #  #   #
; #      #    ##      #         #   #  #    #  			 # ##  #  #   #
; #      #      ##    #       #  #  #  #  #  # 			 #  #  #  #   #
; ####  ###   ###      ##      ##   #  #   ##  			  ###   ##   ###

ListSMSGUIOpen(){
	ListSMSGUI.Show()
}

ListSMSGUICLose(*){
	ListSMSGUI.Hide()
}

clearFullSMS(){
	FullNumeroEdit.Text := ""
	FullDateText.Text := ""
	FullMessageEdit.Text := helpText
}

createSmsList(boxType, SMSList){
	if( SMSList.Length )	{
		messages := SMSList.item(0)
		while messages {
			iconID := boxType
			indexMessage := messages.getElementsByTagName( "Index" ).item[0].text
			phoneNumber := messages.getElementsByTagName( "Phone" ).item[0].text
			phoneNumber := StrReplace(phoneNumber, "+", "")
			phoneNumber := StrReplace(phoneNumber, 33, 0)
			contactName := IniRead("config.ini", "contacts", phoneNumber, phoneNumber)
			contactName := Utf8ToText(contactName)
			dateMessage := messages.getElementsByTagName( "Date" ).item[0].text
			dateMessage := "Le " . SubStr(dateMessage, 1, 10) . "  à  " . SubStr(dateMessage, 12, 19)
			contentMessage := Utf8ToText(messages.getElementsByTagName( "Content" ).item[0].text)
			; Check si le message est "unread", icone spéciale + traytip
			if(messages.getElementsByTagName( "Smstat" ).item[0].text = 0){
					iconID := "3"
					; Si le message est trop long (max 120 traytip Windows) alors on coupe et ...
					if (StrLen(contentMessage) > 120){
						contentMessageTT := SubStr(contentMessage, 1, 120) "..."
					}else{
						contentMessageTT := contentMessage
					}
					
					if ! WinExist("ahk_id " ListSMSGUI.Hwnd){	
						; affichage d'une notification pour chaque message si interface non affichée
						TrayTip(contentMessageTT, "SMS Box4G : " contactName, 36 )
					}
			}
			contentMessage := StrReplace(contentMessage, "`n", A_Space " ↳ " A_Space)
			LV_SMS.Add("Icon" . iconID " Select ", , contactName, dateMessage, contentMessage, indexMessage, iconID, phoneNumber)				
		  messages := SMSList.nextNode
		}
	}
}

OpenListSMSGUI(*){
	ListSMSGUIOpen()
}


ListSMSRightClick(LV_SMS, SelectedRowNumber, *){
	selectedRowsCount := LV_SMS.GetCount("S")
	if(selectedRowsCount > 1){
		return ; No RC menu if multiple selection
	}
	if (SelectedRowNumber > 0){
		SMSType := LV_SMS.GetText(SelectedRowNumber,6)
		; Adaptation du menu en fonction du type de message
		; 1 = inbox, 2 = outbox, 3 = inbox unread
		if(SMSType == 3 ){
			ListSMS_RCMenu.Enable("Marquer comme lu")
		}else{
			ListSMS_RCMenu.Disable("Marquer comme lu")
		}
		if(SMSType == 2 ){
			ListSMS_RCMenu.Disable("Répondre")
		}else{
			ListSMS_RCMenu.Enable("Répondre")
		}
		ListSMS_RCMenu.Show()
	}
}

ListSMSClick(LV_SMS, SelectedRowNumber){
	selectedRowsCount := LV_SMS.GetCount("S")
	if(selectedRowsCount > 0){
		DeleteAllButton.Text := "Supprimer la sélection"
		ReadAllButton.Text := "Marquer la sélection comme lue"
	}else{
		DeleteAllButton.Text := "Tout supprimer"
		ReadAllButton.Text := "Tout marquer comme lu"
	}
	if (selectedRowsCount != 1){
		clearFullSMS()
	}
	else{ 
		; récupère les données de la ligne cliquée
		longNumero := LV_SMS.GetText(SelectedRowNumber,2) 
		longDate := LV_SMS.GetText(SelectedRowNumber,3) 
		longText := LV_SMS.GetText(SelectedRowNumber,4) 
		
		; met à jour les champs d'affichage complet
		FullNumeroEdit.Text := longNumero
		FullDateText.Text := longDate
		longText := StrReplace(longText, A_Space " ↳ " A_Space, "`r`n")
		FullMessageEdit.Text := longText
	}
}

reply(*){
	tagSMSAsRead()
	SelectedRowNumber := LV_SMS.GetNext(0,"F")  ; Find the focused row. 
	if(contactsList.Length){
		DDLContactChoice.Enabled := False
		DDLContactChoice.Text := ""
	}
	numberDest.Text := LV_SMS.GetText(SelectedRowNumber,7)
	numberDest.Enabled := False
	SendSMSGUI.Show()
	messageToDest.focus()
}

deleteSMS(*){
	listOfIndex := []
	selectedRowsCount := LV_SMS.GetCount("S") ; GET CURRENT SELECTED ROWS COUNT

	if(selectedRowsCount = 0){
		msg := "Aucun message n'a été sélectionné donc tous les messages vont être supprimés définitivement, c'est sûr ?"
	}else{
		; GET CURRENT SELECTED ROWS INDEX
		RowNumber := 0 
		Loop selectedRowsCount
		{
		    RowNumber := LV_SMS.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
		    index := LV_SMS.GetText(RowNumber,5)
		    listOfIndex.push(index)
		}
		if(selectedRowsCount = 1){
			msg := "Ce message sera supprimé définitivement, c'est sûr ?"
		}else{
			msg := listOfIndex.Length " messages seront supprimés définitivement, c'est sûr ?"
		}
	}

	msgResult := MsgBox( msg , "ATTENTION !", 49) ; CONFIRM BEFORE DELETE

	if (msgResult = "OK")
	{
		TextInfo.Value := "Suppression en cours..."
		if(listOfIndex.length = 0){
			runBoxCmd("delete-all")
		}else{
			Loop listOfIndex.Length
			{
				runBoxCmd("delete-sms " listOfIndex[A_Index])
			}
		}
		TextInfo.Value := ""
		refresh()
	}
}

tagSMSAsRead(*){
	listOfIndex := []
	selectedRowsCount := LV_SMS.GetCount("S") ; GET CURRENT SELECTED ROWS COUNT

	if(selectedRowsCount > 0){
		; GET CURRENT SELECTED ROWS INDEX
		RowNumber := 0 
		Loop selectedRowsCount
		{
		    RowNumber := LV_SMS.GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
		    boxType := LV_SMS.GetText(RowNumber,6)
		    if(boxType = 3){ ; Only SMS unread else ERROR from Powershell
			    index := LV_SMS.GetText(RowNumber,5)
			    listOfIndex.push(index)
		    }
		}
	}

	TextInfo.Value := "Marquage en cours..."
	if(selectedRowsCount = 0){
		runBoxCmd("read-all")
	}else{
		Loop listOfIndex.Length
		{
			runBoxCmd("read-sms " listOfIndex[A_Index])
		}
	}
	TextInfo.Value := ""
	refresh()
}



;  ###                     #   ###   #   #   ###  		  ###   #   #   ###
; #   #                    #  #   #  #   #  #   # 		 #   #  #   #    #
; #       ###   # ##    ## #  #      ## ##  #     		 #      #   #    #
;  ###   #   #  ##  #  #  ##   ###   # # #   ###  		 #      #   #    #
;     #  #####  #   #  #   #      #  #   #      # 		 #  ##  #   #    #
; #   #  #      #   #  #  ##  #   #  #   #  #   # 		 #   #  #   #    #
;  ###    ###   #   #   ## #   ###   #   #   ###  		  ###    ###    ###

SendSMSGUIShow(*){	
	if(boxIsReachable(true)){
		if(contactsList.Length){
			; Force init
			DDLContactChoice.Enabled := True
			DDLContactChoice.Value := 1
			ChangeContact() 
		}else{
			numberDest.Text := ""
		}
		numberDest.Enabled := True
		SendSMSGUI.Show()
		messageToDest.focus()
	}
}

ChangeContact(*){
	contactChoosen := SubStr(DDLContactChoice.Text, InStr(DDLContactChoice.Text, "(") + 1, -1)
	numberDest.Text := contactChoosen
}


SendSMSGUIGuiClose(*){
	SendSMSGUI.Hide()
}

SendSMSGUIButtonEnvoi(*){
	Global messageToDest
	SendSMSGUI.Submit("0")
	if(!messageToDest.Text){
		MsgBox("Aucun message saisi !!", "Erreur", 48)
		return
	}

	if(!numberDest.Text){
		MsgBox("Aucun numéro saisi !!", "Erreur", 48)
		return
	}

	contactName := IniRead("config.ini", "contacts", numberDest.Text, numberDest.Text)
	contactName := Utf8ToText(contactName)

	if(contactName != "ERROR"){
		dest := "à " . contactName
	}else{
		dest := "au " . numberDest.Text
	}

	msgResult := MsgBox("Le message suivant va être envoyé " dest " : `n`n « " messageToDest.Text " » `n `n Confirmer l'envoi ?", "Confirmation", 33)
	if (msgResult = "OK")
	{
		SendSMSGUI.Hide()
		; Write SMS Text in temp file to avoid UTF8
		tempFile := "sms.txt"
		if(FileExist(tempFile)){
			FileDelete tempFile
		}
		FileAppend messageToDest.Text, tempFile, "`n UTF-8"
		sendReturn := runBoxCmd("send-sms `"" tempFile "`" `"" numberDest.Text "`"")
		if(InStr(sendReturn, "<response>OK</response>")){
			messageToDest.Text := ""
			SendSMSGUI.Hide()
			TextInfo.Value := "Le message a bien été envoyé !"
			Sleep(2000)
			refresh()
			TextInfo.Value := ""
		}else{
			MsgBox("Le message n'a pas pu être envoyé. `n Veuillez vérifier votre saisie...", "ERREUR", 48)
			SendSMSGUI.Show()
		}
	}
}

checkForUpdate(*){
	global currentVersion
	; Crée et configure l'objet HTTP
	http := ComObject("WinHttp.WinHttpRequest.5.1")
	http.Open("GET", "https://api.github.com/repos/jibap/B525-SMSManager/releases/latest", true)
	http.Send()
	http.WaitForResponse()

	json := http.ResponseText

	; --- Extraire la version via Regex ---
	if RegExMatch(json, '"tag_name"\s*:\s*"([^"]+)"', &m)
		latestVersion := m[1]
	else
		latestVersion := ""

	; --- Comparer ---
	if (latestVersion != "" && latestVersion != currentVersion) {
		if MsgBox("Une nouvelle version est disponible: " latestVersion "`n`nMettre à jour maintenant ?", "Mise à jour", 4) = "Yes" {
			; --- Extraire l'URL de l'EXE (premier asset) ---
			if RegExMatch(json, '"browser_download_url"\s*:\s*"([^"]+\.exe)"', &d)
				downloadURL := d[1]
			else
				downloadURL := ""
			; Run(downloadURL)
			; Télécharger le fichier
			tempFile := A_ScriptDir "\B525-SMSManager-Update.exe"
			try {
				Download downloadURL, tempFile
			} catch as err {
				MsgBox("Échec du téléchargement : " err.Message, "Erreur", 48)
				return
			}
			; vérifier si le fichier a été téléchargé
			if !FileExist(tempFile) {
				MsgBox("Le téléchargement de la mise à jour a échoué.", "Erreur", 48)
				return
			}
			MsgBox("La dernière version a bien été téléchargée, le logiciel va maintenant redémarrer pour valider la mise à jour...", "Mise à jour")
			Run(A_ScriptDir "\Updater.cmd")
			ExitApp()	
		}
	} else {
		MsgBox "La version actuelle est la dernière (" currentVersion ")."
	}
}

; ####   #   #  #   #
; #   #  #   #  #   #
; #   #  #   #  ##  #
; ####   #   #  # # #
; # #    #   #  #  ##
; #  #   #   #  #   #
; #   #   ###   #   #

Loop{
	refresh()
	Sleep(loopDelay)
}