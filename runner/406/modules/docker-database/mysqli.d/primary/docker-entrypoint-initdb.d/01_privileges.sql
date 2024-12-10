CREATE USER 'replication'@'%' IDENTIFIED WITH caching_sha2_password BY 'replication';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';

ALTER USER 'root'@'%' IDENTIFIED BY 'moodle';

FLUSH PRIVILEGES;
