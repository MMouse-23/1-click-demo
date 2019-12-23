source ~/.bash_profile
LOCKFILE=/tmp/swingbench.lock
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "already running"
    exit
fi

# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}

DBA_PASSWORD=$1
SOE_DBF_FILE=$2
if [ -z "$DBA_PASSWORD" ]; then
  echo "Usage: $0 <DBA Password> <Location of dbf file>"
  echo "    <DBA Password>: is your sysdba paassword."
  echo ""
  echo "    <location of dbf file>: Location where you want data file to be created."
  echo "          Example: +DATADG/$ORACLE_SID/DATAFILES/soe.dbf, if ASM is used."
  echo "                   /oradata/data/$ORACLE_SID/soe.dbf for SIDB"
  echo ""
  echo " IMPORTANT "
  echo " ----------"
  echo " 1. The script downloads the swingbench if it is not found under $SWINGBENCH_HOME"
  echo " 2. Your ~/.bash_profile must have ORACLE_SID variable set."
  echo " "
  exit 1
fi
if [ -z "$DBA_PASSWORD" ]; then
  echo "Usage: $0 <DBA Password> <Location of dbf file>"
  exit 1
fi

lsnrctl start

IP_ADDRESS=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
CONNECT_STR=//$IP_ADDRESS/$ORACLE_SID
# how much time to run hh:mmormat
RUN_TIME=23:00
DELAY_BETWEEN_RUNS=3600
SWINGBENCH_HOME=$HOME/swingbench
SWINGBENCH_BIN=$SWINGBENCH_HOME/bin/oewizard
CHARBENCH_BIN=$SWINGBENCH_HOME/bin/charbench

if [ ! -f $SWINGBENCH_BIN ]; then
  # S
  echo "Downloading swingbench."
  wget http://www.dominicgiles.com/swingbench/swingbench261076.zip
  echo "Extracting swingbench"
  unzip -d `dirname $SWINGBENCH_HOME` swingbench261076.zip
fi

if [ -f $SWINGBENCH_BIN ]; then
  echo "$SWINGBENCH_BIN exists."
fi

cd `dirname $SWINGBENCH_BIN`
command="$SWINGBENCH_BIN -scale 0.1 -cs $CONNECT_STR -dbap $DBA_PASSWORD -ts SOE -nopart -u soe -p soe -cl -bigfile -dt thin -nocompress -create -df $SOE_DBF_FILE"
echo Running $command
$command

cd `dirname $CHARBENCH_BIN`
command="$CHARBENCH_BIN -c $SWINGBENCH_HOME/configs/SOE_Server_Side_V2.xml -cs $CONNECT_STR -dt thin -intermin 0 -intermax 100 -a -v users,tpm,cpu,tps -rt $RUN_TIME -r $HOME/results.xml -bg -uc 1"

while [[ 1 ]]; do
  echo Running $command
  $command
  echo "Sleeping ..."
  sleep $DELAY_BETWEEN_RUNS
done
