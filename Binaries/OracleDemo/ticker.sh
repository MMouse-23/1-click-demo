#!/usr/bin/env bash
source ~/.bash_profile
TABLE_SUFFIX='oracle'

LOCKFILE=/tmp/ticker.lck
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "already running"
    exit
fi

# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}


TABLE_NAME=era_demo_${TABLE_SUFFIX}
SEQ_NAME=era_seq_${TABLE_SUFFIX}
$ORACLE_HOME/bin/sqlplus / as sysdba <<EOF;
    create sequence ${SEQ_NAME} start with 1;
    create table ${TABLE_NAME} (id number, time_stamp timestamp(6));
    exit;
EOF
while :
do
    $ORACLE_HOME/bin/sqlplus / as sysdba <<EOF;
        insert into ${TABLE_NAME} values (${SEQ_NAME}.nextval, sys_extract_utc(systimestamp));
        commit;
        exit;
EOF
sleep 1
done
rm -f ${LOCKFILE}