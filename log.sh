#!/bin/bash
#
#
# log.sh

# verifyLog(){
#     grep -qi "error:" error_temp.txt && { \
#         printf "error output file found!\n";\
#         exit;
#     }
#     #SE ELE ENCONTRAR ERRO, MOSTRE AO USUÁRIO.
# }

verifyBinaries(){

    local path="/usr/bin"
    declare -a binary

    mapfile -t binaries < <(
        ls $path
    )
    counter=0
    for b in ${binaries[@]}; do
        verification=$(ldd "$path/$b" 2> /dev/null)
        if grep -qi "not found" <<< $verification; then	

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

: << 'LEMBRAR'
Lembrar que tem os caminhos:
/var/log/pacman.log
/var/cache/pacman/pkg
Preciso dar uma olhada neles depois.
/usr/bin *O MAIS IMPORTANTE*

LEMBRAR