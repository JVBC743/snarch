#!/bin/bash
#
#
# lvm.sh

IFS=$'\n'

function fetchVolumes() {

    local code=$1
	local output=""

    # Os códigos passados como parâmetros são para coletar individualmente...

    # 0) Informações de todos os volumes
    # 1) informações dos volumes físicos
    # 2) informações dos grupos de volumes
    # 3) informações dos volumes lógicos

    declare -A volumeStructure

    mapfile -t rawPhysicalVolumes < <(
        pvs | awk -F' ' '{ print $1, $2, $5, $6 }' \
        | sed -E "s|/dev/||g; s|<||g" | column -t -s ' ' -o ' '
    )

    mapfile -t rawVolumeGroups < <(
        vgs | awk -F' ' '{ print $1, $6, $7 }' | sed -E "s|#||g; s|<||g" \
        | column -t -s ' ' -o ' '
    )
    mapfile -t rawLogicalVolumes < <(
        lvs | awk -F' ' '{ print $1, $2, $4 }' | sed -E "s|<||g" \
        | column -t -s ' ' -o ' '
    )

    case $code in
        "1")
            output="${rawPhysicalVolumes[*]}"
            ;;
        "2")
            output="${rawVolumeGroups[*]}"
            ;;
        "3")
            output="${rawLogicalVolumes[*]}"
            ;;
        "0")
            output=$(cat <<- EOF
					Currently, these are the volumes created in this system:
					========PHYSICAL VOLUMES========
					${rawPhysicalVolumes[*]}
					========VOLUME GROUPS========
					${rawVolumeGroups[*]}
					========LOGICAL VOLUMES========
					${rawLogicalVolumes[*]}
				EOF
            )
            ;;
        *)
            output="INVALID CODE!\n"
            ;;
    esac

    printf "%s\n" "$output"

}

function snapshotViability(){

    declare -a twentyPercent
    declare -a minimalForSnapshot
    declare -a viabilityForSnapshot

    mapfile -t vgs < <(
        fetchVolumes 2 | awk -F' ' '{ print $1, $2, $3 }'
    )
    mapfile -t lvs < <(
        fetchVolumes 3 | awk -F' ' '{ print $1, $3, $2 }'
    )

    table=$((
        
        printf "LV LV_SIZE VG VG_SIZE VG_FREE\n"

        for ((i=1; i<"${#vgs[@]}"; i++)); do    
            for ((j=1; j<"${#lvs[@]}"; j++)); do
                if grep -Eiq $(printf "%s\n" "${vgs[i]}" \
                | awk -F ' ' '{ print $1 }') <<< "${lvs[j]}"; then
                    printf "%s %s\n" "${lvs[j]}" $(printf "%s\n" "${vgs[i]}" \
                    | awk -F ' ' '{ print $2, $3 }') 
                fi
            done
        done 
        
        ) | column -t -s ' ' -o ' '
    )

    #REALIZAR VALIDAÇÃO DE MegaBytes TAMBÉM

    mapfile -t lvSize < <(
        printf "%s\n" "$table" | awk -F ' ' '{ print $2 }' | tr -d "g"
    )
    mapfile -t vgSize < <(
        printf "%s\n" "$table" | awk -F ' ' '{ print $4 }' | tr -d "g"
    )
    mapfile -t vgFree < <(
        printf "%s\n" "$table" | awk -F ' ' '{ print $5 }' 
    )
    
    for ((i=1; i<"${#lvs[@]}"; i++)); do

        twentyPercent[i]=$(printf "%.2f" $(echo "${vgSize[i]} * 0.20" | bc -l) )
        minimalForSnapshot[i]=$(printf "%.2f" $(echo "${vgSize[i]} - ${twentyPercent[i]}" | bc -l))

        # SIMBOLOS: NO e YES
        # YES = O tamanho do VG ocupado não ultrapassa o tamanho mínimo do VG para o snapshot.
        # NO = O tamanho do VG ocupado ultrapassa o tamanho mínimo do VG para o snapshot.

        viabilityForSnapshot[i]="YES"

        [[ $(echo "${vgSize[i]} >= ${minimalForSnapshot[i]}" | bc -l) -eq 1 ]] && viabilityForSnapshot[i]="NO"

        snapshotSummary[i]=$(
            printf "%sgb %sgb %sgb %sgb %s\n" \
            ${lvSize[i]} ${vgSize[i]} ${vgFree[i]} ${minimalForSnapshot[i]} ${viabilityForSnapshot[i]}
        )

    done 

    (printf "LV_OCCUPIED_SIZE VG_OCCUPIED_SIZE FREE_SIZE MINIMAL_FOR_SNAPSHOT VIABILITY_FOR_SNAPSHOT\n"
    printf "%s\n" ${snapshotSummary[@]}) | column -t -s ' ' -o ' '
    
}