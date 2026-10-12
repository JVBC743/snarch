#!/bin/bash
#
#
# lvm.sh

OLD="$IFS"
IFS=$'\n'

function findEFI() {

    lsblk -lo NAME,FSTYPE,MOUNTPOINTS | grep -E "vfat|fat32|boot|efi" |\
    awk -F ' ' '{ print $3 }'
    
    return 0
}

function fetchVolumes() {

    local code=$1
    local fromController=$2
	local output=""

    # debug --print "[LVM]: FETCHING PHYSICAL VOLUMES..."

    # mapfile -t pvs < <(
    #     pvs | awk -F' ' 'NR != 1 { print $1, $2, $5, $6 }' 
    # )

    [[ "$code" == "--init" ]] && {

        #PONDERAR SE A CONTAGEM DE VOLUMES LÓGICOS DEVE JÁ SER FEITA AQUI ANTES DO SNAPSHOT MANAGEMENT.

        debug --print "[LVM]: FETCHING VOLUME GROUP(S)..."

        mapfile -t vgs < <(
            vgs | awk -F' ' 'NR != 1 { print $1, $6, $7 }' | tr -d '<'
        )

        debug --print "[LVM]: FETCHING LOGICAL VOLUME(S)..."

        mapfile -t lvs < <(
            lvs | awk -F' ' 'NR != 1 { print $1, $2, $4, $6 }' 
        )

        debug --print "[LVM]: REARRANGING VOLUMES..."

        counter=0

        for instance in "${lvs[@]}"; do

            IFS=' ' read -r lv vg_name lv_size <<< "$instance"
            LV[$counter]="$lv"
            ((counter++))

            LVM["$lv.vg_name"]="$vg_name"
            LVM["$lv.lv_size"]="$lv_size"

            LVM["$lv.vg_size"]=$(
                printf "%s\n" "${vgs[@]}" | grep ${LVM["$lv.vg_name"]} \
                | awk -F' ' '{ print $2 }'
            )
            LVM["$lv.vg_free"]=$(
                printf "%s\n" "${vgs[@]}" | grep ${LVM["$lv.vg_name"]} \
                | awk -F' ' '{ print $3 }'
            )
        done

        return 0
    }

    case $code in
        "--group")

            for lv in "${LV[@]}"; do

                if grep -qi "m" <<< ${LVM["$lv.vg_free"]}; then
                    nw=$(printf "%s\n" ${LVM["$lv.vg_free"]} | sed -E 's/m|M//g')
                    calc=$( echo "$nw / 1024.0" | bc -l )
                    LVM["$lv.vg_free"]=$(printf "%.2fg\n" "$calc")
                fi
                if grep -qi "m" <<< ${LVM["$lv.vg_size"]}; then
                    nw=$(printf "%s\n" ${LVM["$lv.vg_size"]} | sed -E 's/m|M//g')
                    calc=$( echo "$nw / 1024.0" | bc -l )
                    LVM["$lv.vg_size"]=$(printf "%.2fg\n" "$calc")
                fi

                printf "VG %s %s %s\n" ${LVM["$lv.vg_name"]} ${LVM["$lv.vg_size"]} ${LVM["$lv.vg_free"]}
            done
        ;;
        "--logical")
			for lv in "${LV[@]}"; do
				printf "LV %s %s\n" "$lv" ${LVM["$lv.lv_size"]} 
			done

        ;;
        "--all")
            printf "LV_NAME LV_SIZE VG_NAME VG_SIZE VG_FREE_SIZE\n"
			for lv in "${LV[@]}"; do
				printf "%s %s %s %s %s\n" "$lv" ${LVM["$lv.lv_size"]} ${LVM["$lv.vg_name"]} ${LVM["$lv.vg_size"]} ${LVM["$lv.vg_free"]}
			done
        ;;
        *)
            printf "INVALID CODE '%s'!\n" "$code"
        ;;
    esac

    return 0

}

function snapshotViability(){

    local twentyPercent
    local viabilityForSnapshot
    local finalTable=""
    sumBG=0
	
	declare -a completeTable

    debug --print "[LVM]: INITIATING THE CALCULATIONS..."

    modelTable=(`
        fetchVolumes --all
    `)

    debug --print "[LVM]: FETCHING VOLUMES' SIZE AND FREE SIZES..."

    mapfile -t lvSize < <(
        printf "%s\n" "${modelTable[@]:1}" | awk -F ' ' '{ print $2 }' | tr -d "g"
    )
    mapfile -t vgSize < <(
        printf "%s\n" "${modelTable[@]:1}" | awk -F ' ' '{ print $4 }' | tr -d "g" \
        | uniq
    )
    mapfile -t vgFree < <(
        printf "%s\n" "${modelTable[@]:1}" | awk -F ' ' '{ print $5 }' | tr -d "g" \
        | uniq
    )

    debug --print "[LVM]: CREATING THE PRE TABLE..."

    preTable=(`
        printf "%s\n" "${modelTable[@]:1}" |\
        awk -F' ' '{ print $1, $2, $4, $5 }'
    `)
    debug --print "[LVM]: GETTING THE 20% OF THE SUM..."
    for ((i=0; i<"${#lvSize[@]}"; i++)); do
        sumLV[i]=$( echo "${sumLV[i]:-0} + ${lvSize[i]}" | bc -l )

        if [[ ! -z ${vgSize[i]} ]]; then
            sumVG[i]=$( echo "${sumVG[i]:-0} + ${vgSize[i]}" | bc -l )
            sumFreeVG[i]=$( echo "${sumFreeVG[i]:-0} + ${vgFree[i]}" | bc -l )
        fi

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

        tab[i]=$(printf "%s %sg %s\n" "${preTable[i]}" "${twentyPercent[i]}" "${viabilityForSnapshot[i]}")

    done

    debug --print "[LVM]: SETTING THE SNAPSHOT VIABILITY..."

	local viability="POSSIBLE"

    mid=$(
        for i in "${tab[@]}"; do
            printf "%s\n" "$i" | sed -E "s/ +$|^ +//g"
        done
    )

    table=$(
		if grep -qi "IMPOSSIBLE" <<< "${table[@]}"; then
			viability="IMPOSSIBLE"
		fi
		printf "VOLUME OCCUPIED_SIZE VG_SIZE VG_FREE MIN_FOR_SNAPSHOT SNAPSHOT_VIABILITY #%s\n%s\n" "$viability" "$mid"
	)

	debug --print "[LVM]: THE FINAL TABLE IS COMPLETED."

    if grep -q "IMPOSSIBLE" <<< "$table"; then
        printf "%s\n" "$table" 
        return 10
    fi
    
    printf "%s\n" "$table"
}

function snapshotManagement(){

    local code=$1
    local snapshot=$2
    declare -a snapColumns
    local path_1=""
    local path_2=""
    local snapshot_name="snap_$NOW"
    local lv_count=0
    local vg_size=0
    local snapshot_size=0

    case $code in
        "--create")

            debug --print "[LVM]: TAKING SNAPSHOT..."            

            volume_groups=(`
                (
                    for lv in "${LV[@]}"; do
                        printf "%s\n" ${LVM["$lv.vg_name"]}
                    done
                ) | sort -u
            `)

            for vg in ${volume_groups[@]}; do
                for lv in "${LV[@]}"; do
                    [[ $vg == ${LVM["$lv.vg_name"]} ]] && {
                        ((lv_count++))
                        vg_size=$(echo ${LVM["$lv.vg_size"]} | tr -d 'g')
                    }
                done
                #IDEIA: JOGAR ESSE CÁLCULO PARA A FUNÇÃO snapshotViability PRA EVITAR DE CRIAR OS 20% SÓ AQUI
                debug --print "[LVM]: TAKING 20% OF $vg_size FROM $vg..."            

                LVM["$vg.snapshot_size"]=$(printf "%.1fG" "$(bc -l <<< "scale=2; ($vg_size * 0.20) / $lv_count")")
                lv_count=0
            done
            debug --print "[LVM]: CREATING SNAPSHOT..."            

            for lv in "${LV[@]}"; do

                vg=${LVM["$lv.vg_name"]}
                snapshot_size=${LVM["$vg.snapshot_size"]}

                LVM_SUPPRESS_FD_WARNINGS=1 lvcreate -s -n "$snapshot_name-$vg-$lv" -L "$snapshot_size" /dev/$vg/$lv
                debug --print "[LVM]: THE SNAPSHOT '$snapshot_name-$vg-$lv' HAS BEEN CREATED WITH THE SIZE OF $snapshot_size..."            

                [[ $? -ne 0 ]] && {
                    printf "ERRORS HAVE OCCURRED TO THE CREATION OF THE LOGICAL VOLUME '%s'\n" "$snapshot_name-$i"
                    return 127
                }
                debug --print "[LVM]: THE SNAPSHOT HAS BEEN CREATED WITH THE NAME: '$snapshot_name-$i'"
            done
            return 1
        ;;
        "--delete")
            [[ -z "$snapshot" ]] && {
                printf "YOU MUST PROVIDE A SPECIFIC SNAPSHOT NAME TO BE REMOVED.\n"
                return 127
            }
            
            printf "REMOVING THE SNAPSHOT '%s'\n" "snap_$specific_snapshot"
            sleep 1

            for i in ${volume_group[@]:1}; do
                instance=$(printf "%s\n" "$i" | awk -F' ' '{ print $1 }')
                if [[ -z "$specific_snapshot" ]]; then
                    path_1="/dev/$instance/snap_*"
                    path_2="/dev/mapper/$instance-snap_*"
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

            snaps=(`fetchVolumes "--logical" | grep "$snapshot_name*" | awk -F' ' '{ print $1, $2 }'`)
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

            snapColumns="NAME GROUP SIZE USAGE"
            
            snappers=(`fetchVolumes "--logical" | grep "^snap_"`)

			data=$(
				printf "%s\n" "$snapColumns"
				printf "%s\n" "${snappers[@]}" | awk -F' ' '{ $4 = ""$4"%" ; print }'
			)

            printf "%s\n" "$data" 
        ;;
        *)
            printf "INVALID OPTION '$code' FOR THE 'SNAPSHOT MANAGEMENT' FUNCTION!!!\n"
        ;;
    esac

    return 0
}