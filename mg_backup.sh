#!/bin/bash
#############mail################
set -x


mail_from="jiajia.tao@em.denachina.com"
mail_subject="HOS官服MongoDB备份信息"
mail_smtp="smtp.qiye.163.com"
mail_user="jiajia.tao@em.denachina.com"
mail_pass="Hkk5N3jWg3"
mail_nssconfigdir="/etc/pki/nssdb"
mail_to="jiajia.tao@dena.jp"

mail(){
cat "$1" | mailx -v -r "$2" -s "$3" -S smtp="$4" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="$5" -S smtp-auth-password="$6" -S ssl-verify=ignore -S nss-config-dir="$7" "$8"
}

date=`date +%Y%m%d`
datedel=`date -d '-7 day' +%Y%m%d`
bakpath="/data1/backup/"
logpath="/data1/backup/log/"
log_file="${logpath}${date}.log"

function check_result(){
	res=$?
	proj=$1
	if [[ ! -d $logpath ]];then
		mkdir $logpath
	fi
	if [[ $res == 0 ]];then
		echo "$proj MongoDB OK" >> ${log_file}
	else
		echo "$proj MongoDB NOK" >> ${log_file}
	fi
}
#####################
if [ ! -d $logpath ];then
    mkdir -p $logpath
fi

flag=`echo "rs.status()"|mongo --quiet  --port 28018 | grep myState|cut -d ":" -f 2 |cut -d "," -f 1 |cut -d " " -f 2`
if [ $flag == 2 ];then

  if [[ -f ${logpath}backup.log ]];then
	mv -f ${logpath}backup.log ${logpath}backup.log.old
  fi

  if [[ -f ${logpath}${datedel}.log ]];then
	rm -f ${logpath}${datedel}.log
  fi
#insert time info
  echo "$(date)" >> ${log_file}

  echo "db.runCommand({fsync:1,lock:1})" | /usr/bin/mongo --quiet  --port 28018 admin &>> ${logpath}backup.log
  check_result lock

  for db in $(echo "show dbs" | /usr/bin/mongo --quiet  --port 28018 | grep -vE 'local|^test'|awk '{print $1}')
#for db in $(echo "show dbs" | /usr/bin/mongo --quiet | grep 'game-test-2'|awk '{print $1}')
  do
    echo -e "\n"  >> ${logpath}backup.log
    echo "==========Dumping ${db}=======" >> ${logpath}backup.log
    /usr/bin/mongodump -d ${db} -o ${bakpath}${date} &>> ${logpath}backup.log&&
    echo "dump ${db} OK" >> ${log_file}
  done

  echo "db.fsyncUnlock()" | /usr/bin/mongo --quiet --port 28018 admin &>> ${logpath}backup.log
  check_result unlock

  cd ${bakpath}${date}
  for db in $(echo "show dbs" | /usr/bin/mongo --quiet --port 28018 | grep -vE 'local|^test'|awk '{print $1}')
#  for db in $(echo "show dbs" | /usr/bin/mongo --quiet | grep 'game-test-2'|awk '{print $1}')
  do
  tar --remove-files -czf ${db}.tgz ./${db}&&echo "Compressing ${db} OK" >> ${log_file}||echo "Compressing ${db} NOK" >> ${log_file}
  done

  if [ -d ${bakpath}${datedel} ];then
	 rm -rf ${bakpath}${datedel}
  fi

  if grep -q NOK ${log_file};then
  	mail "$log_file" "$mail_from" "$mail_subject" "$mail_smtp" "$mail_user" "$mail_pass" "$mail_nssconfigdir" "$mail_to"
  fi
else
  echo 'MongoDB is in bad health!' >> ${log_file}
  mail "$log_file" "$mail_from" "$mail_subject" "$mail_smtp" "$mail_user" "$mail_pass" "$mail_nssconfigdir" "$mail_to"
fi
