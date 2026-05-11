#!/bin/bash

#PONDERAR: QUEM FICA RESPONSÁVEL APENAS PELA COLETA DE DADOS E QUEM FICA RESPONSÁVEL
# APENAS PELO POLIMENTO DESSES DADOS EM TABELA?

function fetchVolume(){

    declare -a volumes

    mapfile -t raw_volume < <(lsblk | grep "lvm" | \
    awk -F ' ' '{ print $2 }' | sed -e 's/└─//g' -e 's/ /\n/g')

    volumes[i]=$((
        printf "VOLUME_GROUP LOGICAL_VOLUME\n"
    
        for ((i=0; i<${#raw_volume[@]};i++)); do
            printf "%s\n" "${raw_volume[i]}" | awk -F'-' '{ print $1, $2 }'
        done

    ) | column -t -s ' ' -o ' ')

    printf "%s\n" "${volumes[@]}"
}