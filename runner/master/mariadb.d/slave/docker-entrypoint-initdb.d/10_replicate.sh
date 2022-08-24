#!/bin/bash
set -e

echo "============================================================================"
echo "== 10_replicate.sh"
echo "============================================================================"

sleep 5

echo "Dumping ${DBHOST}"
mysql -u root -pmoodle -h ${DBHOST} -e "FLUSH TABLES WITH READ LOCK;" moodle
mysql -u root -pmoodle -h ${DBHOST} -e "SHOW MASTER STATUS;" moodle

mysqldump -u root -pmoodle -h ${DBHOST} --opt moodle
mysqldump -u root -pmoodle -h ${DBHOST} --opt moodle > /tmp/moodle.sql
mysql -u root -pmoodle -h ${DBHOST} -e "UNLOCK TABLES;" moodle
echo "Done"

echo "Master status:"
mysql -u root -pmoodle -h ${DBHOST} -e "SHOW MASTER STATUS;" moodle
position=`mysql -u root -pmoodle -h ${DBHOST} -e "SHOW MASTER STATUS;" moodle | grep 'mysql-bin' | awk '{print $2}'`
replfile=`mysql -u root -pmoodle -h ${DBHOST} -e "SHOW MASTER STATUS;" moodle | grep 'mysql-bin' | awk '{print $1}'`
echo "Master dump complete"
echo "Current position is {$replfile} {$position}"

echo "Restoring into client"
mysql -u root -pmoodle moodle < /tmp/moodle.sql

mysql -u root -pmoodle moodle << EOSQL
CHANGE MASTER TO
  MASTER_HOST='${DBHOST}',
  MASTER_USER='replication',
  MASTER_PASSWORD='replication',
  MASTER_LOG_FILE='$replfile',
  MASTER_LOG_POS=$position;
START SLAVE;
SHOW SLAVE STATUS\G
EOSQL

sleep 5

mysql -u root -pmoodle moodle << EOSQL
SHOW SLAVE STATUS\G
EOSQL
