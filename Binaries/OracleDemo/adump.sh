source ~/.bash_profile
LOCKFILE=/tmp/adump.lock
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "already running"
    exit
fi

# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}

# do stuff
while :
do
     rm -rf /u02/app/oracle/admin/$ORACLE_SID/adump/*
     sleep 10
done
rm -f ${LOCKFILE}