#!/bin/bash
#
#
# update.sh

#Descobrir como lidar com as perguntas do pacman, tipo, "Você aceita essa atualizações? (S/n)"

function update(){

    pacman -Syu --noconfirm 2> error_temp.txt

    if [[ $? -ne 0 ]]; then

        printf "update:1:2" # PENSANDO NA DINÂMICA DOS ERROS, SE USO CÓDIGOS PERSONALIZADOS OU STRINGS INTEIRAS.
        exit

    else

        rm error_temp.txt
    fi
}

