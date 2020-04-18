# srsLTEGita
Herramientas para la ejecución de pruebas de desempeño de **_LTE_** usando el software **srsLTE** y los módulos SDR **USRP B210** controlados por el driver **UHD** de _Ettus Research_.  
  
Se compone de los siguientes elementos principales:  

  * Parche que modifica el software [srsLTE](https://github.com/srsLTE/srsLTE)  
  * Script de ejecución de la prueba.

y los siguientes elementos de apoyo:  

  * Script para el procesamiento de las métricas  
  * Script para las gráficas de _gnuplot_  

### Parchado e instalación de srsLTE
1. Obtenga el paquete [srsLTE](https://github.com/srsLTE/srsLTE)  
  1.1 **Verifique e instale las diferentes dependencias**  
  1.2 Opcionalmente (recomendado) instale el paquete [srsGUI](https://github.com/srsLTE/srsGUI)  
  1.3 `git clone https://github.com/srsLTE/srsLTE`  
  1.4 `echo -e "build/\n.gitignore" > srsLTE/.gitignore`  
2. Descargue y aplique el parche  
  2.1 `git clone https://github.com/wilmar-arcila/srsLTEGita.git; cp srsLTEGita/srsLTEGita.patch .`  
  2.2 `patch -p0 < srsLTEGita.patch; rm srsLTEGita.patch`  
3. Compile e instale el software srsLTE modificado  
  3.1 `cd srsLTE; mkdir build; cd build`  
  3.2 `rm CMakeCache.txt;cmake -DENABLE_BLADERF=OFF -DENABLE_SOAPYSDR=OFF -DENABLE_ZEROMQ=OFF -DENABLE_GUI=ON ../`  
  3.3 En este punto verificar que están instaladas todas las dependencias requeridas chequeando la salida del comando anterior prestando especial atención a los paquetes del tipo _xxxxx-dev_  
  3.4 `make -j4`  
  3.5 `make test`  
  3.6 `sudo make install`  
  
  **Nota para srsGUI**:  
  Si obtiene errores del tipo "_X Error: BadDrawable (invalid Pixmap or Window parameter) 9_" cuando ejecuta srsenb o srsue con la interfaz gráfica habilitada, es posible que se solucione añadiendo la siguiente línea al archivo _/etc/environment_  
  `QT_X11_NO_MITSHM=1`  
  (necesita reiniciar)  

### Sincronismo entre los equipos  
Los equipos donde se va a ejecutar tanto el eNB como el UE deben estar sincronizados con un error de menos de 1 segundo.  
Para verificarlo puede ejecutar el siguiente comando en ambos equipos de manera simultánea `date +%s`  
Aunque es posible realizar la sincronización de manera manual, éste método es propenso al error. El siguiente procedimiento de sincronización automática se probó entre dos máquinas Ubuntu 18.04  

1. Deshabilitar _systemd-timesync_ ya que [no proporciona el sincronismo necesario](https://unix.stackexchange.com/questions/305643/ntpd-vs-systemd-timesyncd-how-to-achieve-reliable-ntp-syncing)  
  `sudo systemctl stop systemd-timesyncd`  
  `sudo systemctl disable systemd-timesyncd`  
2. Instalar _ntp_ y _ntpstat_ `sudo apt install ntp ntpstat`  
3. Seleccionar un pool de [servidores](https://www.pool.ntp.org/es/) con los cuales realizar la sincronización  
4. Ingresar (reemplazar los existentes) los servidores seleccionados en el archivo de configuración de ntpd _**/etc/ntpd.conf**_  
5. Establecer la hora por medio de los servidores ntp y mantenerla sincronizada (https://www.ntppool.org/es/use.html)  
  **NOTA:** [No usar](http://support.ntp.org/bin/view/Dev/DeprecatingNtpdate) _**ntpdate**_   
6.  Reiniciar el servicio  
  `sudo systemctl stop ntp.service`  
  `sudo ntpd -qg`  
  `sudo systemctl start ntp.service`  
7. **¡Ayuda!, mi equipo no entra en sincronismo con los servidores seleccionados**  

    * Verifique con Wireshark que se estén intercambiando paquetes ntp (_udp 123_ )  
    * Si no se están intercambiando paquetes es posible que algún firewall los esté bloqueando. Ver [ésto](https://askubuntu.com/questions/14558/how-do-i-setup-a-local-ntp-server) y [ésto](   https://serverfault.com/questions/806274/how-to-set-up-local-ntp-server-without-internet-access-on-ubuntu)  
    Puede solicitar que permitan el intercambio de dichos paquetes o establecer un servidor NTP de [manera local](http://www.satsignal.eu/ntp/Raspberry-Pi-NTP.html)  
    * Una última opción es convertir uno de los equipos involucrados en el experimento en un servidor NTP. Esto permitiría sincronizar los equipos incluso a sabiendas que la hora no será necesariamente la correcta.  
  
    El archivo de configuración del **servidor** (192.168.0.20) quedaría de la siguiente manera (modificar para las condiciones propias para otro servidor y/o otra red)  
    ```
    /etc/ntp.conf
    # Clients from this (example!) subnet have unlimited access, but only if
    # cryptographically authenticated.
    #restrict 192.168.123.0 mask 255.255.255.0 notrust
    restrict 192.168.0.0 mask 255.255.255.0 nomodify notrap

    # If you want to provide time to your local subnet, change the next line.
    # (Again, the address is an example only.)
    broadcast 192.168.0.255

    # If you want to listen to time broadcasts on your local subnet, de-comment the
    # next lines.  Please do this only if you trust everybody on the network!
    #disable auth
    #broadcastclient

    #Changes recquired to use pps synchonisation as explained in documentation:
    #http://www.ntp.org/ntpfaq/NTP-s-config-adv.htm#AEN3918

    server 127.127.1.0
    fudge 127.127.1.0 stratum 10
    ```  
    y el de los **clientes**  
    ```
    /etc/ntp.conf
    server 192.168.0.20 iburst

    # If you want to listen to time broadcasts on your local subnet, de-comment the
    # next lines.  Please do this only if you trust everybody on the network!
    disable auth
    broadcastclient
    ```  

  
### Ejecución de la prueba
Si los equipos están conectados a una red diferente a la que se creará entre el nodo eNB y el nodo UE de LTE, se puede automatizar el envío y procesamiento de las métricas generadas por el UE. De lo contrario esto debe hacerse manualmente.  
En caso de desear (y poder) realizarlo de forma automática, habilite dicha opción e ingrese la dirección IP del equipo donde correrá el eNB. **Ésto debe realizarse en el script _run_experiment.sh_**.  

1. (**Sólo en el eNB**) Ejecute la EPC enviando los mensajes de LOG al archivo epc1.log: `sudo srsepc --log.filename stdout 2>&1|tee /tmp/epc1.log`  
2.  Ejecute el script _run_experiment.sh_  
  2.1 (**eNB**) Abra otra consola y ejecute el script. Verifique su uso con la opción -h: `./run_experiment -h`  
  2.2 (**UE**) Ejecute el script _run_experiment_ en modo UE `./run_experiment -u`  

#### Solo en modo manual al finalizar la prueba  
3. Copie el archivo de métricas del UE ubicado en **/tmp/ue\_metrics.csv** al equipo eNB bajo el nombre _ue\_m\_**$TIME**.csv_. Verifique el valor de $TIME para las métricas generadas en el eNB.  
  Ej: _ue_m_20-04-15_13:02:52.csv_
4. Procese las métricas `./processMetrics $TIME`  
  Ej: ./processMetrics '20-04-15_13:02:52'
5. Grafique las métricas `gnuplot -p -e "TITLE='Algún titulo'" -e "TIME='$TIME' plotMetrics.gnuplot`  
  Ej: gnuplot -p -e "TITLE='Cable, eNB\_Gain=40, UE\_Gain=25'" -e "TIME='20-04-15_13:02:52' plotMetrics.gnuplot
   
----------------------------------------------------------------------------   
   
#### Cambios

| FECHA | ELEMENTO | TAG | DESCRIPCIÓN |
|-------|----------|-----|-------------|
| 18/04/2020 | scripts | v1.0 | Versión completamente funcional |
| 10/03/2020 | Parche | -- | Inclusión de la marca de tiempo 'epoch' en los archivos de métricas para el eNB y el UE |

El parche es creado usando el siguiente comando:  
`diff -Naur --exclude="build" --exclude=".git" srsLTE/ srsLTEGita/ > srsLTEGita.patch`
