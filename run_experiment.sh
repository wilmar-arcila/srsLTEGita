#!/bin/bash
sudo hwclock -w
##########################################################
# Desarrollador: Wilmar Arcila Castaño                   #
# 10/04/2020                                             #
# Grupo de Investigación en Telecomunicaciones Aplicadas #
# GITA - UdeA                                            #
##########################################################

# Archivos y directorios
LOGFILE=epc1.log    # Archivo de logs que se escribe a medida que se generan los mensajes y no cuando se detiene el proceso
METRICS_ROOT='/media/wilmar/ACADEMICO/MAESTRIA/Proyecto/Vehicle_2_x/srsLTE/experiments/automated'
METRICS_DIR='cable' # Directorio para almacenar las métricas $METRICS_ROOT/$METRICS_DIR
# Datos de los UE
NUM_UE=1
IMSI_UE1=001010123456789
IMSI_UE2=''

#############################################################
function help
{
	echo "Programa para automatizar y sincronizar las pruebas de desempeño"
	echo "en la conexión entre un UE y un eNB usando el software srsLTE."
	echo -e "\nUso:\n./run_experiment { -u | HH:MM }\n"
	echo -e "HH:MM\tHora de ejecución en formato 24 horas. Implica que se ejecuta del lado del eNB."
	echo -e "-u\tIndica que se está ejecutando del lado del UE"
	echo -e "-h\n--help\tMuestra ésta ayuda"
	echo -e "\n\033[33mNOTA:\tVerifique que la escritura de métricas al archivo externo (/tmp/{ue|enb}_metrics.csv)"
	echo -e "\testé activada y configurada en 1s" 
	echo -e "\n\n\033[31mNOTA IMPORTANTE: Es FUNDAMENTAL que los equipos estén sincronizados con un error"
	echo -e "\t\t de menos de un segundo. Esto se puede lograr estableciendo la"
	echo -e "\t\t hora manualmente o por medio de un protocolo de sincronización"
	echo -e "\t\t de red como NTP."
# Debe estar habilitada la salida en csv
# metrics_period_secs:  Sets the period at which metrics are requested from the eNB. 
# metrics_csv_enable:   Write eNB metrics to CSV file.
# metrics_csv_filename: File path to use for CSV metrics.

}

function on_exit
{
	local PS=$(ps -ax -o comm|grep -w srsepc)
	if [[ -z $PS ]]; then
		if [[ -f /tmp/$LOGFILE ]];then rm /tmp/$LOGFILE;fi
	fi
	kill_process
}

function kill_process
{
	#local DEVPID=$(ps -ax -o pid,comm|grep -w "srsue\|srsenb"|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	local NCPID=$(ps -ax -o pid,comm|grep -w nc|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	local IPERFPID=$(ps -ax -o pid,comm|grep -w iperf|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	while [[ -n $IPERFPID ]]; do
		sudo kill -s SIGINT $IPERFPID
		IPERFPID=$(ps -ax -o pid,comm|grep -w iperf|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	done	
	if [[ -n $NCPID ]]; then sudo kill -s SIGINT $NCPID;fi
	if [[ -n $DEVPID ]]; then sudo kill -s SIGINT $DEVPID;fi
	#if [[ -n $DEVPROC_PID ]]; then sudo kill -s SIGINT $DEVPROC_PID;fi
}

function displayError_and_Exit
{
	local MSG=''
	local MSG1="Ejecute la EPC de la siguiente manera: sudo srsepc --log.filename stdout 2>&1|tee /tmp/$LOGFILE\nNota: El nivel de los logs debe estar configurado en INFO"
	case $(($1)) in
		200) MSG="Debe ingresar la hora de ejecución en formato 'HH:MM'" ;;
		201) MSG="Debe ingresar una hora válida para el planeta tierra" ;;
		300) MSG="La EPC (Evolved Packet Core) no está en ejecución\n\n$MSG1" ;;
		400) MSG="El $MODO no está en ejecución" ;;
		500) MSG="El archivo de logs de la EPC (actualizando en tiempo real) no existe en el directorio /tmp/\n\n$MSG1" ;;
		501) MSG="El archivo de logs de la EPC (actualizando en tiempo real) es un archivo antiguo\n\n$MSG1" ;;
		600) MSG="El eNB no esta conectado con la EPC" ;;
		700) MSG="La interfaz $DEVIF no fue creada en el UE" ;;
		701) MSG="No hay asignación de dirección IP a UE alguno" ;;
		702) MSG="No hay conectividad entre UE y eNB" ;;
		703) MSG="El UE no recibió órdenes del eNB en un lapso de $2 \bs" ;;
		704) MSG="No hay respuesta de Iperf" ;;
		800) MSG="No hay archivo de métricas para el $MODO" ;;
		801) MSG="El archivo de métricas del $MODO es un archivo antiguo" ;;
		802) MSG="El archivo de métricas del $MODO no contiene información" ;;
		#703) MSG= ;;
		*) MSG="Sucedió algo inesperado :("
	esac
	echo -e "\033[31m\nError: $MSG"
	echo -e "\nError $1"
	exit $(($1))
}

function enviarReporte
{
	local STR=$1
	local PS=''
	until (( ${#STR}==8 ));do STR+=" ";done
	echo -en "\n-> $STR (Reporte UE)       | $(echo $IPERF_T|cut -d "," -f 2) -- $IPERF_B [bps]"
	echo -en "\n-> Enviando reporte al eNB     | ..."
	sleep 1
	for i in {1..10}; do echo "$IPERF_T,$IPERF_B"|nc -w 1 $IPSPGW $PUERTONC; done
	echo -en "\b\b\bOK "
	PS=$(ps -ax -o pid,comm|grep -w nc|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	if [[ -n $PS ]]; then sudo kill -s SIGINT $PS; fi
}

function esperarReporte
{
	local STR=$1
	local PS=''
	until (( ${#STR}==8 ));do STR+=" ";done
	local IPERF_=''
	local IPERF_T_=''
	local IPERF_B_=''
	local n=30
	local ni=$n
	local i=1
	local sp="/-\|"
	echo -e "$1,eNB,$IPERF_T,$IPERF_B" >> $METRICS_ROOT/$METRICS_DIR/Iperf_$TIME.csv
	echo -en "\n-> $STR (Reporte eNB)      | $(echo $IPERF_T|cut -d "," -f 2) -- $IPERF_B [bps]\n\033[s"
	coproc NCPROC { nc -l $PUERTONC; }
	# Borro el warning generado por tener varios coprocesos
	#echo -ne "\033[u\033[K"
	sleep 0.5
	echo -ne "\033[u-> Esperando reporte del UE    |  \033[K\033[s"
	until [[ -n $IPERF_ ]]; do sleep 1
		read -t 0.2 -u ${NCPROC[0]} IPERF_
		printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		ni=$((ni-1))
		if (( ni==0 )); then
			echo -e "\033[u\033[33m\bFAIL   Warning: no se recibió reporte del UE en un lapso de $n \bs\033[39m\n"
			NCPID_=$(ps -ax -o pid,comm|grep -w nc|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
			if [[ -n $NCPID_ ]]; then sudo kill -s SIGINT $NCPID_;fi
			break
		fi
	done
	if [[ -n $IPERF_ ]]; then
		IPERF_T_=$(echo $IPERF_|cut -d "," -f 1,2)
		IPERF_B_=$(echo $IPERF_|cut -d "," -f 3)
		echo -en "\033[G\033[39m"
	else
		IPERF_T_=$IPERF_T
		IPERF_B_='0'
	fi
	echo -en "-> $STR (Reporte UE)       | $(echo $IPERF_T_|cut -d "," -f 2) -- $IPERF_B_ [bps]"
	echo -e "$1,UE,$IPERF_T_,$IPERF_B_" >> $METRICS_ROOT/$METRICS_DIR/Iperf_$TIME.csv
	PS=$(ps -ax -o pid,comm|grep -w nc|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	if [[ -n $PS ]]; then sudo kill -s SIGINT $PS; fi
}

function verificarFormato
{
	if (( $# == 0))||(( $# > 1 ))||[[ $1 == '-h' ]]||[[ $1 == '--help' ]];then
		help; exit 1;
	else
		if [[ $1 == '-u' ]];then LOGFILE=ue1.log;MODO="UE";COMANDO='srsue';DEVIF='tun_srsue'
		else SHOWTIME=$1
		fi
	fi
}

function verificarTiempo
{
	if [[ $SHOWTIME != ?([[:digit:]])[[:digit:]]:[[:digit:]][[:digit:]] ]];then
			displayError_and_Exit 200
	else
		if (( 10#$(echo $SHOWTIME|cut -d ":" -f 1) > 23 ))||(( 10#$(echo $SHOWTIME|cut -d ":" -f 2) > 59 ));then
			displayError_and_Exit 201
		fi
	SHOWTIME_LEFT_TIME=$(date -ud @$(($(date -d $SHOWTIME +%s)-$(date +%s))) +"%H:%M:%S")
	fi
}

function verificarEPC
{
	local PS=$(ps -ax -o pid,start,comm|grep srsepc)
	if [[ -z $PS ]]; then displayError_and_Exit 300
	else
		EPCTIME=$(echo $PS|cut -d " " -f 2)
		EPCPID=$(echo $PS|cut -d " " -f 1)
		echo "-> EPC activa                  | EPC_PID:$EPCPID"
	fi
}

function verificarEPC_Logs
{
	if [[ ! -f /tmp/$LOGFILE ]]; then
		displayError_and_Exit 500
	else
		local VAR=$(stat -c %Y /tmp/$LOGFILE)
		if (( $(($VAR-$(date -d $EPCTIME +%s))) < 0 ));then
			displayError_and_Exit 501
		fi
		echo "-> Archivo de logs de EPC OK   | /tmp/$LOGFILE"
	fi
}

function ejecutarSRS
{
	local j=15
	local STR=$MODO
	local PS=''
	local i=1
	local sp="/-\|"
	until (( ${#STR}==3 ));do STR+=" ";done
	#coproc DEVPROC { sudo $COMANDO $COM_ARGS &> /dev/null; }
	sudo $COMANDO $COM_ARGS &> /dev/null &
	echo -ne "-> Lanzando el $STR             |  \033[s"
	until (( j==0 )); do sleep 1
		printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		j=$((j-1))
	done
	echo -e "\033[u\b\033[39mOK"
	PS=$(ps -ax -o pid,start,comm|grep -w $COMANDO|sed -e 's/^[ \t]*//')
	if [[ -z $PS ]]; then displayError_and_Exit 400
	else
		DEVTIME=$(echo $PS|cut -d " " -f 2)
		DEVPID=$(echo $PS|cut -d " " -f 1)
		echo -n "-> $STR activo                  | ";echo -n "$MODO"; echo "_PID:$DEVPID"
	fi
}

function chequearConexion_eNB_EPC
{
	local i=3
	local ENB_NAME=''
	local ENB_ID=''
	local ENB_EPC_OK=''
	until (( i==0 )); do sleep 1
		echo -ne "\b.>";i=$((i-1))
	done
	ENB_NAME=$(grep "S1 Setup Request - eNB Name:" /tmp/$LOGFILE|grep S1AP|cut -d ":" -f 4|cut -d "," -f 1|cut -d " " -f 2|tail -n 1)
	ENB_ID=$(grep "S1 Setup Request - eNB Name:" /tmp/$LOGFILE|grep S1AP|cut -d ":" -f 5|cut -d " " -f 2|tail -n 1)
	ENB_EPC_OK=$(grep "Sending S1 Setup Response" /tmp/$LOGFILE)
	if [[ -z $ENB_NAME ]]||[[ -z $ENB_ID ]]||[[ -z $ENB_EPC_OK ]]; then
		echo ""; displayError_and_Exit 600
	else
		echo -en "\033[u<----------->\n"
		echo "-> eNB conectado a la EPC      | Nombre:$ENB_NAME  Id:$ENB_ID"
	fi
}

function buscarIP_UE
{
	local j=20
	local i=1
	local sp="/-\|"
	if [[ $MODO == 'eNB' ]];then
		while [[ -z $IPDIR ]]&&(( $j>0 )); do sleep 1
			j=$((j-1))
			IPDIR=$(grep "\[SPGW GTPC\] \[I\] IMSI: $IMSI_UE1, UE IP:" /tmp/$LOGFILE|cut -d ":" -f 5|sed -e 's/^[ \t]*//'|tail -n 1)
			printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		done
		
	else
		sleep 1
		local VAR=''
		while [[ -z $VAR ]]&&(( $j>0 )); do sleep 1
			j=$((j-1))
			VAR=$(ip -o l show|cut -d ":" -f 2|cut -d " " -f 2|grep -w $DEVIF)
			printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		done
		if [[ -z $VAR ]]; then echo ""; displayError_and_Exit 700
		else IPDIR=$(ip a show $DEVIF|grep -w inet|cut -d ' ' -f 6|cut -d '/' -f 1)
		fi
	fi
	#Verificar que IPDIR no esté vacia -> Indicaría que no hay conexión entre UE y eNB
	if [[ -z $IPDIR ]]; then
		echo ""; displayError_and_Exit 701
	else
		echo -ne "\033[39m\033[2K\033[G-> Dirección IP asignada al UE | IP:$IPDIR\n\033[s"
	fi
}

function lanzarPINGPROC
{
	if [[ $MODO == 'eNB' ]]; then
		coproc PINGPROC { echo $(ping -c4 -w10 -q $IPDIR|grep "packet loss"|rev|cut -d "," -f 2|rev);sleep 1; }
	else
		coproc PINGPROC { echo $(ping -c4 -w10 -q $IPSPGW|grep "packet loss"|rev|cut -d "," -f 2|rev);sleep 1; }
	fi
	# Borro el warning generado por tener varios coprocesos
	#sleep 0.1
	#echo -ne "\033[u\033[K"
}

function leerPINGPROC
{
	local CON=''
	local CON1=''
	while [[ -z $CON ]];do sleep 0.5
		echo -ne "\b.>"
		read -t 0.2 -u ${PINGPROC[0]} CON
	done
	CON1=$(echo $CON|cut -d " " -f 1)
	sleep 0.5
	if [[ $CON1 == '100%' ]];then echo -e "\bX  ]eNB"; displayError_and_Exit 702
	else echo -en "\033[u<------------>eNB  $CON\n\033[s"
	fi
	if [[ -n $PINGPROC_PID ]];then sudo kill -s SIGINT $PINGPROC_PID;fi
}

function enviarSHOWTIME
{
	local i=1
	local j=1
	local sp="/-\|"
	sleep 1
	# Es necesario "disparar" mas de una vez para garantizar que quien escucha haya capturado los datos debido a el jitter en la ejecución
	for j in {1..10}; do 
		printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		echo "$SHOWTIME"|nc -w 1 $IPDIR $PUERTONC
	done
	echo -e "\033[u\b\033[39mOK"
}

function esperarSHOWTIME
{
	local i=1
	local sp="/-\|"
	local n=30
	local ni=$n
	local PS=''
	coproc NCPROC { nc -l $PUERTONC; } 2>/dev/null
	# Borro el warning generado por tener varios coprocesos
	#echo -ne "\033[u\033[K"
	until [[ -n $SHOWTIME ]]; do sleep 1
		read -t 0.5 -u ${NCPROC[0]} SHOWTIME
		printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		ni=$((ni-1))
		if (( ni==0 )); then echo -e "\bX"; displayError_and_Exit 703 $n; fi
	done

	# Ejecutar 60s después de iniciar el script sin esperar órdenes del eNB (USADO PARA PRUEBAS)
	#SHOWTIME=$(date -d @$(($(date +%s)+60)) +"%H:%M")

	echo -e "\033[u\b\033[39mSHOWTIME=$SHOWTIME\033[s"
	PS=$(ps -ax -o pid,comm|grep -w nc|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	if [[ -n $PS ]]; then sudo kill -s SIGINT $PS; fi
	if [[ -n $NCPROC_PID ]]; then sudo kill -s SIGINT $NCPROC_PID; fi
}

function mostrarTiempoFaltante
{
	local i=1
	local sp="/-\|"
	local CONPINGUP=0
	until (( $SHOWTIME_LEFT_TIME==0 )); do sleep 0.5
		SHOWTIME_LEFT_TIME=$(($(date -d $SHOWTIME +%s)-$(date  +%s)))
		# Reactivo la conexión para que eNB y UE estén listos para la prueba
		if (( $SHOWTIME_LEFT_TIME<25 ))&&(( $SHOWTIME_LEFT_TIME>11 ))&&(( $CONPINGUP==0 ));then
			local IPDIR_=$IPDIR
			CONPINGUP=1
			if [[ $MODO == 'eNB' ]]; then
				IPDIR=$(grep "\[SPGW GTPC\] \[I\] IMSI: $IMSI_UE1, UE IP:" /tmp/$LOGFILE|cut -d ":" -f 5|sed -e 's/^[ \t]*//'|tail -n 1)
				coproc PINGPROC { ping -w5 -q $IPDIR; }
			else
				IPDIR=$(ip a show $DEVIF|grep -w inet|cut -d ' ' -f 6|cut -d '/' -f 1)
				coproc PINGPROC { ping -w5 -q $IPSPGW; }
			fi
			if [[ $IPDIR != $IPDIR_ ]]; then echo -en "\033[u\033[33m\tWarning: El UE cambió de dirección IP:$IPDIR_ $IPDIR\033[39m";fi
		fi
		# Spinner o segundos
		if (( $SHOWTIME_LEFT_TIME<11 ));then echo -ne "\033[u\033[39m\033[2D$(date -d @$SHOWTIME_LEFT_TIME +%S)\033[K"
		else printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
		fi
	done
}

function lanzarIPERFPROC_cliente
{
	coproc IPERFPROC { 
		A=''
		i=0 # Contador de seguridad para cuando el proceso se sale de control
		while [[ -z $A ]]&&(( $i<5 ));do
			A=$(iperf -c $1 -y C -x C -n 2M 2>/dev/null)
			i=$((i+1))
			sleep 1
		done
		echo $A
		sleep 1;
	}
}

function lanzarIPERFPROC_servidor
{
	coproc IPERFPROC { iperf -y C -s 2>/dev/null; }
}

function leerIPERFPROC
{
	local IPERF_=''
	local n=100
	local PS=$(ps -ax -o pid,comm|grep -w iperf|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	until [[ -z $PS ]]||[[ -n $IPERF_ ]]||(( $n==0 )); do
		echo -ne "\b.]\033[s\033[K\033[u"
		read -t 0.2 -u ${IPERFPROC[0]} IPERF_
		n=$((n-1))
		sleep 1
	done
	if [[ -z $IPERF_ ]]; then echo ""; displayError_and_Exit 704; fi
	IPERF_T=$(echo $IPERF_|cut -d "," -f 1|sed -r s/\([0-9]{4}\)\([0-9]{2}\)\([0-9]{2}\)\([0-9]{2}\)\([0-9]{2}\)\([0-9]{2}\)$/\\1-\\2-\\3','\\4:\\5:\\6/)
	IPERF_B=$(echo $IPERF_|cut -d "," -f 9)
	PS=$(ps -ax -o pid,comm|grep -w iperf|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	if [[ -n $PS ]]; then sudo kill -s SIGINT $PS 2>/dev/null; fi
	if [[ -n $IPERFPROC_PID ]]; then sudo kill -s SIGINT $IPERFPROC_PID 2>/dev/null; fi
}

function copiarMetricas
{
	local METRICS_DDIR='.'
	local METRICS_DFILE=$(echo $COMANDO|sed -e 's/srs//')_m_$TIME.csv
	local METRICS_FILE=$(echo $COMANDO|sed -e 's/srs//')_metrics.csv
	local VAR=$(stat -c "%Y,%s" /tmp/$METRICS_FILE)
	if [[ ! -f /tmp/$METRICS_FILE ]]; then
		displayError_and_Exit 800
	else
		if (( $(($(echo $VAR|cut -d "," -f 1)-$(date -d $TIME +%s))) < 0 ));then
			displayError_and_Exit 801
		fi
		if (( $(echo $VAR|cut -d "," -f 2)==0 )); then
			displayError_and_Exit 802
		fi
	fi
	if [[ $MODO == 'eNB' ]]; then METRICS_DDIR=$METRICS_ROOT/$METRICS_DIR; fi
	cp /tmp/$METRICS_FILE $METRICS_DDIR/$METRICS_DFILE
	echo -e "\n-> Archivo de métricas OK      | /tmp/$METRICS_FILE -> $METRICS_DDIR/$METRICS_DFILE"
}
#####################################################################################


trap 'echo -e "\n\033[?25h\033[0m\033[35mExit Code:$?"; on_exit' EXIT
## No modificar - Variables globales
MODO=eNB
COMANDO='srsenb'
COM_ARGS=''
IPSPGW=172.16.0.1
IPDIR=''
PUERTONC=6666
SHOWTIME=''
SHOWTIME_LEFT_TIME=''
TIME=$(date +"%y-%m-%d_%H:%M:%S")
EPCTIME=''
EPCPID=''
DEVTIME=''
DEVPID=''
DEVIF='srs_spgw_sgi'
IPERF_T='' # fecha,hora
IPERF_B='' # bps
##########Formato####################################################################
verificarFormato "$@"
#######Grupo 200-Tiempo##############################################################
if [[ $MODO == 'eNB' ]]; then
	verificarTiempo
	echo -e "\tShowtime at $SHOWTIME in $SHOWTIME_LEFT_TIME\n"
fi
############Grupo 300-EPC############################################################
# Se verifica que la EPC esté en ejecución
if [[ $MODO == 'eNB' ]];then
	verificarEPC
fi
sleep 0.5
############Grupo 400-[eNB o UE]#####################################################
echo -e "-> Estableciendo experimento   | args=$COM_ARGS"
sleep 0.5
# Se ejecuta el proceso y se verifica que efectivamente esté en ejecución
ejecutarSRS
sleep 0.5
############Grupo 500-LOGFILE########################################################
# Si el archivo de logs no se encuentra no se puede continuar con la ejecución
if [[ $MODO == 'eNB' ]];then
	verificarEPC_Logs
fi
sleep 0.5
############Grupo 600-Conexión eNB<->EPC#############################################
# Se verifica que el eNB esta conectado a la EPC
if [[ $MODO == 'eNB' ]];then
	echo -ne "-> Verificando conectividad    | eNB\033[s[.          ]EPC\033[u\033[2C"
	chequearConexion_eNB_EPC
fi
sleep 0.5
############Grupo 700-Conexión UE<->eNB#############################################
echo -ne "-> Buscando dirección IP del UE|  \033[s"
sleep 0.2
buscarIP_UE
sleep 0.5
# Chequeando la conexión
lanzarPINGPROC
sleep 0.1
echo -ne "\033[u\033[K\033[u-> Verificando conectividad    | UE\033[s[.           ]eNB\033[K\033[u\033[2C"
leerPINGPROC
sleep 0.5
# Enviar hora de inicio
if [[ $MODO == 'eNB' ]]; then
	echo -ne "\033[u-> Enviando órdenes al UE      |  \033[K\033[s"
	enviarSHOWTIME
else
	echo -ne "\033[u-> Esperando ordenes del eNB   |  \033[K\033[s"
	esperarSHOWTIME
fi
#jobs

###########Experimento#############################################################
SHOWTIME_LEFT_TIME=$(($(date -d $SHOWTIME +%s)-$(date  +%s)))
echo -en "-> Showtime in                 |   \033[s"
if (( $SHOWTIME_LEFT_TIME<0 )); then
	echo -ne "\033[39m\033[2D00"
	SHOWTIME_LEFT_TIME=0
else
	mostrarTiempoFaltante
fi
## Ejecución de la prueba ##
sleep 0.2
# Downlink
echo -en "\n-> Ejecutando IPERF DOWNLINK   | []"
if [[ $MODO == 'eNB' ]];then
	sleep 1
	lanzarIPERFPROC_cliente $IPDIR
else
	lanzarIPERFPROC_servidor
fi
leerIPERFPROC
sleep 0.5
# Envío reporte al eNB
if [[ $MODO == 'eNB' ]]; then
	esperarReporte "DOWNLINK"
else
	enviarReporte "DOWNLINK"
fi
sleep 0.5
echo -en "\n-> Esperando los puertos TCP   |  \033[s"
i=1
sp="/-\|"
if [[ $MODO == 'eNB' ]]; then
	until [[ -z $(ss -ta|grep 5001) ]]; do sleep 0.5
		printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
	done
	echo "OK"|nc -w 1 $IPDIR $PUERTONC
else
	coproc NCPROC { nc -l $PUERTONC; } 2>/dev/null
	VAR=''
	until [[ -n $VAR ]]; do sleep 0.5
		read -t 0.5 -u ${NCPROC[0]} VAR
		printf "\033[u\b\033[?25l\033[32m${sp:i++%${#sp}:1}"
	done
	PS=$(ps -ax -o pid,comm|grep -w nc|sed -e 's/^[ \t]*//'|cut -d " " -f 1)
	if [[ -n $PS ]]; then sudo kill -s SIGINT $PS; fi
	if [[ -n $NCPROC_PID ]]; then sudo kill -s SIGINT $NCPROC_PID; fi
fi
echo -en "\033[u\033[39m\bOK"
# Uplink
sleep 0.5
echo -en "\n-> Ejecutando IPERF UPLINK     | []"
if [[ $MODO == 'eNB' ]];then
	lanzarIPERFPROC_servidor
else
	sleep 2
	lanzarIPERFPROC_cliente $IPSPGW
fi
leerIPERFPROC
sleep 0.5
# Envío reporte al eNB
if [[ $MODO == 'eNB' ]]; then
	esperarReporte "UPLINK"
else
	enviarReporte "UPLINK"
fi
sleep 0.5
###########Grupo 800-Copiado del archivo de métricas###############################
sudo kill -s SIGINT $DEVPID
while [[ -n $(ps -ax -o comm|grep $COMANDO) ]]; do sleep 0.5; done
copiarMetricas
sleep 0.5
echo -e "\t\033[33mEJECUCIÓN COMPLETADA"