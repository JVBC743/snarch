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

                if grep -Eiq "archlinux-keyring|systemd|^pacman|base|linux|bc|coreutils|gcc-libs|gnuutils|grub|lvm2|nftables" \
                <<< $important_ones; then
                    printf "%s [IMPORTANT]\n" "$b"

                else
                    printf "%s\n" "$b"

                fi
                
                ldd "$path/$b" | grep "not found" \
                | tr -d "=> not found" | sed "s/	/ /g"
            )
            ((counter++))
            
        fi
    done

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
    pacs=$(grep -Ei "warning|error" /var/log/pacman.log | grep "$today")

    [[ -z $pacs ]] && {
        printf "NO PROBLEMS HAVE BEEN FOUND IN PACMAN LOG FILE.\n"
        return 10
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
        printf "NO PROBLEMS HAVE BEEN FOUND IN JOURNALCTL LOG FILE.\n"
        return 10
    }

    printf "%s\n" "$jours"
}

function verifyGraphicalDriver(){

    debug --print "[LOG]: SEARCHING FOR GRAPHICAL DRIVERS IN THIS DEVICE..."

}
