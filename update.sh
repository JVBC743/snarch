#!/bin/bash
#
#
# update.sh

#Descobrir como lidar com as perguntas do pacman, tipo, "Você aceita essa atualizações? (S/n)"

function update(){

    pacman -Syu --noconfirm 2> error_temp.txt

    if [[ $? -ne 0 ]]; then

        printf "[UPDATE]: A ERROR HAS OCCURRED, VERIFY THE 'error_temp.txt' FILE FOR MORE DETAILS.\n"
        exit

    else

        rm error_temp.txt
    fi
}

