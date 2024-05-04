#Persistent
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

OnMessage(0x404, Func("clicOnNotif")) ; CLIC sur la notif pour ouvrir la GUI

; IMPORT / EXPORT des fichiers annexes pour version compilée
FileCreateDir,  medias
FileCreateDir,  scripts
FileInstall, noSMS.ico, %A_WorkingDir%\medias\noSMS.ico
FileInstall, more.ico, %A_WorkingDir%\medias\more.ico
FileInstall, load.ico, %A_WorkingDir%\medias\load.ico
FileInstall, net.ico, %A_WorkingDir%\medias\net.ico
FileInstall, manage_sms.sh, %A_WorkingDir%\scripts\manage_sms.sh
FileInstall, config_sample.ini, %A_WorkingDir%\config.ini

; Transposition du chemin du script pour le BASH
StringReplace , scriptPath, A_WorkingDir , : , 
StringReplace , scriptPath, scriptPath , \ , / , All
; lowercase first letter (partition letter)
scriptPath = % RegExReplace(scriptPath, "^.", "$l0",,1)
StringReplace , scriptPath, scriptPath , %A_Space% , \%A_Space% , All ; For paths with spaces


  ; ###   #   #   ###   #####
  ;  #    #   #    #      #
  ;  #    ##  #    #      #
  ;  #    # # #    #      #
  ;  #    #  ##    #      #
  ;  #    #   #    #      #
  ; ###   #   #   ###     #

wifiStatus = 0
lastIcon = noSMS
helpText = Double-clic sur une ligne pour afficher et pouvoir sélectionner les détails du SMS dans cette zone

; ICONS
validIconID = 301
outboxIconID = 195
unreadIconID = 209
enableWifiIconID = 53
openWebPageIconID = 136
sendSMSIconID = 215
refreshIconID = 239
deleteIconID = 132
numeroIconID = Icon161
dateIconID = Icon250
messageIconID = Icon157
reduceIconID = 248
cancelIconID = 296
settingsIconID = 315


; GET WINDOWS VERSION
objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" A_ComputerName "\root\cimv2")
For objOperatingSystem in objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
   windowsVersion := objOperatingSystem.Caption
; IF WINDOWS 10
if(InStr(windowsVersion, "10")){
	validIconID = 297
	unreadIconID = 321
	dateIconID = Icon266
	cancelIconID = 298
	enableWifiIconID = 51
}

; Initialisation personnalisée, le cas échéant, des variables globales
IniRead, ipRouter, config.ini, main, ROUTER_IP
if(!ipRouter || !ValidIP(ipRouter)){
	ipRouter = "192.168.8.1" ; Default IP
}
IniRead, loopDelay, config.ini, main, DELAY
if(!loopDelay || !RegExMatch(loopDelay,"^\d+$")){
	loopDelay = 300000 ; Default Loop delay for check
}
IniRead, defaultSMS, config.ini, main, DEFAULTSMS
if(!defaultSMS || !RegExMatch(defaultSMS,"^\d+$")){
	defaultSMS = 
}

; Création d'une liste d'icones système pour la ListView
ImageListID := IL_Create(3)
IL_Add(ImageListID, "shell32.dll", validIconID)
IL_Add(ImageListID, "imageres.dll", outboxIconID)
IL_Add(ImageListID, "shell32.dll", unreadIconID)


updateTrayIcon("noSMS")


; CREATION DU TRAYMENU
; *****************************
Menu, tray, NoStandard
Menu, tray, add, Quitter l'application, ExitAppli
Menu, tray, add
Menu, tray, add, Activer le Wifi, SwitchWifi
Menu, tray, add, Envoyer un SMS, SendSMSGUI
Menu, tray, add
Menu, tray, add, Paramètres, openSettings
Menu, tray, add
Menu, tray, add, Ouvrir la page Web, Link
Menu, tray, add, Ouvrir l'interface, OpenListSMSGUI
Menu, tray, add
Menu, tray, add, Actualiser, refreshStatus
Menu, tray, Default,  Ouvrir l'interface

Menu, tray, Icon, Quitter l'application, shell32.dll, %deleteIconID%
Menu, tray, Icon, Paramètres, shell32.dll, %settingsIconID%
Menu, tray, Icon, Activer le Wifi, ddores.dll, %enableWifiIconID%
Menu, tray, Icon, Ouvrir la page Web, shell32.dll, %openWebPageIconID%
Menu, tray, Icon, Envoyer un SMS, shell32.dll, %sendSMSIconID%
Menu, tray, Icon, Actualiser, shell32.dll, %refreshIconID%

; Création de l'interface de liste SMS
Gui, ListSMSGUI: New, +HwndMyGuiHwnd, B525-Manager
Gui, ListSMSGUI:Add, Button, hWndhButton1 x10 y8 w100 r2, %A_Space%Actualiser
SetButtonIcon(hButton1, "shell32.dll", refreshIconID, 20)
Gui, ListSMSGUI:Add, Button, hWndhButton2 x240 y8 w220 r2, %A_Space%Marquer tous les messages comme lus
SetButtonIcon(hButton2, "shell32.dll", validIconID, 20)
Gui, ListSMSGUI:Add, Button, hWndhButton3 x470 y8 w200 r2, %A_Space%Supprimer tous les messages
SetButtonIcon(hButton3, "shell32.dll", deleteIconID, 20)
Gui, ListSMSGUI:Add, Button, hWndhButton6 x675 y8 w35 r2, %A_Space%
SetButtonIcon(hButton6, "shell32.dll", settingsIconID, 20)
Gui, ListSMSGUI:Add, ListView, section xs R10 w700 vLVSMS gListSMSTrigger Grid AltSubmit,  | Numéro | Date - Heure | Message
Gui, ListSMSGUI:Add, Picture, section %numeroIconID% w16 h16, shell32.dll
Gui, ListSMSGUI:Add, Edit, ReadOnly ys w150 h20 vFullNumero, 
Gui, ListSMSGUI:Add, Picture, ys %dateIconID% w16 h16, shell32.dll
Gui, ListSMSGUI:Add, Text, ys w200 h20 vFullDate, 
Gui, ListSMSGUI:Add, Picture, section xs %messageIconID% w16 h16, shell32.dll
Gui, ListSMSGUI:Add, Edit, ReadOnly ys w670 h50 vFullMessage, %helpText%
Gui, ListSMSGUI:Add, Button, section xs hWndhButton5  w150 r2 gLink, %A_Space%Ouvrir la page Web
SetButtonIcon(hButton5, "shell32.dll", openWebPageIconID, 20)
Gui, ListSMSGUI:Add, Button, ys hWndhButtonWifi x200 w140 r2 vWifiStatusButton gSwitchWifi, %A_Space%Activer le Wifi
SetButtonIcon(hButtonWifi, "ddores.dll", enableWifiIconID, 20)
Gui, ListSMSGUI:Add, Button, ys hWndhButton4 x380 w140 r2 gSendSMSGUI, %A_Space%Envoyer un SMS
SetButtonIcon(hButton4, "shell32.dll", sendSMSIconID, 20)
Gui, ListSMSGUI:Add, Button, ys hWndhButtonClose x560 w150 r2 gListSMSGUIGuiClose, Fermer
SetButtonIcon(hButtonClose, "shell32.dll", reduceIconID, 20)
; TODO ?
; Menu, ListRCMenu, Add, Supprimer, ListSMSGUIButtonViderlalistedesmessages
; Menu, ListRCMenu, Add, Marquer comme lu, ListSMSGUIButtonMarquertouslesmessagescommelus
LV_SetImageList(ImageListID)  ; Assign the above ImageList to the current ListView.



 ; ####   #   #  #   #
 ; #   #  #   #  #   #
 ; #   #  #   #  ##  #
 ; ####   #   #  # # #
 ; # #    #   #  #  ##
 ; #  #   #   #  #   #
 ; #   #   ###   #   #

Loop {
	refreshStatus()
	Sleep %loopDelay%
}


 ; #####   ###   #   #   ###   #####   ###    ###   #   #   ###
 ; #      #   #  #   #  #   #    #      #    #   #  #   #  #   #
 ; #      #   #  ##  #  #        #      #    #   #  ##  #  #
 ; ####   #   #  # # #  #        #      #    #   #  # # #   ###
 ; #      #   #  #  ##  #        #      #    #   #  #  ##      #
 ; #      #   #  #   #  #   #    #      #    #   #  #   #  #   #
 ; #       ###   #   #   ###     #     ###    ###   #   #   ###

openSettings(){
	Run %A_WorkingDir%\config.ini
}

ExitAppli(){
	ExitApp
}

getSMSCount(option){
	return % runShellCmd("get-count " option)
}

getSmsList(option){
	listSMS := runShellCmd("get-sms " option)
	return % listSMS
}

getWifiStatus(){
	return % runShellCmd("get-wifi ")
}


Link() {
	Global ipRouter
  Run http://%ipRouter%/html/smsinbox.html
}

updateTrayIcon(iconName){
	Global lastIcon
	if !iconName
		iconName = % lastIcon
	iconFile = %A_WorkingDir%\medias\%iconName%.ico
	Menu, Tray, Icon, %iconFile%
}

runShellCmd(option){
	Global scriptPath
	cmd := ComSpec . " /c bash.exe /mnt/" . scriptPath . "/scripts/manage_sms.sh " . option
	objOut := % StdOutStream(cmd)
; Gestion des erreurs
	if(InStr(objOut,"ERROR")){
		objOut := RegExReplace(objOut, ".\[91mERROR : ", "> ")
		objOut := RegExReplace(objOut, ".\[0m")
		errorText = Une erreur est survenue : `n`n%objOut%
	; Cas spécial où il y a une erreur de mot de passe, quitte l'application immédiatement
		if(InStr(objOut,"PASSWORD")){
			errorText = Le mot de passe configuré est incorrect !`n`nVeuillez vérifier le fichier "config.ini" `n `nNB : Le compte est peut-être aussi verrouillé suite à de trop nombreuses tentatives incorrectes... 
		}
		errorText = %errorText% `n`nL'éxécution du programme est annulée.
		MsgBox, 48, ERREUR ! , %errorText%
		ExitApp
	}
	return objOut
}

convertXMLtoArray(xmldata , rootNode){
	xmldata := RegExReplace(xmldata, "\r")
	xmlObj := ComObjCreate("MSXML2.DOMDocument.6.0")
	xmlObj.async := false
	xmlObj.loadXML(xmldata)
	nodes := xmlObj.selectNodes(rootNode)
	return nodes
}

guiIsActive(){
	Global MyGuiHwnd
	return WinActive("ahk_id " MyGuiHwnd)
}


refreshWifiStatus(){
	Global wifiStatus
	wifiStatus = % getWifiStatus()

	; Adaptation des labels du statut WIFI
	wifiLabelCmd = Activer le WIFI
	if(wifiStatus = 1){
		wifiLabelCmd = Désactiver le WIFI
	}
	GuiControl,ListSMSGUI:,WifiStatusButton, %wifiLabelCmd%
	Menu, Tray, Rename, 3& , %wifiLabelCmd%
}

refreshStatus(){
	Global lastIcon
	quiet := !guiIsActive()

	updateTrayIcon("load")

	; Vérification BOX joignable
	Global ipRouter
	cmd := "powershell.exe -ExecutionPolicy Bypass -Command Test-NetConnection " . ipRouter . " -InformationLevel Quiet "	
	result := % StdOutStream(cmd)
	if(!InStr(result, "True")){	
		noticeText = La box 4G est injoignable, veuillez vérifier la connexion...
		if(!quiet){	
			TrayTip, Erreur, % noticeText
		}
		Menu, Tray, Tip, %noticeText%
		; actualisation de l'icone 
		updateTrayIcon("net")
		lastIcon = "net"
		Return
	}

	if(!quiet){
		SplashTextOn, 300 , 40 , BOX 4G, Actualisation, merci de patienter...
	}
	
	refreshWifiStatus()
	clearGUI()

	; Récupération de tous les comptes de la boite
	SMSCountsXML = % getSMSCount("All")

	RegExMatch(SMSCountsXML,"<LocalUnread>(\d+)</LocalUnread>",unreadSMSCountNode)
	unreadSMSCount = %unreadSMSCountNode1%
	RegExMatch(SMSCountsXML,"<LocalInbox>(\d+)</LocalInbox>",inboxSMSCountNode)
	inboxSMSCount = %inboxSMSCountNode1%
	RegExMatch(SMSCountsXML,"<LocalOutbox>(\d+)</LocalOutbox>",outboxSMSCountNode)
	outboxSMSCount = %outboxSMSCountNode1%

	if(inboxSMSCount || outboxSMSCount){
		if(inboxSMSCount > 0){
			; Récupération des messages reçus
			createSmsList(1)
		}
		if(outboxSMSCount > 0){
			; Récupération des messages envoyés
			createSmsList(2)
		}
		LV_ModifyCol()  ; Auto-size
		LV_ModifyCol(3, "SortDesc") ; Sort by Date
	}else{
		 if(!quiet){
		 	Sleep 1000 ; juste pour laisser le temps au message de s'afficher
		 }
	}
	if(!quiet){
		SplashTextOff
	}



	; si il y a des messages non lus
	If (unreadSMSCount > 0)
	{
		; Modification de message - pluriel - en fonction du nombre
		if(unreadSMSCount = 1){
			noticeTitle = 1 nouveau message
		}else{
			noticeTitle = %unreadSMSCount% nouveaux messages
		}
		lastIcon = more
	}else {
		; Il n'y a aucun message non lu 
		lastIcon = noSMS
		noticeTitle = Aucun nouveau message
	}
	; actualisation de l'icone 
	updateTrayIcon(lastIcon)
	; actualisation de l'infobulle de l'icone
	Menu, Tray, Tip, %noticeTitle% `n%inboxSMSCount% reçu(s) `n%outboxSMSCount% envoyé(s)
}

; Permet de valider une IP
ValidIP(IPAddress){
	fp := RegExMatch(IPAddress, "^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$", octet)
	If (fp = 0)
		Return 0
	Loop 4
	{
		If (octet%A_Index% > 255)
			Return 0
	}

	return 1
}

JEE_StrUtf8BytesToText(ByRef vUtf8Bytes){
  if A_IsUnicode
  {
    VarSetCapacity(vTemp, StrPut(vUtf8Bytes, "CP0"))
    StrPut(vUtf8Bytes, &vTemp, "CP0")
    return StrGet(&vTemp, "UTF-8")
  }
  else
    return StrGet(&vUtf8Bytes, "UTF-8")
}

JEE_StrTextToUtf8Bytes(ByRef vText){
  VarSetCapacity(vTemp, StrPut(vText, "UTF-8"))
  StrPut(vText, &vTemp, "UTF-8")
  return StrGet(&vTemp, "CP0")
}

RemoveLetterAccents(ByRef text)	{
	static Array := { "a" : "áàâǎăãảạäåāąấầẫẩậắằẵẳặǻ", "c" : "ćĉčċç", "d" : "ďđð", "e" : "éèêěĕẽẻėëēęếềễểẹệ", "g" : "ğĝġģ", "h" : "ĥħ", "i" : "íìĭîǐïĩįīỉịĵ", "k" : "ķ", "l" : "ĺľļłŀ", "n" : "ńňñņ", "o" : "óòŏôốồỗổǒöőõøǿōỏơớờỡởợọộ", "s" : "ṕṗŕřŗśŝšş", "t" : "ťţŧ", "u" : "úùŭûǔůüǘǜǚǖűũųūủưứừữửựụ", "w" : "ẃẁŵẅýỳŷÿỹỷỵ", "z" : "źžż" }
	for k, v in Array
	{
	 StringUpper, VU, v
	 StringUpper, KU, k
	 text:=RegExReplace(text,"[" v "]",k)
	 text:=RegExReplace(text,"[" VU "]",KU)
	}
	Return text
}

; Fonction spéciale pour les GUI, permet d'afficher une icone dans un bouton
SetButtonIcon(hButton, File, Index, Size := 16) {
    hIcon := LoadPicture(File, "h" . Size . " Icon" . Index, _)
    SendMessage 0xF7, 1, %hIcon%,, ahk_id %hButton%
}

; Fonction qui permets de cliquer sur la notif Windows pour ouvrir la GUI
clicOnNotif(wParam, lParam, msg, hwnd){
	if (hwnd != A_ScriptHwnd)
		return
	if (lParam = 1029)
		openGui()
}

; #      #            #        ##   #  #   ##  			  ##   #  #  ###
; #                   #       #  #  ####  #  # 			 #  #  #  #   #
; #     ##     ###   ###       #    ####   #   			 #     #  #   #
; #      #    ##      #         #   #  #    #  			 # ##  #  #   #
; #      #      ##    #       #  #  #  #  #  # 			 #  #  #  #   #
; ####  ###   ###      ##      ##   #  #   ##  			  ###   ##   ###

openGui(){
	Gui, ListSMSGUI:Show
}

clearGUI(){
	Global helpText
	Gui, ListSMSGUI:Default
	LV_Delete() ; clear the table
	GuiControl,ListSMSGUI:,FullNumero,
	GuiControl,ListSMSGUI:,FullDate,
	GuiControl,ListSMSGUI:,FullMessage, %helpText%
}

createSmsList(boxType){
		Global MyGuiHwnd
		SMSList = % getSmsList(boxType)
		messagesNodes = % convertXMLtoArray(SMSList, "//response/Messages/Message")
		messages := messagesNodes.item(0)
		while messages {
			iconID = %boxType%
			phoneNumber := % messages.getElementsByTagName( "Phone" ).item[0].text
			StringReplace, phoneNumber, phoneNumber, +33, 0 , All
			IniRead, phoneNumber, %A_WorkingDir%\config.ini, contacts, % phoneNumber, % phoneNumber
			phoneNumber := % JEE_StrUtf8BytesToText(phoneNumber)
			dateMessage := % messages.getElementsByTagName( "Date" ).item[0].text
			dateMessage := "Le " . SubStr(dateMessage, 1, 10) . "  à  " . SubStr(dateMessage, 12, 19)
			contentMessage := % JEE_StrUtf8BytesToText(messages.getElementsByTagName( "Content" ).item[0].text)
			; Check si le message est "unread", icone spéciale + traytip
			if(messages.getElementsByTagName( "Smstat" ).item[0].text = 0){
					iconID = 3
					; Si le message est trop long (max 120 traytip Windows) alors on coupe et ...
					if (StrLen(contentMessage) > 120){
						contentMessageTT := SubStr(contentMessage, 1, 120) "..."
					}else{
						contentMessageTT = % contentMessage
					}
					
					if ! WinExist("ahk_id " MyGuiHwnd){	
						; affichage d'une notification pour chaque message si interface non affichée
						TrayTip, SMS Box4G : %phoneNumber%, %contentMessageTT%	
					}
			}
			StringReplace, contentMessage, contentMessage, `n, %A_Space% ↳ %A_Space%, All
			LV_Add("Icon" . iconID " Select " ,, phoneNumber , dateMessage , contentMessage)				
		  messages := messagesNodes.nextNode
		}
}

OpenListSMSGUI:
	openGui()
return

; Affichage détaillé d'une ligne si clic dessus
ListSMSTrigger: 
	; préviens les autres clics et force sur le double pour ne pas gêner le clic droit
	If (A_GuiEvent != "DoubleClick"){
	 Return
	}

	; récupère les données de la ligne cliquée
	LV_GetText(longNumero, A_EventInfo, 2) 
	LV_GetText(longDate, A_EventInfo, 3) 
	LV_GetText(longText, A_EventInfo, 4) 

	; met à jour les champs d'affichage complet
	GuiControl,ListSMSGUI:,FullNumero, %longNumero%
	GuiControl,ListSMSGUI:,FullDate, %longDate%
	StringReplace, longText, longText, %A_Space% ↳ %A_Space%, `n, All
	GuiControl,ListSMSGUI:,FullMessage, %longText%

return

; TODO Menu contextuel pour marquer comme lu, supprimer ou répondre
; ListSMSGUIGuiContextMenu:
; 	IF (A_EventInfo) {
; 		rightClickedRow := A_EventInfo 
; 		Menu, ListRCMenu, Show 
; 	}
; return


; TODO with /api/monitoring/status
; <ConnectionStatus>901</ConnectionStatus> = OK
; <SignalIcon>2</SignalIcon>
; <maxsignal>5</maxsignal>

; ContextProperties:  ; The user selected "Properties" in the context menu.
; ; For simplicitly, operate upon only the focused row rather than all selected rows:
; FocusedRowNumber := LV_GetNext(0, "F")  ; Find the focused row.
; if not FocusedRowNumber  ; No row is focused.
;     return

ListSMSGUIButton:
	openSettings()
return

ListSMSGUIButtonActualiser:
	refreshStatus()
return

ListSMSGUIButtonMarquertouslesmessagescommelus:
	SplashTextOn, 200 , 50 , BOX 4G : SMS, Marquage en cours...
	runShellCmd("read-all")
	SplashTextOn, 200 , 50 , BOX 4G : SMS, Marquage terminé !
	Sleep 1000
	SplashTextOff
	refreshStatus()
return

ListSMSGUIButtonSupprimertouslesmessages:
	MsgBox, 49, ATTENTION !, Tous les messages seront supprimés définitivement, c'est sûr ?
	IfMsgBox, OK
	{
		Gui, Hide
		; SplashTextOn, 200 , 50 , BOX 4G : SMS, Suppression en cours...
	  runShellCmd("delete-all 1")
	  runShellCmd("delete-all 2")
		; SplashTextOn, 200 , 50 , BOX 4G : SMS, Suppression terminée !
		; Sleep 1000
		; SplashTextOff
		refreshStatus()
	}
return 


ListSMSGUIGuiEscape:
ListSMSGUIGuiClose:
	Gui, Hide
return 





;  ###                     #   ###   #   #   ###    ###   #   #   ###
; #   #                    #  #   #  #   #  #   #  #   #  #   #    #
; #       ###   # ##    ## #  #      ## ##  #      #      #   #    #
;  ###   #   #  ##  #  #  ##   ###   # # #   ###   #      #   #    #
;     #  #####  #   #  #   #      #  #   #      #  #  ##  #   #    #
; #   #  #      #   #  #  ##  #   #  #   #  #   #  #   #  #   #    #
;  ###    ###   #   #   ## #   ###   #   #   ###    ###    ###    ###

; SOUS-PROGRAME - GUI d'envoi de SMS
; *****************************
SendSMSGUI:
	Gui, SendSMSGUI: New
	Gui, SendSMSGUI:Add, Text,, Message:
	Gui, SendSMSGUI:Add, Edit, vSMSText w240 r5 ys
	Gui, SendSMSGUI:Add, Text, section xs w45, Numéro: 
	Gui, SendSMSGUI:Add, Edit, vNumero ys w80 Limit10 Number

; Si numéro par défaut perso configuré, ajout à l'affichage
	if (defaultSMS){
		Gui, SendSMSGUI:Add, Text, ys, Par défaut : %defaultSMS% 
	}

	Gui, SendSMSGUI:Add, Button, section xs hWndhButton10 w150 r2 gSendSMSGUIGuiClose, Annuler
	SetButtonIcon(hButton10, "shell32.dll", cancelIconID, 20)
	Gui, SendSMSGUI:Add, Button, ys hWndhButton11 w150 r2, Envoi 
	SetButtonIcon(hButton11, "shell32.dll", validIconID, 20)
	Gui, SendSMSGUI:Show,, Envoi de SMS sur Box4G
	return

SendSMSGUIButtonEnvoi:
	Gui, SendSMSGUI:Submit, NoHide
	if(!SMSText){
		MsgBox, 48,Erreur, Aucun message saisi !!
		return
	}

; Si numéro par défaut perso configuré, application
	if(!Numero && defaultSMS){
		Numero = %defaultSMS%
	}

	if(!Numero){
		MsgBox, 48,Erreur, Aucun numéro saisi !!
		return
	}

	MsgBox, 33, Confirmation, Le message suivant va être envoyé au %Numero% : `n`n "%SMSText%" `n `n Confirmer l'envoi ?
	IfMsgBox, OK
	{
	; suppression des caractères à pb
		StringReplace, SMSText, SMSText, ', '' , All
		StringReplace, SMSText, SMSText, >, _ , All
		StringReplace, SMSText, SMSText, <, _ , All
		StringReplace, SMSText, SMSText, `n, _NL_ , All ; transposition des sauts de ligne car mal géré par Run
		Gui, SendSMSGUI:Hide
		SplashTextOn, 200 , 50 , BOX 4G : SMS, Envoi en cours...
		sendReturn := runShellCmd("send-sms '" . SMSText . "' " . Numero)
		if(InStr(sendReturn, "unexpected EOF")){
			SplashTextOff
			MsgBox, 48, ERREUR, Le message n'a pas pu être envoyé. `n Veuillez vérifier votre saisie...
			Sleep 100
			Gui, SendSMSGUI:Show
		}else{
			SplashTextOn, 200 , 50 , BOX 4G : SMS, Le message a bien été envoyé !
			Sleep 1000
			SplashTextOff
			Gui, SendSMSGUI:Destroy
			refreshStatus()
		}
	}
	return

SendSMSGUIGuiEscape:
SendSMSGUIGuiClose:
	Gui, SendSMSGUI:Hide
	Return


; #   #  ###    ####   ###            ##    #   #  ###    #####   ##    #  #
; #   #   #     #       #            #  #   #   #   #       #    #  #   #  #
; # # #   #     ###     #             #     # # #   #       #    #      ####
; # # #   #     #       #              #    # # #   #       #    #      #  #
; ## ##   #     #       #            #  #   ## ##   #       #    #  #   #  #
; #   #  ###    #      ###            ##    #   #  ###      #     ##    #  #


SwitchWifi:
	updateTrayIcon("load")
	Global wifiStatus
	if guiIsActive(){
		GuiControl, Disable ,WifiStatusButton
	} 

	if(wifiStatus = 1){
		SplashTextOn, 200 , 50 , BOX 4G : WIFI, Désactivation du WIFI...
		runShellCmd("deactivate-wifi")
	}	else{
		SplashTextOn, 200 , 50 , BOX 4G : WIFI, Activation du WIFI...
		runShellCmd("activate-wifi")
	}
	Sleep 3000
	SplashTextOff
	refreshWifiStatus()
	updateTrayIcon(false) ;Restore previous icon, set by refreshStatus()
	if guiIsActive(){
		Sleep 5000
		GuiControl, Enable ,WifiStatusButton
	} 
	return


	;  ##   ###   ###    ##   #  #  ###    ##   #  #   ##   ###
	; #  #   #    #  #  #  #  #  #   #    #  #  #  #  #  #  #  #
	;  #     #    #  #  #  #  #  #   #       #  #  #  #  #  #  #
	;   #    #    #  #  #  #  #  #   #      #   #  #  ####  ###
	; #  #   #    #  #  #  #  #  #   #     #     ##   #  #  # #
	;  ##    #    ###    ##    ##    #    ####   ##   #  #  #  #
	


	StdOutStream( sCmd, Callback := "", WorkingDir:=0, ByRef ProcessID:=0) { ; Modified  :  maz-1 https://gist.github.com/maz-1/768bf7938e533907d54bff276db80904
  Static StrGet := "StrGet"           ; Modified  :  SKAN 31-Aug-2013 http://goo.gl/j8XJXY
                                      ; Thanks to :  HotKeyIt         http://goo.gl/IsH1zs
                                      ; Original  :  Sean 20-Feb-2007 http://goo.gl/mxCdn
  tcWrk := WorkingDir=0 ? "Int" : "Str"
  hPipeRead := 
  hPipeWrite := 
  sOutput :=
  ExitCode :=
  DllCall( "CreatePipe", UIntP,hPipeRead, UIntP,hPipeWrite, UInt,0, UInt,0 )
  DllCall( "SetHandleInformation", UInt,hPipeWrite, UInt,1, UInt,1 )
  If A_PtrSize = 8
  {
    VarSetCapacity( STARTUPINFO, 104, 0  )      ; STARTUPINFO          ;  http://goo.gl/fZf24
    NumPut( 68,         STARTUPINFO,  0 )      ; cbSize
    NumPut( 0x100,      STARTUPINFO, 60 )      ; dwFlags    =>  STARTF_USESTDHANDLES = 0x100
    NumPut( hPipeWrite, STARTUPINFO, 88 )      ; hStdOutput
    NumPut( hPipeWrite, STARTUPINFO, 96 )      ; hStdError
    VarSetCapacity( PROCESS_INFORMATION, 24 )  ; PROCESS_INFORMATION  ;  http://goo.gl/b9BaI
  }
  Else
  {
    VarSetCapacity( STARTUPINFO, 68, 0  )
    NumPut( 68,         STARTUPINFO,  0 )
    NumPut( 0x100,      STARTUPINFO, 44 )
    NumPut( hPipeWrite, STARTUPINFO, 60 )
    NumPut( hPipeWrite, STARTUPINFO, 64 )
    VarSetCapacity( PROCESS_INFORMATION, 16 )
  }
  
  If ! DllCall( "CreateProcess", UInt,0, UInt,&sCmd, UInt,0, UInt,0 ;  http://goo.gl/USC5a
              , UInt,1, UInt,0x08000000, UInt,0, tcWrk, WorkingDir
              , UInt,&STARTUPINFO, UInt,&PROCESS_INFORMATION ) 
   {
    DllCall( "CloseHandle", UInt,hPipeWrite ) 
    DllCall( "CloseHandle", UInt,hPipeRead )
    DllCall( "SetLastError", Int,-1 )     
    Return "" 
   }
   
  hProcess := NumGet( PROCESS_INFORMATION, 0 )                 
  hThread  := NumGet( PROCESS_INFORMATION, A_PtrSize )  
  ProcessID:= NumGet( PROCESS_INFORMATION, A_PtrSize*2 )  

  DllCall( "CloseHandle", UInt,hPipeWrite )

  AIC := ( SubStr( A_AhkVersion, 1, 3 ) = "1.0" ) ;  A_IsClassic 
  VarSetCapacity( Buffer, 4096, 0 ), nSz := 0 
  
  While DllCall( "ReadFile", UInt,hPipeRead, UInt,&Buffer, UInt,4094, UIntP,nSz, Int,0 ) {

   tOutput := ( AIC && NumPut( 0, Buffer, nSz, "Char" ) && VarSetCapacity( Buffer,-1 ) ) 
              ? Buffer : %StrGet%( &Buffer, nSz, "CP0" ) ; formerly CP850, but I guess CP0 is suitable for different locales

   Isfunc( Callback ) ? %Callback%( tOutput, A_Index ) : sOutput .= tOutput

  }                   
 
  DllCall( "GetExitCodeProcess", UInt,hProcess, UIntP,ExitCode )
  DllCall( "CloseHandle",  UInt,hProcess  )
  DllCall( "CloseHandle",  UInt,hThread   )
  DllCall( "CloseHandle",  UInt,hPipeRead )
  DllCall( "SetLastError", UInt,ExitCode  )
  VarSetCapacity(STARTUPINFO, 0)
  VarSetCapacity(PROCESS_INFORMATION, 0)

Return Isfunc( Callback ) ? %Callback%( "", 0 ) : sOutput      
}
