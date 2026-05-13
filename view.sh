#!/bin/bash

#VER SE VAI PRECISAR SER UM DAEMON

intro(){ 
    printf "=============#==================#=============\n"
    printf "============# Welcome to Snarch! #============\n"
    printf "=============#==================#=============\n"
}

choose(){

    printf "\nWhat operation you need to be done?\n\n"
    printf "[1]: Just automate already\n[2]: Show me the volumes\n[3]: Take a snapshot\n[4]: Verify snapshot viability\n"
    printf "\n[ENTER]: default [1]\n\nYour choice: "

    read option

    if [[ -z $option ]]; then
        option="1"
    elif (( $option > 4 || $option < 1 )); then
        printf "\nINVALID OPTION!\n"
        exit
    fi

}


