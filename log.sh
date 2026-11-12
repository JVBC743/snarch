#!/bin/bash
#
#
# log.sh

function verifyBinaries(){

    local path="/usr/bin"
    declare -a bins

    mapfile -t binaries < <(
        ls $path
    )
    
    counter=0
    check=""
    for b in ${binaries[@]}; do
        verification=$(ldd "$path/$b" 2> /dev/null)
        if grep -qi "not found" <<< $verification; then
            debug --print "[LOG]: LIB NOT FOUND FOR $b"

            bins[$counter]=$(
                important_ones=$(
                    pactree -lr $(pacman -Qo /usr/bin/$b 2>/dev/null | awk '{print $5}' ) | sort -u
                )
                if grep -Eiq "systemd|linux|base|init|glibc|bash|sh|util-linux|^pacman|crypto|coreutils" \
                <<< $important_ones; then
                    check="[IMPORTANT]:"
                
                elif grep -Eiq "bc|sed|lvm2|archlinux-keyring|nftables" <<< $important_ones; then
                    check="[ATTENTION]:"
                else
                    check="[ WARNING ]:"
                fi
                printf "%s %s => " "$check" "$b"
                printf "%s\n" "$verification" | grep "not found" \
                    | awk -F' ' '{ 
                        if (bins == "") 
                            bins = $1
                        else 
                            bins = bins ", " $1
                    } END {
                        print bins
                    }'
            )
            ((counter++))
            check=""
        fi
    done

    [[ -z "${bins[@]}" ]] && {
        printf "NO PROBLEMS HAVE BEEN FOUND IN THE SYSTEM'S BINARIES.\n"
        return 11
    }

	printf "THESE BINARY FILES HAVE BEEN FOUND WITH MISSIING LIBRARIES:\n"
	printf "%s\n" "${bins[@]}"
}

function verifyPacman(){

    pacs=$(grep -aEi "warning:|error:" /var/log/pacman.log | grep -a "$TODAY")

    [[ -z $pacs ]] && {
        printf "NO PROBLEMS HAVE BEEN FOUND IN PACMAN LOG FILE.\n"
        return 11
    }

    printf "%s\n" "$pacs"
}

function verifyJournal(){

    local begin=$1
    local final=$2

    jours=$(
        journalctl --since "$begin" --until "$final" | grep -Ei "missing|not found|failed|warning"
    )

    [[ -z $jours ]] && {
        printf "NO PROBLEMS HAVE BEEN FOUND IN JOURNALCTL FILES.\n"
        return 11
    }

    printf "%s\n" "$jours"
}
