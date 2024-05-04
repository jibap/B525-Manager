#!/bin/bash
# Written by oga83, custom by Jibap


#  /$$$$$$$$ /$$   /$$ /$$   /$$  /$$$$$$  /$$$$$$$$ /$$$$$$  /$$$$$$  /$$   /$$  /$$$$$$
# | $$_____/| $$  | $$| $$$ | $$ /$$__  $$|__  $$__/|_  $$_/ /$$__  $$| $$$ | $$ /$$__  $$
# | $$      | $$  | $$| $$$$| $$| $$  \__/   | $$     | $$  | $$  \ $$| $$$$| $$| $$  \__/
# | $$$$$   | $$  | $$| $$ $$ $$| $$         | $$     | $$  | $$  | $$| $$ $$ $$|  $$$$$$
# | $$__/   | $$  | $$| $$  $$$$| $$         | $$     | $$  | $$  | $$| $$  $$$$ \____  $$
# | $$      | $$  | $$| $$\  $$$| $$    $$   | $$     | $$  | $$  | $$| $$\  $$$ /$$  \ $$
# | $$      |  $$$$$$/| $$ \  $$|  $$$$$$/   | $$    /$$$$$$|  $$$$$$/| $$ \  $$|  $$$$$$/
# |__/       \______/ |__/  \__/ \______/    |__/   |______/ \______/ |__/  \__/ \______/




is_validIP() {
    local ip=$1
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        for i in 1 2 3 4; do
            if [ $(echo "$ip" | cut -d. -f$i) -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

ProcessRouterResponseHeader()
{
	# Get token from header
	NEWTOKEN=`cat $TMP_HEADER_FILE | grep "__RequestVerificationTokenone: " | awk -F' ' '{print $2}'`
	if [ ! -z "$NEWTOKEN" ]; then TOKEN=$NEWTOKEN; fi
	NEWTOKEN=`cat $TMP_HEADER_FILE | grep "__RequestVerificationToken: " | awk -F' ' '{print $2}'`
	if [ ! -z "$NEWTOKEN" ]; then TOKEN=$NEWTOKEN; fi
	NEWSESSIONID=`cat $TMP_HEADER_FILE | grep "Set-Cookie: SessionID=" | awk -F' ' '{print $2}' | cut -b 1-138`
	if [ ! -z "$NEWSESSIONID" ]; then SESSIONID=$NEWSESSIONID; fi
}

GetRouterData() # Param1: Relative URL
{
	RESPONSE=`curl $CURL_OPT --request GET http://$ROUTER_IP$1 \
       		--dump-header $TMP_HEADER_FILE \
        	-H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $TOKEN" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
       		`
	ProcessRouterResponseHeader
}

GetSessionToken() # No parameters
{
	# Get SessionID and RequestVerificationToken
	GetRouterData '/api/webserver/SesTokInfo'
        SESSIONID="SessionID="`echo "$RESPONSE"| grep -oPm1 "(?<=<SesInfo>)[^<]+"`
        TOKEN=`echo "$RESPONSE"| grep -oPm1 "(?<=<TokInfo>)[^<]+"`
}

PostRouterData() # Param1: RelativeUrl, Param2: Data, Param3:bAskNewToken
{
	# Get new token if necessary
	if [ ! -z $3 ]; then
		GetSessionToken
	fi

	# echo "POST on http://$ROUTER_IP$1 :" $2
	RESPONSE=`curl $CURL_OPT --request POST http://$ROUTER_IP$1 \
	       --dump-header $TMP_HEADER_FILE \
	       -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $TOKEN" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
	       --data "$2"`
	ProcessRouterResponseHeader
}

connect(){
	# Get initial SessionID and RequestVerificationToken
	GetSessionToken

	# Login
	CREDENTIALS=`printf $ROUTER_PASSWORD | sha256sum | head -c64 | base64 -w0`
	CREDENTIALS=`printf "%s%s%s" $ROUTER_USERNAME $CREDENTIALS $TOKEN | sha256sum | head -c64 | base64 -w0`
	DATA=`printf "<request><Username>%s</Username><Password>%s</Password><password_type>4</password_type></request>" $ROUTER_USERNAME $CREDENTIALS`
	PostRouterData "/api/user/login" "$DATA"
	# Check if password is OK
	if [[ $RESPONSE == *"108007"* ]]; then
	  printf "\e[91mERROR : BAD PASSWORD\e[0m\n"
	fi
}

disconnect(){
	# Logout
	PostRouterData "/api/user/logout" "<request><Logout>1</Logout></request>"
}

getCount(){ # param 1 = boxtype (Unread / Inbox / Outbox / All)
	boxType="Local$1"
	content=$(wget http://$ROUTER_IP/api/sms/sms-count -q -O -)
	if [ "$1" != "All" ] ; then	RESPONSE=`echo "$content" | grep -oP "(?<=<$boxType>)[[:digit:]]+"`; else RESPONSE="$content"; fi
}

getSMS(){ # param 1 = boxtype (1: reçus, 2: envoyés)
	# Lecture des messages reçus
	PostRouterData "/api/sms/sms-list" "<request><PageIndex>1</PageIndex><ReadCount>20</ReadCount><BoxType>$1</BoxType><SortType>0</SortType><Ascending>0</Ascending><UnreadPreferred>1</UnreadPreferred></request>" 1
	# Récupération des index de tous les messages dans un tableau
	INDEXES=(`echo "$RESPONSE" | grep -oP "(?<=<Index>)[[:digit:]]+"`)
	# echo "Nombre de messages : ${#INDEXES[@]}"
}

tagAllAsRead(){
	getSMS 1
	for index in "${INDEXES[@]}"
	do
		PostRouterData "/api/sms/set-read" "<request><Index>$index</Index></request>" 1
	done
}

deleteAll(){ # param 1 = boxtype (1: reçus, 2: envoyés)
	# suppression des messages
	getSMS $1
	for index in "${INDEXES[@]}"
	do
		PostRouterData "/api/sms/delete-sms" "<request><Index>$index</Index></request>" 1
	done
}

sendSMS(){
	message="${2//_NL_/$'\n'}"
	DATA="<?xml version='1.0' encoding='UTF-8'?><request><Index>-1</Index><Phones><Phone>$1</Phone></Phones><Sca></Sca><Content>$message</Content><Length>${#2}</Length><Reserved>1</Reserved><Date>`date +'%F %T'`</Date></request>"
	PostRouterData "/api/sms/send-sms" "$DATA" 1
	printf "$RESPONSE"
}

getWifiStatus(){
	GetRouterData "/api/wlan/status-switch-settings"
	RESPONSE=`echo "$RESPONSE" | grep -oP --max-count=1 "(?<=<wifienable>)[[:digit:]]+" | head -1`;
}

changeWifiStatus(){
	DATA="<?xml version="1.0" encoding="UTF-8"?><request><radios><radio><wifienable>$1</wifienable><index>0</index><ID>InternetGatewayDevice.X_Config.Wifi.Radio.1.</ID></radio><radio><wifienable>$1</wifienable><index>1</index><ID>InternetGatewayDevice.X_Config.Wifi.Radio.2.</ID></radio></radios><WifiRestart>1</WifiRestart></request>"
	PostRouterData "/api/wlan/status-switch-settings" "$DATA" 1
}

activateWifi(){
	changeWifiStatus "1"
}
deactivateWifi(){
	changeWifiStatus "0"
}

   # $$\      $$\  $$$$$$\  $$$$$$\ $$\   $$\
   # $$$\    $$$ |$$  __$$\ \_$$  _|$$$\  $$ |
   # $$$$\  $$$$ |$$ /  $$ |  $$ |  $$$$\ $$ |
   # $$\$$\$$ $$ |$$$$$$$$ |  $$ |  $$ $$\$$ |
   # $$ \$$$  $$ |$$  __$$ |  $$ |  $$ \$$$$ |
   # $$ |\$  /$$ |$$ |  $$ |  $$ |  $$ |\$$$ |
   # $$ | \_/ $$ |$$ |  $$ |$$$$$$\ $$ | \$$ |
   # \__|     \__|\__|  \__|\______|\__|  \__|




# construct config file path
CONFIG_FILE=$(dirname "$dir")/config.ini

# Check if config.ini file exists
if ! [ -f "$CONFIG_FILE" ]; then printf "\e[91mERROR : Fichier [config.ini] introuvable\e[0m \n" $0 ; exit 0 ; fi

ROUTER_IP=$(awk -F '=' '/ROUTER_IP/ {print $2}' $CONFIG_FILE | tr -d '\r')
ROUTER_USERNAME=$(awk -F "=" '/ROUTER_USERNAME/ {print $2}' $CONFIG_FILE | tr -d '\r')
ROUTER_PASSWORD=$(awk -F "=" '/ROUTER_PASSWORD/ {print $2}' $CONFIG_FILE | tr -d '\r')

TMP_HEADER_FILE=/tmp/headers.tmp

CURL_OPT=--silent


usage="Usage: manage_sms.sh <command> \n\n Commands:\tget-count [Unread,Inbox,Outbox,All]\n \t\tget-sms [1=reçus (par defaut), 2=envoyés]\n \t\tread-all \n \t\tdelete-all [1=reçus (par defaut), 2=envoyés]\n \t\tget-wifi \n \t\tactivate-wifi \n \t\tdeactivate-wifi \n \t\tsend-sms <Message> <Numero> \n"


if [ ! $ROUTER_USERNAME ]; then ROUTER_USERNAME=admin ; fi
if [ ! $ROUTER_PASSWORD ]; then printf "\e[91mERROR : Aucun PASSWORD configuré\e[0m \n" $0 ; exit 0 ; fi

# Si IP invalide, default is 192.168.8.1
is_validIP $ROUTER_IP
if [[ $? -ne 0 ]]; then
	ROUTER_IP=192.168.8.1
fi

# Check command line parameters
# at least 1 parameter required
if [ "$#" -lt 1 ]; then
    printf "\e[91mERROR : At least 1 parameter required\e[0m \n $usage" $0
    exit 0
fi

# si commande 'get-count', paramètres possible pour choisir entre <Unread / Inbox / Outbox>
if [ "$1" = get-count ]; then 
	if [ ! "$2" ] || [[ "$2" != Unread && "$2" != Inbox && "$2" != Outbox && "$2" != All ]]; then printf "\e[91mERROR : Second parameter required, available options: <Unread / Inbox / Outbox / All>\e[0m \n " $0;	exit 0;	else BOX_TYPE=$2;fi
fi

# si commande 'get-sms', paramètres possible pour choisir entre sms reçus(1) ou sms envoyés(2)
if [ "$1" = get-sms ]; then 
	if [ ! "$2"  ] || [[ "$2" != 1 && "$2" != 2 ]]; then BOX_TYPE=1 ;else BOX_TYPE=$2;fi
fi

# si commande 'delete-all', paramètres possible pour choisir entre sms reçus(1) ou sms envoyés(2)
if [ "$1" = delete-all ]; then 
	if [ ! "$2"  ] || [[ "$2" != 1 && "$2" != 2 ]]; then BOX_TYPE=1 ;else BOX_TYPE=$2;fi
fi

# si commande 'send-sms', paramètres requis
if [ "$1" = send-sms ]; then 
	if [ ! "$2" ]; then printf "\e[91mERROR : Second parameter required\e[0m <Message>\n" $0;	exit 0;	else SMS_TEXT=$2;fi
	if [ ! "$3" ]; then printf "\e[91mERROR : Third parameter required\e[0m <Numero>\n" $0;exit 0; else SMS_NUMBER=$3;fi
fi

# Route command
case $1 in
 	get-count) getCount $BOX_TYPE; printf "$RESPONSE";;
 	get-sms) connect; getSMS $BOX_TYPE; echo "$RESPONSE";;
 	read-all) connect; tagAllAsRead;;
 	delete-all) connect; deleteAll $BOX_TYPE;;
	send-sms) connect; sendSMS "$SMS_NUMBER" "$SMS_TEXT";;
	get-wifi) connect; getWifiStatus; printf "$RESPONSE";;
	activate-wifi) connect; activateWifi;;
	deactivate-wifi) connect; deactivateWifi;;
	*) printf "\e[91mERROR : Command '$1' unavailable\e[0m \n $usage" $0
esac

disconnect
