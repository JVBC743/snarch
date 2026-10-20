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

    case $code in
        "--arrange")
            debug --print "[LVM]: FETCHING VOLUME GROUP(S)..."

            mapfile -t vgs < <(
                LVM_SUPPRESS_FD_WARNINGS=1 vgs | awk -F' ' 'NR != 1 { print $1, $6, $7 }' | tr -d '<'
            )

            debug --print "[LVM]: FETCHING LOGICAL VOLUME(S)..."

            mapfile -t lvs < <(
                LVM_SUPPRESS_FD_WARNINGS=1 lvs | awk -F' ' 'NR != 1 {
                    if ($6 == "") {
                        print $1, $2, $4
                    } 
                }' 
            )

            mapfile -t snaps < <(
                LVM_SUPPRESS_FD_WARNINGS=1 lvs | awk -F' ' 'NR != 1 {
                    if ($6 != "") {
                        print $1, $4, $6, $7
                    } 
                }' 
            )

            debug --print "[LVM]: REARRANGING VOLUMES..."

            counter=0

            for (( i=0; i<"${#lvs[@]}"; i++ )); do

                instance=$(printf "%s %s\n" "${lvs[i]}" "${snaps[i]}")
                
                IFS=' ' read -r lv vg_name lv_size snapshot_name snapshot_size snapshot_data <<< "$instance"

                LV[$counter]="$lv"

                ((counter++))

                LVM["$lv.vg_name"]="$vg_name"
                LVM["$lv.lv_size"]="$lv_size"
                LVM["$lv.snapshot_name"]="$snapshot_name"
                LVM["$lv.snapshot_size"]="$snapshot_size"
                LVM["$lv.snapshot_data"]="$snapshot_data"

                LVM["$lv.vg_size"]=$(
                    printf "%s\n" "${vgs[@]}" | grep ${LVM["$lv.vg_name"]} \
                    | awk -F' ' '{ print $2 }'
                )
                LVM["$lv.vg_free"]=$(
                    printf "%s\n" "${vgs[@]}" | grep ${LVM["$lv.vg_name"]} \
                    | awk -F' ' '{ print $3 }'
                )
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

    local viabilityForSnapshot
    local finalTable=""
    local vg_size=0
    local vg_free=0
    local twentyPercent=0
    sumBG=0
	
	declare -a completeTable
    
    debug --print "[LVM]: CALCULATING THE SNAPSHOT VIABILITY..."

    volume_groups=(`
        (
            for lv in "${LV[@]}"; do
                printf "%s\n" ${LVM["$lv.vg_name"]}
            done
        ) | sort -u
    `)

    lv_count=$(
        (   
            for lv in "${LV[@]}"; do
                printf "%s\n" ${LVM["$lv.vg_name"]}
            done
        ) | sort | uniq -c
    )

    for lv in "${LV[@]}"; do
        LVM["$lv.lv_per_vg"]=$(
            printf "%s\n" $lv_count \
            | grep ${LVM["$lv.vg_name"]} \
            | sed -E "s/ +$|^ +//g" \
            | awk -F' ' '{ print $1 }'
        )
    done

    local viability="POSSIBLE"

    for vg in ${volume_groups[@]}; do
        for lv in "${LV[@]}"; do
            [[ $vg == ${LVM["$lv.vg_name"]} ]] && {

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

                vg_size=$(echo ${LVM["$lv.vg_size"]} | tr -d 'g')
                vg_free=$(echo ${LVM["$lv.vg_free"]} | tr -d 'g')

                twentyPercent=$(printf "%.2f" $(echo "$vg_size * 0.20" | bc -l) )

                LVM["$lv.twenty_percent"]=$twentyPercent

                viabilityForSnapshot="IMPOSSIBLE"
                [[ $(echo "$vg_free > $twentyPercent" | bc -l) -eq 1 ]] \
                && viabilityForSnapshot="POSSIBLE"

                LVM["$lv.snapshot_viability"]=$viabilityForSnapshot

                [[ ${LVM["$lv.snapshot_viability"]} == "IMPOSSIBLE" ]] && {
                    viability="IMPOSSIBLE"
                }
            }

        done

    done

    debug --print "[LVM]: SETTING THE SNAPSHOT VIABILITY FOR THE SYSTEM..."

    table=$(

        printf "VOLUME OCCUPIED_SIZE VG_SIZE VG_FREE MIN_FOR_SNAPSHOT SNAPSHOT_VIABILITY #%s\n" "$viability"

        for lv in "${LV[@]}"; do
            printf "%s %s %s %s %s %s\n" "$lv"\
            ${LVM["$lv.lv_size"]} \
            ${LVM["$lv.vg_size"]} \
            ${LVM["$lv.vg_free"]} \
            ${LVM["$lv.twenty_percent"]} \
            ${LVM["$lv.snapshot_viability"]}
        done
    )

	debug --print "[LVM]: THE TABLE IS COMPLETED."

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

            for lv in ${LV[@]}; do

                vg=${LVM["$lv.vg_name"]}
                twenty_percent=${LVM["$lv.twenty_percent"]}
                lv_per_vg=${LVM["$lv.lv_per_vg"]}

                snapshot_size=$(printf "%.1fG" "$(bc -l <<< "scale=2; $twenty_percent / $lv_per_vg")")

                LVM_SUPPRESS_FD_WARNINGS=1 lvcreate -s -n "$snapshot_name-$vg-$lv" -L "$snapshot_size" /dev/$vg/$lv

                [[ $? -ne 0 ]] && {
                    printf "ERRORS HAVE OCCURRED TO THE CREATION OF THE SNAPSHOT VOLUME '%s'\n" "$snapshot_name-$vg-$lv"
                    return 127
                }
                debug --print "[LVM]: THE SNAPSHOT HAS BEEN CREATED WITH THE NAME: '$snapshot_name-$vg-$lv"

            done  

        ;;
        "--delete")
            [[ -z "$snapshot" ]] && {
                printf "YOU MUST PROVIDE A SPECIFIC SNAPSHOT NAME TO BE REMOVED.\n"
                return 127
            }

            printf "REMOVING THE SNAPSHOT '%s'...\n" "$snapshot"

            for lv in ${LV[@]}; do

                [[ ${LVM["$lv.snapshot_name"]} == "$snapshot" ]] && {
                    vg=${LVM["$lv.vg_name"]}
                    LVM_SUPPRESS_FD_WARNINGS=1 lvremove -f /dev/$vg/${LVM["$lv.snapshot_name"]}

                    [[ $? -ne 0 ]] && {
                        printf "ERRORS HAVE OCCURRED TO THE DELETION OF THE LOGICAL VOLUME '%s'\n" ${LVM["$lv.snapshot_name"]}
                        return 127
                    }

                    rm -f /dev/$vg/$snapshot
                    rm -f /dev/mapper/$snapshot

                    debug --print "[LVM]: THE SNAPSHOT '${LVM["$lv.snapshot_name"]}' HAS BEEN REMOVED."
                }
            done

        ;;
        "--rollback")

            printf "Executing rollback...\n"

            for lv in ${LV[@]}; do

                LVM_SUPPRESS_FD_WARNINGS=1 lvconvert --merge /dev/${LVM["$lv.vg_name"]}/${LVM["$lv.snapshot_name"]}

                [[ $? -ne 0 ]] && {
                    printf "ERRORS HAVE OCCURRED DURING THE ROLLBACK PROCESS OF THE SNAPSHOT: '%s'\n" ${LVM["$lv.snapshot_name"]}
                    return 127
                }
            done
        ;;
        *)
            printf "INVALID OPTION '$code' FOR THE 'SNAPSHOT MANAGEMENT' FUNCTION!!!\n"
        ;;
    esac

    return 0
}