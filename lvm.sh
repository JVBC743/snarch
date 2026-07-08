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

    $DEBUG_PRINT "[LVM]: FETCHING PHYSICAL VOLUMES..."

    mapfile -t rawPhysicalVolumes < <(
        LVM_SUPPRESS_FD_WARNINGS=1 pvs | awk -F' ' '{ print $1, $2, $5, $6 }' \
        | sed -E "s|/dev/||g; s|<||g"
    )
    $DEBUG_PRINT "[LVM]: FETCHING VOLUME GROUP(S)..."

    mapfile -t rawVolumeGroups < <(
        LVM_SUPPRESS_FD_WARNINGS=1 vgs | awk -F' ' '{ print $1, $6, $7 }' | sed -E "s|#||g; s|<||g" 
    )
    
    $DEBUG_PRINT "[LVM]: FETCHING LOGICAL VOLUME(S)..."

    mapfile -t rawLogicalVolumes < <(
        LVM_SUPPRESS_FD_WARNINGS=1 lvs | awk -F' ' '{ print $1, $2, $4 }' | sed -E "s|<||g" 
    )

    if [[ -z ${rawPhysicalVolumes[@]} || -z ${rawVolumeGroups[@]} || -z ${rawLogicalVolumes[@]} ]]; then
        printf "test\n"
        exit
    fi
    $DEBUG_PRINT "[LVM]: REARRANGING VOLUMES..."
    sleep 1
    $DEBUG_PRINT "[LVM]: THE CODE CHOOSEN IS $code"

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

    vgs=(`fetchVolumes 2 | awk -F' ' '{ print $1, $2, $3 }'`)
    lvs=(`fetchVolumes 3 | awk -F' ' '{ print $1, $3, $2 }'`)
    
    $DEBUG_PRINT "[LVM]: GETTING INPUTS..."

    local twentyPercent
    minimalForSnapshot=""
    local viabilityForSnapshot
    local sumLV
    # local sumVG
    local sumFreeVG
	
	declare -a temp
	declare -a completeTable
    $DEBUG_PRINT "[LVM]: CREATING TABLE..."

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


    $DEBUG_PRINT "[LVM]: FETCHING VOLUMES' SIZE AND FREE SIZES..."

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

    $DEBUG_PRINT "[LVM]: SUMMING..."

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
    $DEBUG_PRINT "[LVM]: GETTING THE 20% OF THE SUM..."

    twentyPercent=$(printf "%.2f" $(echo "$sumVG * 0.20" | bc -l) )
    $DEBUG_PRINT "[LVM]: SUBTRACTING..."

    minimalForSnapshot=$(printf "%.2f" $(echo "$sumVG - $twentyPercent" | bc -l))
    $DEBUG_PRINT "[LVM]: CREATING THE FIRST RAW TABLE..."

    tab=$(
        ( printf "%s\n" "${modelTable[@]}" |\
        	awk -F' ' '{ print $1, $2, $4, $5 }'
        ) 
    )

    $DEBUG_PRINT "[LVM]: SETTING THE SNAPSHOT VIABILITY..."

    viabilityForSnapshot="POSSIBLE"

    [[ $(echo "$sumLV >= $minimalForSnapshot" | bc -l) -eq 1 ]] && viabilityForSnapshot="IMPOSSIBLE"

    $DEBUG_PRINT "[LVM]: REARRAGING ALL GATHERED DATA..."

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
	$DEBUG_PRINT "[LVM]: THE FINAL RAW TABLE IS COMPLETED."

	printf "__ LV_SIZE VG_SIZE FREE_SIZE\n"
	printf "%s\n" "${output[@]}"
    printf "VIABILITY_FOR_SNAPSHOT\n%s\n" "$viabilityForSnapshot"

}

takeSnapshot(){

    volume_name=$(fetchVolumes 3 | awk -F' ' ' NR==2 { print $1 }')
    volume_group=$(fetchVolumes 3 | awk -F' ' ' NR==2 { print $2 }')

    snapshotViability > /dev/null
    $DEBUG_PRINT "[LVM]: TAKING SNAPSHOT..."
    today=$(date +"%Y_%m_%d_%H.%M.%S")
    snapshot_name="snap_$today"
    snapshot_size=$( ( echo "$sumVG - $minimalForSnapshot" | bc -l ) ) #REFORMULAR LÓGICA PARA QUE O MÍNIMAL SEJA JÁ OS 20% PRA NÃO FAZER TODO ESSE CÁLCULO DE NOVO...

    lvcreate -s -n "$snapshot_name" -L "$snapshot_size"G /dev/$volume_group/$volume_name

    $DEBUG_PRINT "[LVM]: SNAPSHOT HAS BEEN CREATED WITH THE NAME: '$snapshot_name'"
    printf "SNAPSHOT '%s' CREATED WITH THE SIZE OF %s\n" "$snapshot_name" "$snapshot_size"

    
}
makeRollback(){

    printf "Executing rollback...\n"
    sleep 3
    lvconvert --merge /dev/$volume_group/$snapshot_name
}

deleteSnapshot(){

    printf "REMOVING THE LATEST SNAPSHOT...\n"
    sleep 3
    lvremove -f /dev/base/snap_*
    printf "SNAPSHOT SUCCESSFULLY REMOVED.\n"

}