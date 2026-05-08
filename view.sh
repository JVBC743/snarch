#!/bin/bash

#VER SE VAI PRECISAR SER UM DAEMON
source controller.sh

printf "=============#==================#=============\n"
printf "============# Welcome to Snarch! #============\n"
printf "=============#==================#=============\n"

printf "Do you wish to take of a single volume or more volumes?\n"
printf "[1] Individual\n[2] More than one\n\n"

printf "Currently, these are the volumes created in this system:\n"

displayVolume