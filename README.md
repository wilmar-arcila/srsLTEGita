# srsLTEGita
Herramientas para la ejecución de pruebas de desempeño de **_LTE_** usando el software **srsLTE** y los módulos SDR **USRP B210** controlados por el driver **UHD** de _Ettus Research_.  
Se compone de los siguientes elementos:
  * Parche que modifica el software [srsLTE](https://github.com/srsLTE/srsLTE)  
  * Script de ejecución de la prueba.

### Parchado e instalación de srsLTE
1. Obtenga el paquete [srsLTE](https://github.com/srsLTE/srsLTE)  
  1.1 `git clone https://github.com/srsLTE/srsLTE`  
  1.2 `echo -e "build/\n.gitignore" > srsLTE/.gitignore`  
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
  
### Ejecución de la prueba
1. Ejecute la EPC enviando los mensajes de LOG al archivo epc1.log: `sudo srsepc --log.filename stdout|tee /tmp/epc1.log`  
2. En otra consola ejecute el script _run_experiment.sh_. Verifique su uso con la opción -h: `./run_experiment -h`    
3. xxxxx


#### Cambios
10/03/2020 - Inclusión de la marca de tiempo 'epoch' en los archivos de métricas para el eNB y el UE

El parche es creado usando el siguiente comando:  
`diff -Naur --exclude="build" --exclude=".git" srsLTE/ srsLTEGita/ > srsLTEGita.patch`
