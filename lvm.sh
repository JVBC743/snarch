#!/bin/bash
#
#
# lvm.sh

OLD="$IFS"
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
        | sed -E "s|/dev/||g; s|<||g"
    )

    mapfile -t rawVolumeGroups < <(
        vgs | awk -F' ' '{ print $1, $6, $7 }' | sed -E "s|#||g; s|<||g" \
    )
    mapfile -t rawLogicalVolumes < <(
        lvs | awk -F' ' '{ print $1, $2, $4 }' | sed -E "s|<||g" \
        
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
					
					${rawPhysicalVolumes[*]}+
					${rawVolumeGroups[*]}+
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
    local sumLV
    local sumVG
    local sumFreeVG
	
	declare -a temp
	declare -a completeTable

    mapfile -t vgs < <( # COLOCAR ELES COMO PARÂMETROS DA FUNÇÃO PARA QUE O CONTROLLER JOGUE ELES DENTRO DA FUNÇÃO
        fetchVolumes 2 | awk -F' ' '{ print $1, $2, $3 }'
    )
    mapfile -t lvs < <(
        fetchVolumes 3 | awk -F' ' '{ print $1, $3, $2 }'
    )

    modelTable=$((
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

        )
    )

    local tmp=(`printf "%s\n" "$modelTable"`)
    modelTable=(`printf "%s\n" "${tmp[@]:1}"`)
	unset tmp

    #REALIZAR VALIDAÇÃO DE MegaBytes TAMBÉM

    mapfile -t lvSize < <(
        printf "%s\n" "${modelTable[@]}" | awk -F ' ' '{ print $2 }' | tr -d "g"
    )
    mapfile -t vgSize < <(
        printf "%s\n" "${modelTable[@]}" | awk -F ' ' '{ print $3, $4 }' | tr -d "g" \
        | uniq | awk -F ' ' '{ print $2 }'
    )
    mapfile -t vgFree < <(
        printf "%s\n" "${modelTable[@]}" | awk -F ' ' '{ print $3, $5 }' | tr -d "g" \
        | uniq | awk -F ' ' '{ print $2 }'
    )


    sumLV=0
    sumVG=0
    sumFreeVG=0

    for ((i=0; i<"${#lvSize[@]}"; i++)); do
        sumLV=$( echo "$sumLV + ${lvSize[i]}" | bc -l )
        # printf "%s\n" "${vgSize[i]}"
        if [[ ! -z ${vgSize[i]} ]]; then
            sumVG=$( echo "$sumVG + ${vgSize[i]}" | bc -l )
            sumFreeVG=$( echo "$sumFreeVG + ${vgFree[i]}" | bc -l )
        fi
        
    done 

    twentyPercent=$(printf "%.2f" $(echo "$sumVG * 0.20" | bc -l) )
    minimalForSnapshot=$(printf "%.2f" $(echo "$sumVG - $twentyPercent" | bc -l))

    tab=$(
        ( printf "%s\n" "${modelTable[@]}" |\
        	awk -F' ' '{ print $1, $2, $4, $5 }'
        ) 
    )

    viabilityForSnapshot="POSSIBLE"

    [[ $(echo "$sumLV >= $minimalForSnapshot" | bc -l) -eq 1 ]] && viabilityForSnapshot="IMPOSSIBLE"

    mapfile -t table < <(
		printf "%s\n" "$tab" &&\
		printf "%s %s %s\n" "$sumLV" "$sumVG" "$sumFreeVG"
	)

	for ((i=0; i<"${#table[@]}"; i++)); do
		temp[i]="${table[i]}"
		(( $i == ${#table[@]} - 1 )) && temp[i]="TOTAL: ${table[i]}"
    done
	
	for ((i=0; i<=${#table[@]} + 1; i++)); do
	
		completeTable[i]="${temp[i]}"
		if (( $i == ${#table[@]} - 1 )); then
			completeTable[i]="--- --- --- ---"
		elif (( $i > ${#table[@]} )); then
			completeTable[i]="${temp[((${#table[@]} - 1))]}"
		fi
	done

	output=$(
		for ((i=0; i<${#completeTable[@]}; i++)); do
			if [[ -n "${completeTable[i]}" ]]; then
				printf "%s\n" "${completeTable[i]}"
			fi
		done
	)
	
	printf "__ LV_SIZE VG_SIZE FREE_SIZE\n"
	printf "%s\n" "${output[@]}"
    printf "VIABILITY_FOR_SNAPSHOT\n%s\n" "$viabilityForSnapshot"

}

snapshot(){

    $DEBUG_PRINT "[LOG]: TAKING SNAPSHOT..."
    sleep 3
    $DEBUG_PRINT "[LOG]: SNAPSHOT HAS BEEN CREATED WITH THE NAME: 'snapshot_name'"
}