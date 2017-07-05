#!/bin/bash

######################################################
# We use mariadb and oracle db docker for some of our
# jobs as mariadb01.test.in.moodle.com won't suffice
# for all jobs. So here is a script to start a new
# Mariadb instance
#####################################################

# ./dockerdb.sh mariadb
# or
# ./dockerdb.sh oracle
# or
# ./dockerdb.sh sqlsrv

# NOTE: For sqlsrv you need to have sqltools
# https://docs.microsoft.com/en-gb/sql/linux/sql-server-linux-setup-tools#ubuntu

#####################################################

dbs=(\
"behat_whole_suite_m31_phpunit" \
"behat_whole_suite_m31_parallel" \
"behat_whole_suite_m31_chrome" \
"behat_whole_suite_m31_phantomjs" \
"behat_whole_suite_m31_parallel_clean" \
"behat_whole_suite_m32_phpunit" \
"behat_whole_suite_m32_parallel" \
"behat_whole_suite_m32_chrome" \
"behat_whole_suite_m32_phantomjs" \
"behat_whole_suite_m32_parallel_clean" \
"behat_whole_suite_m33_phpunit" \
"behat_whole_suite_m33_parallel" \
"behat_whole_suite_m33_chrome" \
"behat_whole_suite_m33_phantomjs" \
"behat_whole_suite_m33_parallel_clean" \
"behat_whole_suite_m_phpunit" \
"behat_whole_suite_m" \
"behat_whole_suite_m_parallel" \
"behat_whole_suite_m_chrome" \
"behat_whole_suite_m_phantomjs" \
"behat_whole_suite_m_parallel_boost" \
"behat_whole_suite_m_phpunit_php7" \
)

function usage() {
cat << EOF
##################################### Usage ####################################
# ./dockerdb.sh mariadb
# or
# ./dockerdb.sh oracle
# or
# ./dockerdb.sh sqlsrv

# NOTE: For sqlsrv you need to have sqltools
# https://docs.microsoft.com/en-gb/sql/linux/sql-server-linux-setup-tools#ubuntu
#################################################################################
EOF
}

# If no argument passed then user don't know what he is doing. Stop.
if [ -z "${1}" ] ; then
    usage
    exit 1
fi

docker network list  --filter name=nightly | grep nightly > /dev/null
if [ $? -ne 0 ]
then
    docker network create nightly
fi

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

# Check if we have old instance running/exit state.
docker inspect ${1} > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Cleaning old ${1} instance"
    docker inspect --format="{{ .State.Running }}" ${1} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        docker stop ${1}
    fi
    docker rm -f ${1}
fi


# Start docker instance.
if [ "${1}" == "oracle" ]; then
    echo "Starting oracle instance"
    docker run \
      --detach \
      --name oracle \
      --network nightly \
      -p 49160:22 \
      -p 1521:1521 \
      -v $SCRIPTPATH/oracle.d/tmpfs.sh:/docker-entrypoint-initdb.d/tmpfs.sh \
      --tmpfs /var/lib/oracle \
      danpoltawski/moodle-db-oracle
    sleep 20

# MARIADB
elif [ "${1}" == "mariadb" ]; then
    echo "Starting mariadb instance"
    docker run \
      --detach \
      --name mariadb \
      --network nightly \
      -e MYSQL_ROOT_PASSWORD=moodle \
      -e MYSQL_DATABASE=moodle \
      -e MYSQL_USER=moodle \
      -e MYSQL_PASSWORD=moodle \
      -p 3307:3306 \
      --tmpfs /var/lib/mysql:rw \
      -v $SCRIPTPATH/mysql.d:/etc/mysql/conf.d \
      mariadb:latest
    # Wait few sec, before executing commands.
    sleep 20
    docker exec -e MYSQL_PWD=moodle -d mariadb /usr/bin/mysql -uroot -e 'SET GLOBAL innodb_file_per_table=1;SET GLOBAL innodb_file_format=Barracuda;ALTER DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;'

    # Create dbs.
    for db in "${dbs[@]}"; do
        echo "Creating database: ${db}"
        createdbsql="create database ${db} default character set utf8 COLLATE utf8_bin;"
        docker exec -e MYSQL_PWD=moodle mariadb /usr/bin/mysql -uroot -e "$createdbsql"
        grantdbsql="grant all privileges on ${db}.*  to 'moodle'@'%' identified by 'moodle';flush privileges;"
        docker exec -e MYSQL_PWD=moodle mariadb /usr/bin/mysql -uroot -e "$grantdbsql"
    done

# SQLSRV
elif [ "${1}" == "sqlsrv" ]; then
    echo "Starting Sqlsrv instance"
    docker run \
      --detach \
      --name sqlsrv \
      --network nightly \
      -e ACCEPT_EULA=Y \
      -e SA_PASSWORD=Passw0rd! \
      -p 1433:1433 \
      microsoft/mssql-server-linux

    # Wait for 20 seconds to ensure we have sqlsrv  docker initialized.
    sleep 20
    DBHOST=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" sqlsrv)
    # Check if sqlsrv is ready.
    docker exec sqlsrv /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Passw0rd!' -Q "select top(3) name from sys.objects" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Sqlsrv is not ready. Please check sqlcmd is installed."
        exit 1
    fi

    # Create dbs.
    for db in "${dbs[@]}"; do
        docker exec sqlsrv /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Passw0rd!' -Q "CREATE DATABASE ${db} COLLATE LATIN1_GENERAL_CS_AS"
        docker exec sqlsrv /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Passw0rd!' -Q "ALTER DATABASE ${db} SET ANSI_NULLS ON"
        docker exec sqlsrv /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Passw0rd!' -Q "ALTER DATABASE ${db} SET QUOTED_IDENTIFIER ON"
        docker exec sqlsrv /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Passw0rd!' -Q "ALTER DATABASE ${db} SET READ_COMMITTED_SNAPSHOT ON"
    done

# Mysql
elif [ "${1}" == "mysql" ]; then
    echo "Starting mysql instance"
    docker run \
      --detach \
      --name mysql \
      --network nightly \
      -e MYSQL_ROOT_PASSWORD=moodle \
      -e MYSQL_DATABASE=moodle \
      -e MYSQL_USER=moodle \
      -e MYSQL_PASSWORD=moodle \
      -p 3306:3306 \
      --tmpfs /var/lib/mysql:rw \
      -v $SCRIPTPATH/mysql.d:/etc/mysql/conf.d \
      mysql:5
    # Wait few sec, before executing commands.
    sleep 20
    docker exec -e MYSQL_PWD=moodle -d mysql /usr/bin/mysql -uroot -e 'SET GLOBAL innodb_file_per_table=1;SET GLOBAL innodb_file_format=Barracuda;ALTER DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;'

    # Create dbs.
    for db in "${dbs[@]}"; do
        echo "Creating database: ${db}"
        createdbsql="create database ${db} default character set utf8 COLLATE utf8_bin;"
        docker exec -e MYSQL_PWD=moodle mysql /usr/bin/mysql -uroot -e "$createdbsql"
        grantdbsql="grant all privileges on ${db}.*  to 'moodle'@'%' identified by 'moodle';flush privileges;"
        docker exec -e MYSQL_PWD=moodle mysql /usr/bin/mysql -uroot -e "$grantdbsql"
    done

#Pgsql
elif [ "${1}" == "pgsql" ]; then
    echo "Starting pgsql instance"
    docker run \
      --detach \
      --name pgsql \
      --network nightly \
      -e POSTGRES_USER=moodle \
      -e POSTGRES_PASSWORD=moodle \
      -e POSTGRES_DB=moodle \
      -v $SCRIPTPATH/pgsql.d:/docker-entrypoint-initdb.d \
      --tmpfs /var/lib/postgresql/data:rw \
      -p 5532:5432 \
      postgres
    # Wait few sec, before executing commands.
    sleep 20

    # Create dbs.
    for db in "${dbs[@]}"; do
        echo "Creating database: ${db}"
        docker exec pgsql psql -U postgres -c "CREATE DATABASE ${db} WITH OWNER moodle ENCODING 'UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8' TEMPLATE=template0;"
    done

else
    echo "You should not have reached here...Check db passed"
    usage

fi
