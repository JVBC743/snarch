#!/bin/bash
#
#
# update.sh

function makeUpdate() {
    code=$1

    [[ -z $code ]] && {
        printf "NO OPTION HAS BEEN PROVIDED FOR THE 'update' FUNCTION!!!\n"
        return 127
    }

    case $code in
        "--check")

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
            packages=$(
                pacman -Su --print-format "%n"
            )
            
            [[ -z $packages ]] && {
                printf "THERE ARE NO PACKAGES AVAILABLE FOR UPDATE.\n"
                return 10
            }

            UPDATE["packages"]=$(
                printf "%s\n" "$packages" 
            )
            UPDATE["packages_number"]=$(
                printf "%s\n" "$packages" | wc -l
            )
            
            UPDATE["kernel_updated"]="NO"
            
            if grep -qi "^linux" <<< ${UPDATE["packages"]}; then
                UPDATE["kernel_updated"]="YES"
                debug --print "[CONTROLLER]: WARNING! THERE IS A UPDATE REGARDING THE LINUX KERNEL! THE SYSTEM WILL TAKE A COPY OF YOUR '/boot' DIRECTORY AND INSERT IN A NEW FOLDER IN THE ROOT DIRECTORY CALLED 'backup_kernel'.\n"
            fi
        ;;
        "--make")

            pacman -Syu --noconfirm

            [[ $? -ne 0 ]] && {
                printf "ERRORS HAVE BEEN FOUND DURING THE UPDATE.\n"
                return 127
            }

            UPDATE["system_updated"]="YES"

        ;;
        *)
            printf "INVALID OPTION '$code' FOR THE 'update' FUNCTION!!!\n"
        ;;
    esac

    return 0
}