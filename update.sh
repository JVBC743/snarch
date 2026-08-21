#!/bin/bash
#
#
# update.sh

function verifyPendingUpdates(){

    local code=$1

    ls /var/lib/pacman/ | grep -q "db.lck" && {
        rm /var/lib/pacman/db.lck
    }

    pacman -Sy

    [[ $? -ne 0 ]] && {
        printf "ERRORS HAVE BEEN FOUND DURING THE REMOTE REPO SYNC.\n"
        return 127
    }
    
    local verification=$(
        pacman -Qu
    )

    [[ -z "$verification" ]] && {
        return 10
    }

    [[ -n $code ]] && {

        local kernel_updated="NO"
        
        if grep -qi "^linux" <<< "$verification"; then
            kernel_updated="YES"
        fi
        printf "| PACKAGES_UPDATED : "
        printf "%s\n" "$verification" | wc -l
        printf "| KERNEL_UPDATED : %s\n" "$kernel_updated"

        return 0
    }

    verification=$(
        printf "%s\n" "$verification" | awk -F'->' '{ print $1, $2 }' |\
        column -t -s ' ' -o ' '
    )

    if grep -qi "^linux" <<< "$verification"; then

        debug --print "[CONTROLLER]: WARNING! THERE IS A UPDATE REGARDING THE LINUX KERNEL! THE SYSTEM WILL TAKE A COPY OF YOUR '/boot' DIRECTORY AND INSERT IN A NEW FOLDER IN THE ROOT DIRECTORY CALLED 'backup_kernel'.\n"
        sleep 3
        mkdir -p /backup_kernel
        cp -p -r /boot/* /backup_kernel
    fi

}

function makeUpdate(){

    verifyPendingUpdates
    var=$?

    [[ $var -eq 10 ]] && {
        printf "NO PACKAGES AVAIABLE.\n"
        return 10
    }

    [[ $var -ne 0 ]] && {
        printf "AN ERROR HAS OCCURRED DURING THE VERIFICATION OF THE REPO PACKAGES\n"
        return 10
    }

    pacman -Syu --noconfirm

    [[ $? -ne 0 ]] && {
        printf "ERRORS HAVE BEEN FOUND DURING THE UPDATE.\n"
        return 127
    }

    printf "%s\n" "$updateOutput"


}