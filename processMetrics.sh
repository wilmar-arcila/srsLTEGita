#!/bin/bash
METRICS_ROOT='/media/wilmar/ACADEMICO/MAESTRIA/Proyecto/Vehicle_2_x/srsLTE/experiments/automated'
METRICS_DIR='cable' # Directorio para almacenar las métricas $METRICS_ROOT/$METRICS_DIR
METRICS_FILE_UE="ue_m_$1.csv"
METRICS_FILE_ENB="enb_m_$1.csv"
IPERF_FILE="Iperf_$1.csv"

if [[ -f $METRICS_ROOT/$METRICS_DIR/averages_enb.csv ]]; then rm $METRICS_ROOT/$METRICS_DIR/averages_enb.csv; fi
if [[ -f $METRICS_ROOT/$METRICS_DIR/averages_ue.csv ]]; then rm $METRICS_ROOT/$METRICS_DIR/averages_ue.csv; fi

if [[ $(tail -1 $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB) != '#eof' ]]; then echo "Archivo $METRICS_FILE_ENB incompleto";fi
if [[ $(tail -1 $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE) != '#eof' ]]; then echo "Archivo $METRICS_FILE_UE incompleto";fi

# Cambio 'is_attached' por 'isAttached' en el UE
if [[ -n $(grep 'is_attached' $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE) ]]; then
	sed -i 's/is_attached/isAttached/' $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE
fi
# Cambio 'nof_ue' por 'UEs' en el UE
if [[ -n $(grep 'nof_ue' $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB) ]]; then
	sed -i 's/nof_ue/UEs/' $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB
fi
# Incluyo llaves para su correcta interpretación por gnuplot
if [[ -z $(grep -e "[[:alpha:]]*_{[[:alpha:]]*}" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB) ]]; then
	sed -i 's/\(;[[:alpha:]]*_\)\([[:alpha:]]*\)/\1{\2}/g' $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB
fi
if [[ -z $(grep -e "[[:alpha:]]*_{[[:alpha:]]*}" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE) ]]; then
	sed -i 's/\(;[[:alpha:]]*_\)\([[:alpha:]]*\)/\1{\2}/g' $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE
fi

# Primera fila: Nombre de cada columna
# La columna vacía separa los datos para el eNB y el UE
echo -n "Time;DL_{Iperf};DL_{down};DL_{up};UL_{Iperf};UL_{down};UL_{up};;" > $METRICS_ROOT/$METRICS_DIR/averages_$1.csv
echo "Time;DL_{Iperf};DL_{down};DL_{UP};UL_{Iperf};UL_{down};UL_{UP}" >> $METRICS_ROOT/$METRICS_DIR/averages_$1.csv

########## PROCESAMIENTO DE LAS MÉTRICAS DEL eNB ###################
DOWNLINK_START=$(grep -e "^DOWNLINK,eNB,[[:digit:]]*,Start$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE|sed -e 's/^DOWNLINK,eNB,\([[:digit:]]*\),Start$/\1/')
DOWNLINK_=$(grep -e "^DOWNLINK,eNB,[[:digit:]]*,[[:digit:]]*$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE)
DOWNLINK_FIN=$(echo $DOWNLINK_|sed -e 's/^DOWNLINK,eNB,\([[:digit:]]*\),[[:digit:]]*$/\1/')
DOWNLINK_IPERF=$(echo $DOWNLINK_|sed -e 's/^DOWNLINK,eNB,[[:digit:]]*,\([[:digit:]]*\)$/\1/')
NL_DL_START=$(grep $DOWNLINK_START $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 2)
NL_DL_FIN=$(grep $DOWNLINK_FIN $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 2)
UPLINK_START=$(grep -e "^UPLINK,eNB,[[:digit:]]*,Start$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE|sed -e 's/^UPLINK,eNB,\([[:digit:]]*\),Start$/\1/')
UPLINK_=$(grep -e "^UPLINK,eNB,[[:digit:]]*,[[:digit:]]*$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE)
UPLINK_FIN=$(echo $UPLINK_|sed -e 's/^UPLINK,eNB,\([[:digit:]]*\),[[:digit:]]*$/\1/')
UPLINK_IPERF=$(echo $UPLINK_|sed -e 's/^UPLINK,eNB,[[:digit:]]*,\([[:digit:]]*\)$/\1/')
NL_UL_START=$(grep $UPLINK_START $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 2)
NL_UL_FIN=$(grep $UPLINK_FIN $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 2)

# echo "DOWNLINK_START:$DOWNLINK_START"
# echo "DOWNLINK_:$DOWNLINK_"
# echo "DOWNLINK_FIN:$DOWNLINK_FIN"
# echo "DOWNLINK_IPERF:$DOWNLINK_IPERF"
# echo "NL_DL_START:$NL_DL_START"
# echo "NL_DL_FIN:$NL_DL_FIN"
# echo "UPLINK_START:$UPLINK_START"
# echo "UPLINK_:$UPLINK_"
# echo "UPLINK_FIN:$UPLINK_FIN"
# echo "UPLINK_IPERF:$UPLINK_IPERF"
# echo "NL_UL_START:$NL_UL_START"
# echo "NL_UL_FIN:$NL_UL_FIN"

# Procesamiento del DOWNLINK para el eNB
DOWNLINK_TOTAL=0
UPLINK_TOTAL=0
for i in $(seq $NL_DL_START $NL_DL_FIN); do
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 4)
	DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL+$VAR")
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 5)
	UPLINK_TOTAL=$(bc -l <<< "$UPLINK_TOTAL+$VAR")
done
DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL/($NL_DL_FIN-$NL_DL_START)")
UPLINK_TOTAL=$( bc -l <<< "$UPLINK_TOTAL/($NL_DL_FIN-$NL_DL_START)")
for i in $(seq $NL_DL_START $NL_DL_FIN); do
	echo "$i;$DOWNLINK_IPERF;$DOWNLINK_TOTAL;$UPLINK_TOTAL;;;;" >> $METRICS_ROOT/$METRICS_DIR/averages_enb.csv
done
# Procesamiento del UPLINK para el eNB
DOWNLINK_TOTAL=0
UPLINK_TOTAL=0
for i in $(seq $NL_UL_START $NL_UL_FIN); do
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 4)
	DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL+$VAR")
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_ENB|cut -d ';' -f 5)
	UPLINK_TOTAL=$(bc -l <<< "$UPLINK_TOTAL+$VAR")
done
DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL/($NL_UL_FIN-$NL_UL_START)")
UPLINK_TOTAL=$(bc -l <<< "$UPLINK_TOTAL/($NL_UL_FIN-$NL_UL_START)")
for i in $(seq $NL_UL_START $NL_UL_FIN); do
	echo "$i;;;;$UPLINK_IPERF;$DOWNLINK_TOTAL;$UPLINK_TOTAL;" >> $METRICS_ROOT/$METRICS_DIR/averages_enb.csv
done

########## PROCESAMIENTO DE LAS MÉTRICAS DEL UE ###################
DOWNLINK_START=$(grep -e "^DOWNLINK,UE,[[:digit:]]*,Start$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE|sed -e 's/^DOWNLINK,UE,\([[:digit:]]*\),Start$/\1/')
DOWNLINK_=$(grep -e "^DOWNLINK,UE,[[:digit:]]*,[[:digit:]]*$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE)
DOWNLINK_FIN=$(echo $DOWNLINK_|sed -e 's/^DOWNLINK,UE,\([[:digit:]]*\),[[:digit:]]*$/\1/')
DOWNLINK_IPERF=$(echo $DOWNLINK_|sed -e 's/^DOWNLINK,UE,[[:digit:]]*,\([[:digit:]]*\)$/\1/')
NL_DL_START=$(grep $DOWNLINK_START $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 2)
NL_DL_FIN=$(grep $DOWNLINK_FIN $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 2)
UPLINK_START=$(grep -e "^UPLINK,UE,[[:digit:]]*,Start$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE|sed -e 's/^UPLINK,UE,\([[:digit:]]*\),Start$/\1/')
UPLINK_=$(grep -e "^UPLINK,UE,[[:digit:]]*,[[:digit:]]*$" $METRICS_ROOT/$METRICS_DIR/$IPERF_FILE)
UPLINK_FIN=$(echo $UPLINK_|sed -e 's/^UPLINK,UE,\([[:digit:]]*\),[[:digit:]]*$/\1/')
UPLINK_IPERF=$(echo $UPLINK_|sed -e 's/^UPLINK,UE,[[:digit:]]*,\([[:digit:]]*\)$/\1/')
NL_UL_START=$(grep $UPLINK_START $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 2)
NL_UL_FIN=$(grep $UPLINK_FIN $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 2)

# echo "------------"
# echo "DOWNLINK_START:$DOWNLINK_START"
# echo "DOWNLINK_:$DOWNLINK_"
# echo "DOWNLINK_FIN:$DOWNLINK_FIN"
# echo "DOWNLINK_IPERF:$DOWNLINK_IPERF"
# echo "NL_DL_START:$NL_DL_START"
# echo "NL_DL_FIN:$NL_DL_FIN"
# echo "UPLINK_START:$UPLINK_START"
# echo "UPLINK_:$UPLINK_"
# echo "UPLINK_FIN:$UPLINK_FIN"
# echo "UPLINK_IPERF:$UPLINK_IPERF"
# echo "NL_UL_START:$NL_UL_START"
# echo "NL_UL_FIN:$NL_UL_FIN"

# Procesamiento del DOWNLINK para el UE
DOWNLINK_TOTAL=0
UPLINK_TOTAL=0
for i in $(seq $NL_DL_START $NL_DL_FIN); do
	#echo "1: $DOWNLINK_TOTAL $UPLINK_TOTAL"
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 9)
	#echo "2: $VAR"
	DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL+$VAR")
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 14)
	#echo "3: $VAR"
	UPLINK_TOTAL=$(bc -l <<< "$UPLINK_TOTAL+$VAR")
done
DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL/($NL_DL_FIN-$NL_DL_START)")
UPLINK_TOTAL=$( bc -l <<< "$UPLINK_TOTAL/($NL_DL_FIN-$NL_DL_START)")
#echo "$DOWNLINK_TOTAL $UPLINK_TOTAL"
for i in $(seq $NL_DL_START $NL_DL_FIN); do
	echo "$i;$DOWNLINK_IPERF;$DOWNLINK_TOTAL;$UPLINK_TOTAL;;;" >> $METRICS_ROOT/$METRICS_DIR/averages_ue.csv
done
# Procesamiento del UPLINK para el UE
DOWNLINK_TOTAL=0
UPLINK_TOTAL=0
for i in $(seq $NL_UL_START $NL_UL_FIN); do
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 9)
	DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL+$VAR")
	VAR=$(grep -e "^[[:digit:]]*;$i;" $METRICS_ROOT/$METRICS_DIR/$METRICS_FILE_UE|cut -d ';' -f 14)
	UPLINK_TOTAL=$(bc -l <<< "$UPLINK_TOTAL+$VAR")
done
DOWNLINK_TOTAL=$(bc -l <<< "$DOWNLINK_TOTAL/($NL_UL_FIN-$NL_UL_START)")
UPLINK_TOTAL=$(bc -l <<< "$UPLINK_TOTAL/($NL_UL_FIN-$NL_UL_START)")
for i in $(seq $NL_UL_START $NL_UL_FIN); do
	echo "$i;;;;$UPLINK_IPERF;$DOWNLINK_TOTAL;$UPLINK_TOTAL" >> $METRICS_ROOT/$METRICS_DIR/averages_ue.csv
done

############ CONCATENAR AMBAS MÉTRICAS EN UN SOLO ARCHIVO ################
NL_ENB=$(wc -l < $METRICS_ROOT/$METRICS_DIR/averages_enb.csv)
NL_UE=$(wc -l < $METRICS_ROOT/$METRICS_DIR/averages_ue.csv)
NL_D=$(($NL_ENB-$NL_UE))
# echo "ENB:$NL_ENB UE:$NL_UE D:$NL_D"
if (( $NL_D > 0 )); then
	for i in $(seq 1 $NL_D); do echo ";;;;;;" >> $METRICS_ROOT/$METRICS_DIR/averages_ue.csv; done
fi
if (( $NL_D < 0 )); then
	for i in $(seq 1 $((-$NL_D))); do echo ";;;;;;;" >> $METRICS_ROOT/$METRICS_DIR/averages_enb.csv; done
fi
paste -d";" $METRICS_ROOT/$METRICS_DIR/averages_enb.csv $METRICS_ROOT/$METRICS_DIR/averages_ue.csv >> $METRICS_ROOT/$METRICS_DIR/averages_$1.csv
rm $METRICS_ROOT/$METRICS_DIR/averages_enb.csv
rm $METRICS_ROOT/$METRICS_DIR/averages_ue.csv