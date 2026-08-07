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
                printf "%s\n" "$b"
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
	
	printf "%s\n" "${bins[@]}"     
}

function verifyPacman(){
    pacs=$(grep -Ei "warning|error" /var/log/pacman.log | grep "$today")

    printf "%s\n" "$pacs"
}
function verifyJournal(){
    # today=$(date +"%Y-%m-%d")
    jours=$(
        journalctl -q -b | grep -Ei "missing|not found|failed|warning"
    )

    printf "%s\n" "$jours"
}

function verifyGraphicalDriver(){

    debug --print "[LOG]: SEARCHING FOR GRAPHICAL DRIVERS IN THIS DEVICE..."

}
