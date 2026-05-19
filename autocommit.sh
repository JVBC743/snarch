#!/bin/bash
#
#
# autocommit.sh

printf "#######################################################################\n"
printf "Lembrou de trocar a versão do sistema na função de intro da VIEW? (s/n)\n"
printf "#######################################################################\n"

read resp

if [[ $resp != "s" ]]; then

    printf "Parando...\n\n"
    exit

fi

printf "Digite a sua mensagem para o commit abaixo:\n\n"
read commit 

git add . && git commit -m "$commit"