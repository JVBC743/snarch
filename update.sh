#!/bin/bash
#
#
# update.sh

function update(){

    updateOutput=$(pacman -Syu --noconfirm 2> error_temp.txt)

    if [[ $? -ne 0 ]]; then
        printf "ERRORS HAVE BEEN FOUND.\n" 
        exit
    else
        rm error_temp.txt
    fi

    if grep -qi "there is nothing to do" <<< $updateOutput; then

        printf "NO UPDATES AVAILABLE FOR NOW.\n"
        exit
    else
        printf "%s\n" "$updateOutput"
    fi

}