#!/bin/bash
#
#
# update.sh

function verifyPendingUpdates(){
    
    pacman -Sy
    pacman -Qu | awk -F'->' '{ print $1, $2 }' |\
    column -t -s ' ' -o ' '
    

}

function update(){

    updateOutput=$(pacman -Syu --noconfirm)

    if [[ $? -ne 0 ]]; then
        printf "ERRORS HAVE BEEN FOUND.\n"
    elif grep -qi "there is nothing to do" <<< $updateOutput; then
        printf "NO UPDATES AVAILABLE FOR NOW.\n"
    else
        printf "%s\n" "$updateOutput"
    fi

}