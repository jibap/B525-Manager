#Persistent
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; IMPORT / EXPORT des fichiers annexes pour version compilée
FileInstall, more.ico, %A_ScriptDir%\more.ico
FileInstall, noSMS.ico, %A_ScriptDir%\noSMS.ico
FileInstall, load.ico, %A_ScriptDir%\load.ico
FileInstall, manage_sms.sh, %A_ScriptDir%\manage_sms.sh
FileInstall, config.ini, %A_ScriptDir%\config.ini



; Transposition du chemin du script pour le BASH
StringReplace , scriptPath, A_ScriptDir , : , 
StringReplace , scriptPath, scriptPath , \ , / , All
; lowercase first letter (partition letter)
scriptPath = % RegExReplace(scriptPath, "^.", "$l0",,1)

; Pour cacher la fenêtre de powershell
DllCall("AllocConsole")
WinHide % "ahk_id " DllCall("GetConsoleWindow", "ptr")


  ; ###   #   #   ###   #####
  ;  #    #   #    #      #
  ;  #    ##  #    #      #
  ;  #    # # #    #      #
  ;  #    #  ##    #      #
  ;  #    #   #    #      #
  ; ###   #   #   ###     #

noticeText = 

; Initialisation personnalisée, le cas échéant, des variables globales
IniRead, ipRouter, %A_ScriptDir%\config.ini, main, ROUTER_IP
if(!ipRouter || !ValidIP(ipRouter)){
	ipRouter = "192.168.8.1" ; Default IP
}
IniRead, loopDelay, %A_ScriptDir%\config.ini, main, DELAY
if(!loopDelay || !RegExMatch(loopDelay,"^\d+$")){
	loopDelay = 300000 ; Default Loop delay for check
}
IniRead, defaultSMS, %A_ScriptDir%\config.ini, main, DEFAULTSMS
if(!defaultSMS || !RegExMatch(defaultSMS,"^\d+$")){
	defaultSMS = 
}

; Création d'une liste d'icones système 
ImageListID := IL_Create(3)
IL_Add(ImageListID, "shell32.dll", 248) ; In
IL_Add(ImageListID, "shell32.dll", 247) ; Out
IL_Add(ImageListID, "shell32.dll", 209) ; Unread

updateTrayIcon("noSMS")


; CREATION DU TRAYMENU
; *****************************
Menu, tray, NoStandard
Menu, tray, add, Quitter, ExitAppli
Menu, tray, add
Menu, tray, add, Ouvrir la page Web, Link
Menu, tray, add, Envoyer un SMS, SendSMSGUI
Menu, tray, add
Menu, tray, add, Afficher tous les SMS, ListSMSGUI
Menu, tray, add
Menu, tray, add, Actualiser, refreshStatus
Menu, tray, Default, Afficher tous les SMS

; Création de l'interface de liste SMS
Gui, ListSMSGUI: New
Gui, ListSMSGUI:Add, Button, hWndhButton1 x10 y8 w100 r2, %A_Space%Actualiser
SetButtonIcon(hButton1, "shell32.dll", 239, 20)
Gui, ListSMSGUI:Add, Button, hWndhButton2 x280 y8 w220 r2, %A_Space%Marquer tous les messages comme lus
SetButtonIcon(hButton2, "shell32.dll", 301, 20)
Gui, ListSMSGUI:Add, Button, hWndhButton3 x510 y8 w200 r2, %A_Space%Supprimer tous les messages
SetButtonIcon(hButton3, "shell32.dll", 132, 20)
Gui, ListSMSGUI:Add, ListView, section xs R10 w700 vLVSMS gListSMSTrigger Grid AltSubmit,  | Numéro | Date - Heure | Message
Gui, ListSMSGUI:Add, Picture, section Icon161 w16 h16, shell32.dll
Gui, ListSMSGUI:Add, Edit, ReadOnly ys w100 h20 vFullNumero, 
Gui, ListSMSGUI:Add, Picture, ys Icon250 w16 h16, shell32.dll
Gui, ListSMSGUI:Add, Text, ys w200 h20 vFullDate, 
Gui, ListSMSGUI:Add, Picture, section xs Icon157 w16 h16, shell32.dll
Gui, ListSMSGUI:Add, Edit, ReadOnly ys w670 h50 vFullMessage, Double-clic sur une ligne pour afficher le message ici
Gui, ListSMSGUI:Add, Button, section xs hWndhButton5  w150 r2 gLink, %A_Space%Ouvrir la page Web
SetButtonIcon(hButton5, "shell32.dll", 136, 20)
Gui, ListSMSGUI:Add, Button, ys hWndhButton4 x300 w140 r2 gSendSMSGUI, %A_Space%Envoyer un SMS
SetButtonIcon(hButton4, "shell32.dll", 25, 20)
Gui, ListSMSGUI:Add, Button, ys hWndhButtonClose x560 w150 r2 gListSMSGUIGuiClose, Fermer
SetButtonIcon(hButtonClose, "shell32.dll", 248, 20)
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


Link() {
	Global ipRouter
  Run http://%ipRouter%/html/smsinbox.html
}

updateTrayIcon(iconName){
	iconFile = %A_WorkingDir%\%iconName%.ico
	Menu, Tray, Icon, %iconFile%
}

runShellCmd(option){
	Global scriptPath
	updateTrayIcon("load")
	objShell := ComObjCreate("WScript.Shell")
	objExec := % objShell.Exec("bash.exe /mnt/" . scriptPath . "/manage_sms.sh " . option)
	objOut := objExec.StdOut.ReadAll() ;read the output at once
	return 	JEE_StrUtf8BytesToText(objOut)    
}

convertXMLtoArray(xmldata , rootNode){
	xmldata := RegExReplace(xmldata, "\r")
	xmlObj := ComObjCreate("MSXML2.DOMDocument.6.0")
	xmlObj.async := false
	xmlObj.loadXML(xmldata)
	nodes := xmlObj.selectNodes(rootNode)
	return nodes
}

refreshStatus(quiet=1){
	Global noticeText
	Gui, ListSMSGUI:Default ; Focus sur la GUI pour éditer les éléments dedans (Text, Edit, ListView)
	clearGUI()

	if(!quiet){
		SplashTextOn, 300 , 40 , SMS, Actualisation de la liste, merci de patienter...
	}

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
			createSmsList("Inbox")
		}
		if(outboxSMSCount > 0){
			; Récupération des messages envoyés
			createSmsList("Outbox")
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
		
		; Si le message est trop long (max 120 traytip Windows) alors on coupe et ...
		if (StrLen(noticeText) > 120){
			noticeText := SubStr(noticeText, 1, 120) "..."
		}

		; actualisation de l'icone 
		updateTrayIcon("more")
		; affichage d'une notification
		TrayTip, Box4G : %noticeTitle%, % noticeText	
	}else {
		; Il n'y a aucun message non lu 
		updateTrayIcon("noSMS")
		noticeTitle = Aucun nouveau message
		GuiControl,ListSMSGUI:,FullMessage, %noticeTitle%
	}
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

; #      #            #        ##   #  #   ##  			  ##   #  #  ###
; #                   #       #  #  ####  #  # 			 #  #  #  #   #
; #     ##     ###   ###       #    ####   #   			 #     #  #   #
; #      #    ##      #         #   #  #    #  			 # ##  #  #   #
; #      #      ##    #       #  #  #  #  #  # 			 #  #  #  #   #
; ####  ###   ###      ##      ##   #  #   ##  			  ###   ##   ###

clearGUI(){
	Global noticeText
	noticeText = 
	LV_Delete() ; clear the table
	GuiControl,ListSMSGUI:,FullNumero,
	GuiControl,ListSMSGUI:,FullDate,
	GuiControl,ListSMSGUI:,FullMessage, Double-clic sur une ligne pour afficher le message ici
}

createSmsList(listType){
		Global noticeText
		boxType = 1
		if (listType = "Outbox"){
			boxType = 2
		}
		SMSList = % getSmsList(boxType)
		messagesNodes = % convertXMLtoArray(SMSList, "//response/Messages/Message")
		messages := messagesNodes.item(0)
		while messages {
			iconID = %boxType%
			phoneNumber := % messages.getElementsByTagName( "Phone" ).item[0].text
			StringReplace, phoneNumber, phoneNumber, +33, 0 , All
			dateMessage := % messages.getElementsByTagName( "Date" ).item[0].text
			dateMessage := "Le " . SubStr(dateMessage, 1, 10) . "  à  " . SubStr(dateMessage, 12, 19)
			contentMessage := % RemoveLetterAccents(messages.getElementsByTagName( "Content" ).item[0].text)
			; Check si le message est "unread", icone spéciale + traytip autocomplete
			if(messages.getElementsByTagName( "Smstat" ).item[0].text = 0){
					iconID = 3
					noticeText = %noticeText%%contentMessage% `n ------------------------------------ `n
			}
			LV_Add("Icon" . iconID " Select " ,, phoneNumber , dateMessage , contentMessage)				
		  messages := messagesNodes.nextNode
		}
}

ListSMSGUI:
	Gui, ListSMSGUI:Show
return

; Affichage détaillé d'une ligne si clic dessus
ListSMSTrigger: 
	; préviens les autres clics 
	If (A_GuiEvent != "DoubleClick"){
	 Return
	}

	; récupère les données de la ligne cliquée
	LV_GetText(longNumero, A_EventInfo, 2) 
	LV_GetText(longDate, A_EventInfo, 3) 
	LV_GetText(longText, A_EventInfo, 4) 

	; met à jour les champs d'affichage complet
	GuiControl,,FullNumero, %longNumero%
	GuiControl,,FullDate, %longDate%
	GuiControl,,FullMessage, %longText%

return

; TODO
; ListSMSGUIGuiContextMenu:
; 	IF (A_EventInfo) {
; 		rightClickedRow := A_EventInfo 
; 		Menu, ListRCMenu, Show 
; 	}
; return

ListSMSGUIButtonActualiser:
	refreshStatus(0)
return

ListSMSGUIButtonMarquertouslesmessagescommelus:
	SplashTextOn, 200 , 50 , SMS, Marquage en cours...
	runShellCmd("read-all")
	SplashTextOn, 200 , 50 , SMS, Marquage terminé !
	Sleep 1000
	SplashTextOff
	refreshStatus(0)
return

ListSMSGUIButtonSupprimertouslesmessages:
	MsgBox, 49, ATTENTION !, Tous les messages seront supprimés définitivement, c'est sûr ?
	IfMsgBox, OK
	{
		Gui, Hide
		; SplashTextOn, 200 , 50 , SMS, Suppression en cours...
	  runShellCmd("delete-all 1")
	  runShellCmd("delete-all 2")
		; SplashTextOn, 200 , 50 , SMS, Suppression terminée !
		; Sleep 1000
		; SplashTextOff
		refreshStatus(1)
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
	SetButtonIcon(hButton10, "shell32.dll", 296, 20)
	Gui, SendSMSGUI:Add, Button, ys hWndhButton11 w150 r2, Envoi 
	SetButtonIcon(hButton11, "shell32.dll", 301, 20)
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
		Gui, SendSMSGUI:Hide
		SplashTextOn, 200 , 50 , SMS, Envoi en cours...
		runShellCmd("send-sms '" . SMSText . "' " . Numero)
		SplashTextOn, 200 , 50 , SMS, Message envoyé !
		Sleep 1000
		SplashTextOff
		Gui, SendSMSGUI:Destroy
		refreshStatus()
	}
	return

SendSMSGUIGuiEscape:
SendSMSGUIGuiClose:
	Gui, SendSMSGUI:Destroy
	Return
