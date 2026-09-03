#!/bin/bash
#
#
# log.sh

function verifyBinaries(){

    local path="/usr/bin"
    declare -a binary

    mapfile -t binaries < <(
        ls $path
    )
    counter=0
    for b in ${binaries[@]}; do
        verification=$(ldd "$path/$b" 2> /dev/null)
        if grep -qi "not found" <<< $verification; then	

            debug --print "[LOG]: LIB NOT FOUND FOR $b"

            libs[$counter]=$(

                important_ones=$(
                    pactree -lr $(pacman -Qo /usr/bin/$b 2>/dev/null | awk '{print $5}' ) | sort -u
                )

                if grep -Eiq "systemd|linux|base|init|glibc|bash|sh|util-linux|^pacman|crypto|coreutils" \
                <<< $important_ones; then
                    printf "%s [IMPORTANT]\n" "$b"
                
                elif grep -Eiq "bc|sed|lvm2|archlinux-keyring|nftables" <<< $important_ones; then
                    printf "%s [ATTENTION]\n" "$b"
                fi
                
                ldd "$path/$b" | grep "not found" \
                | tr -d "=> not found" | sed "s/	/ /g"
            )
            ((counter++))
        fi
    done

    [[ -z "${bins[@]}" ]] && {
        printf "NO PROBLEMS HAVE BEEN FOUND IN THE SYSTEM'S BINARIES.\n"
        return 11
    }
    [[ -n "${bins[@]}" ]] && {
        printf "SNARCH HAS DETECTED IRREGULAR FILES IN THE SYSTEM'S BINARIES.\n"
        PERFECTION=0
    }
    
	mapfile -t bins < <(
		(
			for ((i=0;i<$counter;i++)); do
				printf "%s " "${libs[i]}" | tr -d "\n"
				echo -e "\n"
			done
		) | sed -e '/^$/d' -e 's/^ \+//' \
		| column -t -s ' ' -o ' '
	)
	printf "THESE BINARY FILES HAVE BEEN FOUND WITH MISSIING LIBRARIES:\n"
	printf "%s\n" "${bins[@]}"     
}

function verifyPacman(){

    pacs=$(grep -aEi "warning|error" /var/log/pacman.log | grep -a "$TODAY")

    [[ -z $pacs ]] && {
        printf "NO PROBLEMS HAVE BEEN FOUND IN PACMAN LOG FILE.\n"
        return 11
    }
    [[ -n $pacs ]] && {
        printf "SNARCH FOUNDED WARNING OR ERROR LINES IN PACMAN LOG FILES.\n"
        PERFECTION=0
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

    [[ -n $jours ]] && {
        printf "SNARCH FOUNDED WARNING OR ERROR LINES IN JOURNALCTL LOG FILES.\n"
        PERFECTION=0
    }

    printf "%s\n" "$jours"
}
