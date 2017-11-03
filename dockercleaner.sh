#!/bin/bash

#############################################
# This script will remove any existing docker
# instances which have existed but not removed
#############################################

docker rm $(docker ps -a --filter 'exited=0' -q)
