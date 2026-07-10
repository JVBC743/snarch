#!/bin/bash
#
#
# update.sh

function update(){

    updateOutput=$(pacman -Syu --noconfirm)

    if [[ $? -ne 0 ]]; then
        printf "ERRORS HAVE BEEN FOUND.\n" 
        exit
    fi

    if grep -qi "there is nothing to do" <<< $updateOutput; then

        printf "NO UPDATES AVAILABLE FOR NOW.\n"
        exit
    else
        printf "%s\n" "$updateOutput"
    fi

}