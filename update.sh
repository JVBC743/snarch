#!/bin/bash
#
#
# update.sh

#Descobrir como lidar com as perguntas do pacman, tipo, "Você aceita essa atualizações? (S/n)"

function update(){

    pacman -Syu 2> error_temp.txt
}

