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

    local twentyPercent
    local minimalForSnapshot
    local viabilityForSnapshot
    local sumLv

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
        printf "%s\n" "$table" | awk -F ' ' '{ print $5 }' | tr -d "g"
    )

    #considerando que só tenha apenas um VG, tem que considerar se tem mais de um.
    twentyPercent=$(printf "%.2f" $(echo "${vgSize[1]} * 0.20" | bc -l) )
    minimalForSnapshot=$(printf "%.2f" $(echo "${vgSize[1]} - $twentyPercent" | bc -l))

    sumLv=0

    for ((i=1; i<"${#lvSize[@]}"; i++)); do

        sumLv=$( echo "$sumLv + ${lvSize[i]}" | bc -l )
    done 

    tab=$(printf "%s\n" "${lvs[@]}" | awk -F' ' '{ print "│", $1, "│", $2, "│", $3, "│" }')

    lineWidth=$(echo "$tab" | wc -L)


    ceil=$(
        printf "┌"
        printf "%0.s─" $(seq 0 $(( $lineWidth - 3 )))
        printf "┐"
    )
    

    floor=$(
        printf "└"
        printf "%0.s─" $(seq 0 $(( $lineWidth - 3 )))
        printf "┘"
    )

    
    printf "%s\n" "$ceil"
    printf "%s\n" "$tab" | column -t -s'│' -o '│'
    printf "%s\n" "$floor"
    
    
    exit
    printf "├──────────────────────────────────────────────────────────────────────────────────────┤\n"


    viabilityForSnapshot="YES"

    [[ $(echo "$sumLv >= $minimalForSnapshot" | bc -l) -eq 1 ]] && viabilityForSnapshot="NO"

    

    printf "┌────────────────┬─────────┬───────────┬───────────────────────────────────────────────┐\n"

    (
        printf "│ LV_SIZE_SUMMED │ VG_SIZE │ FREE_SIZE │ MINIMAL_FOR_SNAPSHOT │ VIABILITY_FOR_SNAPSHOT │\n"
        printf "│ %sg │ %sg │ %sg │ %sg │ %s │\n" \
        "$sumLv" "${vgSize[1]}" "${vgFree[1]}" "$minimalForSnapshot" "$viabilityForSnapshot"\ 
    
    ) | column -t -s'│' -o '│'

    #printf "└──────────────────────────────────────────────────────────────────────────────────────┘\n"

    #┤ ├

}