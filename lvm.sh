#!/bin/bash
#
#
# lvm.sh

OLD="$IFS"
IFS=$'\n'

function fetchVolumes() {

    local code=$1
    local fromController=$2
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
        LVM_SUPPRESS_FD_WARNINGS=1 lvs | awk -F' ' '{ print $1, $2, $4, $6 }' | sed -E "s|<||g"
    )


    if [[ -z ${rawPhysicalVolumes[@]} || -z ${rawVolumeGroups[@]} || -z ${rawLogicalVolumes[@]} ]]; then
        printf "test\n"
        exit
    fi
    debug --print "[LVM]: REARRANGING VOLUMES..."
    sleep 0.5
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
            rawLogicalVolumes=(`
                printf "%s\n" "${rawLogicalVolumes[@]}" | awk -F' ' '{ print $1, $2, $3 }'
            `)

            output=$(cat <<- EOF
					PHYSICAL_VOLUME(S)
					${rawPhysicalVolumes[*]}
					VOLUME_GROUP(S)
					${rawVolumeGroups[*]}
					LOGICAL_VOLUME(S)
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
    local viabilityForSnapshot
    local finalTable=""
    sumBG=0
	
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

    tab=(`
        printf "%s\n" "${modelTable[@]}" |\
        awk -F' ' '{ print $1, $2, $4, $5 }'
    `)

    for ((i=0; i<"${#lvSize[@]}"; i++)); do
        sumLV[i]=$( echo "${sumLV[i]:-0} + ${lvSize[i]}" | bc -l )

        if [[ ! -z ${vgSize[i]} ]]; then
            sumVG[i]=$( echo "${sumVG[i]:-0} + ${vgSize[i]}" | bc -l )
            sumFreeVG[i]=$( echo "${sumFreeVG[i]:-0} + ${vgFree[i]}" | bc -l )
        fi

        debug --print "[LVM]: GETTING THE 20% OF THE SUM..."

        twentyPercent[i]=$(printf "%.2f" $(echo "${sumVG[i]:-0} * 0.20" | bc -l) )

        viabilityForSnapshot[i]="IMPOSSIBLE"

        [[ $(echo "${sumFreeVG[i]:-0} > ${twentyPercent[i]}" | bc -l) -eq 1 ]] \
        && viabilityForSnapshot[i]="POSSIBLE"

        if [[ -z ${sumVG[i]} ]]; then

            twentyPercent[i]=$(printf "%.2f" $(echo "${sumVG[i-1]} * 0.20" | bc -l) )

            viabilityForSnapshot[i]="IMPOSSIBLE"

            [[ $(echo "${sumFreeVG[i-1]} > ${twentyPercent[i]}" | bc -l) -eq 1 ]] \
            && viabilityForSnapshot[i]="POSSIBLE"

        fi

        debug --print "[LVM]: SETTING THE SNAPSHOT VIABILITY..."

        table[i]=$(printf "%s %sg %s\n" "${tab[i]}" "${twentyPercent[i]}" "${viabilityForSnapshot[i]}")

    done

	local viability=""

    table=$(


		if grep -qi "IMPOSSIBLE" <<< "${table[@]}"; then
			viability=" #IMPOSSIBLE"
		else
			viability=" #POSSIBLE"
		fi
		printf "+VOLUME +OCCUPIED_SIZE +VG_SIZE +VG_FREE +MIN_FOR_SNAPSHOT +SNAPSHOT_VIABILITY %s\n" "$viability"
        printf "%s\n" "${table[@]}"
	)

	debug --print "[LVM]: THE FINAL TABLE IS COMPLETED."


    if grep -q "IMPOSSIBLE" <<< "$table"; then
        printf "%s\n" "$table" 
        return 10
    fi
    
    printf "%s\n" "$table"

	

}

function snapshotManagement(){

    local option=$1
    local specific_snapshot=$2
    declare -a snapColumns


    local volume_group=(`fetchVolumes 2 | awk -F' ' '{ print $1, $2 }'`)
    
    mapfile -t volume_name < <(fetchVolumes 3 | awk -F' ' '{ 
            if ($4 == "") {
                print $1, $2, $3
            }
        }'
    )

    local path_1=""
    local path_2=""
    snapshot_name="snap_$NOW"

    case $option in
        "--create")

            snapshotViability >/dev/null
            debug --print "[LVM]: TAKING SNAPSHOT..."            

            for vg in "${volume_group[@]:1}"; do
                
                vg_instance=$(printf "%s\n" "$vg" | awk -F' ' '{ print $1 }')
                vg_size_instance=$(printf "%s\n" "$vg" | awk -F' ' '{ print $2 }' | tr -d 'g')

                lv_count=$(printf "%s\n" "${volume_name[@]}" | grep "$vg_instance" | wc -l)
                lv_name=(`printf "%s\n" "${volume_name[@]}" | grep "$vg_instance" \
                    | awk -F' ' '{ print $1 }'
                `)

                snapshot_size=$( echo "( $vg_size_instance * 0.20 ) / $lv_count" | bc -l )
                snapshot_size=$(printf "%.2fG\n" "$snapshot_size")

                for i in ${lv_name[@]}; do
                    LVM_SUPPRESS_FD_WARNINGS=1 lvcreate -s -n "$snapshot_name-$i" -L "$snapshot_size" /dev/$vg_instance/$i

                    [[ $? -ne 0 ]] && {
                        printf "ERRORS HAVE OCCURRED TO THE CREATION OF THE LOGICAL VOLUME '%s'\n" "$snapshot_name-$i"
                        return 127
                    }
                    debug --print "[LVM]: THE SNAPSHOT HAS BEEN CREATED WITH THE NAME: '$snapshot_name-$i'"
                    printf "SNAPSHOT '%s' CREATED WITH THE SIZE OF %s\n" "$snapshot_name-$i" "$snapshot_size"
                done
            done
        ;;
        "--delete")

            printf "REMOVING THE SNAPSHOT '%s'\n" "snap_$specific_snapshot"
            sleep 1

            for i in ${volume_group[@]:1}; do
                instance=$(printf "%s\n" "$i" | awk -F' ' '{ print $1 }')
                if [[ -z "$specific_snapshot" ]]; then
                    path_1="/dev/$instance/snap_*"
                    path_2="/dev/mapper/$instance-snap*"
                else
                    path_1="/dev/$instance/snap_$specific_snapshot"
                    path_2="/dev/mapper/$instance-snap_$specific_snapshot"                    
                fi

                LVM_SUPPRESS_FD_WARNINGS=1 lvremove -f $path_1
                rm -f $path_1
                rm -f $path_2

                [[ $? -ne 0 ]] && {
                    printf "ERRORS HAVE OCCURRED TO THE CREATION OF THE LOGICAL VOLUME '%s'\n" "$snapshot_name-$i"
                    return 127
                }

                printf "SNAPSHOT '$specific_snapshot' SUCCESSFULLY REMOVED.\n"

            done

        ;;
        "--rollback")

            printf "Executing rollback...\n"
            sleep 3

            [[ -n $specific_snapshot ]] && {
                snapshot_name=$specific_snapshot
            }

            snaps=(`fetchVolumes 3 | grep "$snapshot_name*" | awk -F' ' '{ print $1, $2 }'`)
            for i in ${snaps[@]}; do

                local snapshot=$(printf "%s\n" "$i" | awk -F' ' '{ print $1 }')
                local group=$(printf "%s\n" "$i" | awk -F' ' '{ print $2 }')

                LVM_SUPPRESS_FD_WARNINGS=1 lvconvert --merge /dev/$group/$snapshot

                [[ $? -ne 0 ]] && {
                    printf "ERRORS HAVE OCCURRED DURING THE ROLLBACK PROCESS OF THE SNAPSHOT: '%s'\n" "$snapshot"
                    return 127
                }
            done
        ;;
        "--gather")

            snapColumns=(
                "| NAME" "| ORIGIN" "| GROUP" "| SIZE" "| USAGE(%)"
            )

            snappers=(`fetchVolumes 3 | grep "snap*" | tr "-" " "`)

            formatedSnappers=(`
                for ((i=1;i<6; i++)); do
                    printf "%s\n" "${snappers[@]}" |\
                        awk -F' ' -v col="$i" '{ print $col " |" }' | tr "\n" " "
                    echo ""
                done
            `)

            data=$(
                for ((i=0;i<"${#formatedSnappers[@]}"; i++)); do
                    printf "%s : %s\n" "${snapColumns[i]}" "${formatedSnappers[i]}"
                done
            )

            printf "%s\n" "$data" 
        ;;
        *)
            printf "INVALID OPTION FOR THE 'SNAPSHOT MANAGEMENT' FUNCTION!!!\n"
        ;;
    esac

}