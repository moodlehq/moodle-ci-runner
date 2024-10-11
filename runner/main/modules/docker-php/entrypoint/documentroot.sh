#!/usr/bin/env bash

# Replace the default document root in Apache configuration files with the one set in the environment variable.
# This is needed to make the webserver work with the Moodle codebase for Moodle 5.1 onwards with MDL-83424.

sed -ri -e 's@/var/www/html@${APACHE_DOCUMENT_ROOT}@g' /etc/apache2/sites-available/*.conf
sed -ri -e 's@/var/www/@${APACHE_DOCUMENT_ROOT}@g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
