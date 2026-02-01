#!/usr/bin/env bash

# Create a new directory for the composer installation.

PHPWORKINGDIR="${PHPWORKINGDIR:-/var/www/composed}"
mkdir -p ${PHPWORKINGDIR}
