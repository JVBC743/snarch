#!/bin/bash
#
#
# update.sh

#Descobrir como lidar com as perguntas do pacman, tipo, "Você aceita essa atualizações? (S/n)"

function update(){

    starting_time=$(date +"%H:%M:%S")
    updateOutput=$(pacman -Syu --noconfirm 2> error_temp.txt)
    ending_time=$(date +"%H:%M:%S")

    if [[ $? -ne 0 ]]; then
        printf "ERRORS HAVE BEEN FOUND.\n" # PENSANDO NA DINÂMICA DOS ERROS, SE USO CÓDIGOS PERSONALIZADOS OU STRINGS INTEIRAS.
        exit
    else
        rm error_temp.txt
    fi

    printf "STARTING TIME: %s\n%s\nENDING TIME: %s\n" "$starting_time" "$updateOutput" "$ending_time"
}

