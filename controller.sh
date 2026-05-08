#!/bin/bash
source update.sh
source lvm.sh
source log.sh

function displayVolume(){
    vol=$(fetchVolume)
    printf "%s\n" "${vol}"
}

