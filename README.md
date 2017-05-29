# Nightly Scripts

Repository to ensure that the docker scripts are manageable

# Installation

Clone the repository

# Notes

Please ensure that you fetch the repository after making changes:

```
ssh jenkins@nightly
cd /store/scripts
git fetch origin master
git reset --hard origin/master
```

This needs to be performed on:
* nightly
* nightly02


# Common Tasks

## Adding databases to MariaDB, Oracle, and MSSQL.

We use docker for MariaDB, Oracle, and MSSQL.

When these servers are brought up, the databases are created.

To add a new database, or remove an old one, update the dockerdb.sh script and add/remove databases as required.
