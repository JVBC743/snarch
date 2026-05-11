#!/bin/bash

#PONDERAR: QUEM FICA RESPONSÁVEL APENAS PELA COLETA DE DADOS E QUEM FICA RESPONSÁVEL
# APENAS PELO POLIMENTO DESSES DADOS EM TABELA?

IFS="\n"

function fetchVolumes() {

    code=$1

    # Os códigos passados como parâmetros são para coletar individualmente...

    # 0) Informações de todos os volumes
    # 1) informações dos volumes físicos
    # 2) informações dos grupos de volumes
    # 3) informações dos volumes lógicos

    declare -A volumeStructure

    mapfile -t rawPhysicalVolumes < <(
        pvs | awk -F' ' '{ print $1, " ", $2, " ", $5 }' \
        | sed -E "s|/dev/||g; s|<||g" | column -t -s ' ' -o ' '
    )

    mapfile -t rawVolumeGroups < <(
        vgs | awk -F' ' '{ print $1, " ", $6 }' | sed -E "s|#||g; s|<||g" \
        | column -t -s ' ' -o ' '
    )
    mapfile -t rawLogicalVolumes < <(
        lvs | awk -F' ' '{ print $1, " ", $2, " ", $4 }' | sed -E "s|<||g" \
        | column -t -s ' ' -o ' '
    )

    if [[ $code -eq 1 ]]; then
        printf "%s\n" "${rawPhysicalVolumes[@]}"
    fi

    if [[ $code -eq 2 ]]; then
        printf "%s\n" "${rawVolumeGroups[@]}"
    fi

    if [[ $code -eq 3 ]]; then
        printf "%s\n" "${rawLogicalVolumes[@]}"
    fi

    if [[ $code -eq 0 ]]; then

        printf "\n========PHYSICAL VOLUMES========\n"
        printf "%s\n" "${rawPhysicalVolumes[@]}"

        printf "\n========VOLUME GROUPS========\n"
        printf "%s\n" "${rawVolumeGroups[@]}"

        printf "\n========LOGICAL VOLUMES========\n"
        printf "%s\n" "${rawLogicalVolumes[@]}"
    fi

}

function snapshotViability(){

    mapfile -t vgs < <(fetchVolumes 2)
    mapfile -t lvs < <(fetchVolumes 3 | awk -F' ' '{ print $1, " ", $3 }')

    # printf "LV LV_SIZE VG VG_SIZE"
    printf "%s\n%s\n" "${lvs[@]:1}" "${vgs[@]:1}"

}
snapshotViability
# fetchVolume