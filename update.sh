#!/bin/bash
#
#
# update.sh

function verifyPendingUpdates(){
    
    local verification=$(
        pacman -Sy
        pacman -Qu | awk -F'->' '{ print $1, $2 }' |\
        column -t -s ' ' -o ' '
    )

    if grep -qi "^linux" <<< "$verification"; then

        debug --print "[CONTROLLER]: WARNING! THERE IS A UPDATE REGARDING THE LINUX KERNEL! THE SYSTEM WILL TAKE A COPY OF YOUR '/boot' DIRECTORY AND INSERT IN A NEW FOLDER IN THE ROOT DIRECTORY CALLED 'backup_kernel'.\n"
        sleep 3
        mkdir -p /backup_kernel
        cp -p -r /boot/* /backup_kernel
    fi

    if [[ $? -ne 0 ]]; then
        printf "ERRORS HAVE BEEN FOUND DURING THE VERIFICATION.\n"
        return 127
    fi

}

function update(){

    pacman -Sy && pacman -Qu >/dev/null

    if [[ $? -eq 1 ]]; then
        printf "NO UPDATES AVAIABLE\n."
        return 10
    fi

    pacman -Syu --noconfirm

    if [[ $? -ne 0 ]]; then
        printf "ERRORS HAVE BEEN FOUND DURING THE UPDATE.\n"
        return 127

    else
        printf "%s\n" "$updateOutput"
    fi

}