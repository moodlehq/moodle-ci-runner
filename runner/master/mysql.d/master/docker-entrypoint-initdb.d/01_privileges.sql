GRANT SHUTDOWN ON *.* TO 'multi_admin'@'localhost' IDENTIFIED BY 'multipass';
CREATE USER 'replication'@'%' IDENTIFIED BY 'replication';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';

GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'moodle';
GRANT ALL ON *.* TO 'moodle'@'%' IDENTIFIED BY 'moodle';

FLUSH PRIVILEGES;
