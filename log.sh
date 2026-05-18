#!/bin/bash
#
#
# log.sh

grep -i "error:" error_temp.txt && { \
    printf "error output file not found!\n";\
    exit;
} #SE ELE ENCONTRAR ERRO, MOSTRE AO USUÁRIO.

: << 'LEMBRAR'

Lembrar que tem os caminhos:
/var/log/pacman.log
/var/cache/pacman/pkg

Preciso dar uma olhada neles depois.
LEMBRAR