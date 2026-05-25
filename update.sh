#!/bin/bash
#
#
# update.sh

#Descobrir como lidar com as perguntas do pacman, tipo, "Você aceita essa atualizações? (S/n)"

function update(){

    pacman -Syu --noconfirm 2> error_temp.txt

    if [[ $? -ne 0 ]]; then

        printf "An error has occured during the update, verify the 'error_temp.txt' file to see the details.\n"
        exit

    fi
}

