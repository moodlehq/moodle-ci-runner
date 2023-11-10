CREATE USER 'replication'@'%' IDENTIFIED BY 'replication';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';

ALTER USER 'root'@'%' IDENTIFIED BY 'moodle';

FLUSH PRIVILEGES;
