#!/bin/bash
#
#
# lvm.sh

OLD="$IFS"
IFS=$'\n'

function fetchVolumes() {

    local code=$1
	local output=""

    declare -A volumeStructure

    debug --print "[LVM]: FETCHING PHYSICAL VOLUMES..."

    mapfile -t rawPhysicalVolumes < <(
        LVM_SUPPRESS_FD_WARNINGS=1 pvs | awk -F' ' '{ print $1, $2, $5, $6 }' \
        | sed -E "s|/dev/||g; s|<||g"
    )
    debug --print "[LVM]: FETCHING VOLUME GROUP(S)..."

    mapfile -t rawVolumeGroups < <(
        LVM_SUPPRESS_FD_WARNINGS=1 vgs | awk -F' ' '{ print $1, $6, $7 }' | sed -E "s|#||g; s|<||g" 
    )
    
    debug --print "[LVM]: FETCHING LOGICAL VOLUME(S)..."

    mapfile -t rawLogicalVolumes < <(
        LVM_SUPPRESS_FD_WARNINGS=1 lvs | awk -F' ' '{ print $1, $2, $4 }' | sed -E "s|<||g" 
    )

    if [[ -z ${rawPhysicalVolumes[@]} || -z ${rawVolumeGroups[@]} || -z ${rawLogicalVolumes[@]} ]]; then
        printf "test\n"
        exit
    fi
    debug --print "[LVM]: REARRANGING VOLUMES..."
    sleep 1
    debug --print "[LVM]: THE CODE CHOOSEN IS $code"

    case $code in
        "1")
            output="${rawPhysicalVolumes[*]}"
            ;;
        "2")
            output="${rawVolumeGroups[*]}"
            VName=(`printf "%s\n" "$output" | awk -F' ' '{ print $1 }'`)
            VSize=(`printf "%s\n" "$output" | awk -F' ' '{ print $2 }'`)
            VFree=(`printf "%s\n" "$output" | awk -F' ' '{ print $3 }'`)

            for ((i=0;i<"${#VSize[@]}";i++)); do

                # printf "%s %s\n" "${VSize[i]}" "${VFree[i]}"

                if grep -qi "m" <<< "${VFree[i]}"; then
                    nw=$(printf "%s\n" "${VFree[i]}" | sed -E 's/m|M//g')
                    calc=$( echo "$nw / 1024.0" | bc -l )
                    VFree[i]=$(printf "%.2fg\n" "$calc")

                fi
                if grep -qi "m" <<< "${VSize[i]}"; then
                    nw=$(printf "%s\n" "${VSize[i]}" | sed -E 's/m|M//g')
                    calc=$( echo "$nw / 1024.0" | bc -l )
                    VSize[i]=$(printf "%.2fg\n" "$calc")

                fi
                
                arr[i]=$(printf "%s %s %s\n" "${VName[i]}" "${VSize[i]}" "${VFree[i]}")

            done

            output=$(printf "%s\n" "${arr[@]}")
            
            ;;
        "3")
            output="${rawLogicalVolumes[*]}"
            ;;
        "0")
            output=$(cat <<- EOF
					
					${rawPhysicalVolumes[*]} 
					= + =
					${rawVolumeGroups[*]} 
					= + =
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
    
    debug --print "[LVM]: GETTING INPUTS..."

    local twentyPercent
    minimalForSnapshot=""
    local viabilityForSnapshot
    local sumLV=0
    sumVG=0
    local sumFreeVG=0
	
	declare -a temp
	declare -a completeTable
    debug --print "[LVM]: CREATING TABLE..."

    modelTable=$(
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

    local tmp=(`printf "%s\n" "$modelTable"`)
    modelTable=(`printf "%s\n" "${tmp[@]:1}"`)
	unset tmp

    debug --print "[LVM]: FETCHING VOLUMES' SIZE AND FREE SIZES..."

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

    debug --print "[LVM]: SUMMING..."

    
    for ((i=0; i<"${#lvSize[@]}"; i++)); do
        sumLV=$( echo "$sumLV + ${lvSize[i]}" | bc -l )
        
        if [[ ! -z ${vgSize[i]} ]]; then
            sumVG=$( echo "$sumVG + ${vgSize[i]}" | bc -l )
            sumFreeVG=$( echo "$sumFreeVG + ${vgFree[i]}" | bc -l )
        fi
        
    done 

    debug --print "[LVM]: GETTING THE 20% OF THE SUM..."

    twentyPercent=$(printf "%.2f" $(echo "$sumVG * 0.20" | bc -l) )
    debug --print "[LVM]: SUBTRACTING..."

    minimalForSnapshot=$(printf "%.2f" $(echo "$sumVG - $twentyPercent" | bc -l))
    debug --print "[LVM]: CREATING THE FIRST RAW TABLE..."

    tab=$(
        ( printf "%s\n" "${modelTable[@]}" |\
        	awk -F' ' '{ print $1, $2, $4, $5 }'
        ) 
    )

    debug --print "[LVM]: SETTING THE SNAPSHOT VIABILITY..."

    viabilityForSnapshot="POSSIBLE"

    [[ $(echo "$sumLV >= $minimalForSnapshot" | bc -l) -eq 1 ]] && viabilityForSnapshot="IMPOSSIBLE"

    debug --print "[LVM]: REARRAGING ALL GATHERED DATA..."

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
	debug --print "[LVM]: THE FINAL RAW TABLE IS COMPLETED."

	finalTable=$(
        printf "__ LV_SIZE VG_SIZE FREE_SIZE\n"
        printf "%s\n" "${output[@]}"
        printf "VIABILITY_FOR_SNAPSHOT\n%s\n" "$viabilityForSnapshot"

    )
	
    if grep -q "IMPOSSIBLE" <<< "$finalTable"; then
        return 10
    fi

    printf "%s\n" "$finalTable"

}

snapshotManagement(){

    local option=$1
    local snapshot_to_delete=$2

    biggerVG=$(printf "%s\n" "$(fetchVolumes 2)" | sort -nr \
    | awk -F' ' ' NR==1 { print $1 }')

    out=$(printf "%s\n" "$(fetchVolumes 3)" | grep "$biggerVG")

    local volume_name=(`printf "%s\n" "$out" | awk -F' ' '{ print $1 }'`)
    local volume_group=(`printf "%s\n" "$out"  | awk -F' ' '{ print $2 }'`)
    local path_1=""
    local path_2=""
    snapshot_name="snap_$TODAY"
    counter=0

    case $option in
        "--create")

            snapshotViability >/dev/null
            debug --print "[LVM]: TAKING SNAPSHOT..."

            snapshot_size=$( ( echo "( $sumVG - $minimalForSnapshot) / ${#volume_name[@]}" | bc -l ) ) #REFORMULAR LÓGICA PARA QUE O MÍNIMAL SEJA JÁ OS 20% PRA NÃO FAZER TODO ESSE CÁLCULO DE NOVO...
                                    
            for i in "${volume_name[@]}"; do
                lvcreate -s -n "$snapshot_name.$counter" -L "$snapshot_size"G /dev/$volume_group/$i
                ((counter++))
            done
        
            [[ $? -ne 0 ]] && {
                printf "ERRORS HAVE OCCURRED TO THE CREATION OF THE LOGICAL VOLUME '%s'\n" "$snapshot_name"
                return 127
            }
            counter=0
            for i in ${volume_name[@]}; do
                debug --print "[LVM]: SNAPSHOT HAS BEEN CREATED WITH THE NAME: '$snapshot_name.$counter'"
                printf "SNAPSHOT '%s' CREATED WITH THE SIZE OF %.2f\n" "$snapshot_name.$counter" "$snapshot_size"
                ((counter++))
            done

        ;;
        "--delete")

        #COLOCAR UM "FOR" AQUI PARA OS DIFERENTES LVS E VGS

            printf "REMOVING THE SNAPSHOT '%s'\n" "snap_$snapshot_to_delete"
            sleep 3

            if [[ -z "$snapshot_to_delete" ]]; then

                path_1="/dev/base/snap_*"
                path_2="/dev/mapper/base-snap*"

            else
                path_1="/dev/base/snap_$snapshot_to_delete"
                path_2="/dev/mapper/base-snap_$snapshot_to_delete"
                
            fi

            lvremove -f $path_1
            rm -f $path_1
            rm -f $path_2

            printf "SNAPSHOT SUCCESSFULLY REMOVED.\n"

        ;;
        "--rollback")

            printf "Executing rollback...\n"
            sleep 2
            [[ ${#volume_name[@]} -gt 1 ]] && {

                for i in ${#volume_name[@]}; do
                    LVM_SUPPRESS_FD_WARNINGS=1 lvconvert --merge /dev/$volume_group/$snapshot_name.$i
                done

                return 0
            }

            LVM_SUPPRESS_FD_WARNINGS=1 lvconvert --merge /dev/$volume_group/$snapshot_name

            [[ $? -ne 0 ]] && {
                printf "ERRORS HAVE OCCURRED DURING THE MERGE PROCESS OF THE LOGICAL VOLUME '%s'\n" "$snapshot_name"
                return 127
            }
        ;;
        *)
        ;;

    esac
}