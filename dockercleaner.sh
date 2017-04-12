#!/bin/bash

#############################################
# This script will remove any existing docker
# instances which have existed but not removed
#############################################

# Get all exited docker instances.
docker ps -a | grep "Exited" | awk '{print $1}' | sed 's/ //' > ~/dockerexit.txt

# Run though all and remove them
IFS='
'
exec 4<~/dockerexit.txt           # opening  file via descriptor
while read DOCKERID <&4; do
 docker rm $DOCKERID
done

# Remove the file
rm ~/dockerexit.txt
