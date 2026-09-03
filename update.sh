#!/bin/bash
#
#
# update.sh

function verifyPendingUpdates(){

    local code=$1

    [[ -e /var/lib/pacman/db.lck ]] && {
        if pgrep -x pacman >/dev/null; then
            printf "THERE IS ANOTHER PACMAN PROCESS RUNNING. PLEASE, VERIFY...\n"
            return 127
        fi
        rm -f /var/lib/pacman/db.lck
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
    if grep -qi "^linux" <<< "$verification"; then
        KERNEL_UPDATED="YES"
        debug --print "[CONTROLLER]: WARNING! THERE IS A UPDATE REGARDING THE LINUX KERNEL! THE SYSTEM WILL TAKE A COPY OF YOUR '/boot' DIRECTORY AND INSERT IN A NEW FOLDER IN THE ROOT DIRECTORY CALLED 'backup_kernel'.\n"
    fi

    [[ -n $code ]] && {

        printf "KERNEL_UPDATED PACKAGES_UPDATED\n"
        printf "%s " "$kernel_updated"
        printf "%s\n" "$verification" | wc -l

        return 0
    }

    verification=$(
        printf "%s\n" "$verification" | awk -F'->' '{ print $1, $2 }' |\
        column -t -s ' ' -o ' '
    )

    

}

function makeUpdate(){

    verifyPendingUpdates
    var=$?

    [[ $var -eq 10 ]] && {
        printf "NO PACKAGES AVAILABLE.\n"
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