CREATE USER 'replication'@'%' IDENTIFIED WITH mysql_native_password BY 'replication';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';

ALTER USER 'root'@'%' IDENTIFIED BY 'moodle';

FLUSH PRIVILEGES;
