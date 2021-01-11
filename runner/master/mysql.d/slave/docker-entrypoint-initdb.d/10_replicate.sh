#!/bin/bash
set -e

echo "============================================================================"
echo "== 10_replicate.sh"
echo "============================================================================"

sleep 5

# We need to set this for some inane reason otherwise it fails to start mysql.
# This seems to be a bug with the entrypoint.sh
DATABASE_ALREADY_EXISTS='true'

docker_temp_server_stop

echo "Copying moodle.cnf"
gosu root cp /config/moodle.cnf /etc/mysql/conf.d/

echo "Restarting mysqld"
docker_temp_server_start mysqld

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

echo "Stopping server to apply slave configuration"
docker_temp_server_stop
gosu root cp /config/slave.cnf /etc/mysql/conf.d/

echo "Restarting mysqld"
docker_temp_server_start mysqld

echo "Starting slave"
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
