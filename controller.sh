#!/bin/bash

source update.sh
source lvm.sh
source log.sh
source view.sh

intro
choose

case $option in
    "1")
        printf "TESTE OPÇÃO 1\n"
    ;;
    "2")
        fetchVolumes 0
    ;;
    "3")
        printf "TESTE OPÇÃO 3\n"
    ;;
    "4")
        snapshotViability
    ;;
    *)
        printf "TESTE!\n"
    ;;
esac
