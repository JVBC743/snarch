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

# debug(){

    
# }

verifyBinaries(){

    local path="/usr/bin"
    local notFound
    mapfile -t binaries < <(
        ls $path
    )

    declare -a notFound
    counter=0
    for b in ${binaries[@]}; do
        verification=$(ldd "$path/$b" 2> /dev/null)
        if grep -qi "not found" <<< $verification; then
            # printf "[DEBUG]: MISSING LIB FOR '%s' BINARY.\n" "$b"

            notFound[$counter]=$(
                printf "%s\n" "$b"
                ldd "$path/$b" | grep "not found"
            )
            ((counter++))
        fi
    done

    printf "%s\n" "${notFound[@]}"
}



: << 'LEMBRAR'
Lembrar que tem os caminhos:
/var/log/pacman.log
/var/cache/pacman/pkg
Preciso dar uma olhada neles depois.
/usr/bin *O MAIS IMPORTANTE*

LEMBRAR