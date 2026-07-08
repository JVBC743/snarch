#!/bin/bash
#
#
# controller.sh

: << 'DEBUGS'

    [DEBUG]: MISSING LIB FOR '%s' BINARY.
    [CONTROLLER]: UPDATING THE SYSTEM\n"
    [CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES
    [CONTROLLER]: NO ERRORS FOUND. EXITING...
    [UPDATE]: A ERROR HAS OCCURRED, VERIFY THE 'error_temp.txt' FILE FOR MORE DETAILS.

DEBUGS

source update.sh
source lvm.sh
source log.sh
source view.sh
source debug.sh

! grep -iq "en_US" /etc/locale.conf && { 
    printf "The local language of your system must be in 'en_US'!\n"
    exit
}

! ping -c 1 1.1.1.1 > /dev/null 2>&1 && {
    printf "The system needs to have internet connection!\n"
    exit
}

! ls /usr/bin | grep -qw 'bc' && {
    printf "The basic calculator (bc) package must be in your system!\n"
    exit
}

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG=1
FUNCTION_DEBUG=""
LVM_SUPPRESS_FD_WARNINGS=1

function main(){
    intro
    choose 1

    case $option in
        "1")
            $DEBUG_PRINT "[CONTROLLER]: VERIFYING SNAPSHOT VIABILITY..."

            viability=$(snapshotViability)
            if grep -qi "IMPOSSIBLE" <<< $viability; then
                table "$viability" 1
                exit
            fi
            takeSnapshot

            $DEBUG_PRINT "[CONTROLLER]: UPDATING THE SYSTEM..."

            # update_initialization=$(date +"%H:%M:%S - %Y/%m/%d")
            updating=$(update)

            # if grep "NO UPDATES AVAILABLE FOR NOW" <<< $updating; then
            #     deleteSnapshot
            #     exit
            # fi

            printf "%s\n" "$updating"

            # update_ending=$(date +"%H:%M:%S - %Y/%m/%d")

            $DEBUG_PRINT "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

            verifyBinaries
            
            $DEBUG_PRINT "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

            verifyPacman

            $DEBUG_PRINT "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."

            verifyJournal

            choose "2"

            if (( $option == "1" )); then

                makeRollback

                printf "Your system will be rebooted for a full recovery in:"

               for i in {5..1}; do
                    printf "%s\n" "$i"
                    sleep 1
                done
                

                reboot

                

            elif (( $option == "2" )); then

                printf "All the messages displayed in the terminal can be found in the 'process_log.txt' file.\nAlso, you snapshot will be REMOVED in 'set_date'"

            fi
            ;;
        "2")

            return=$(fetchVolumes 0)           
            table "$return" 2
        ;;
        "3")
            takeSnapshot
        ;;
        "4")
            # snapshotViability

            return=$(snapshotViability)
            table "$return" 1
        ;;
        *)
            printf "TESTE!!!!!\n"
        ;;
    esac

}

if (( $DEBUG == 1 )); then
    debugOpen
    DEBUG_PRINT="debugPrint"
    main
    debugClose
else

    main

fi



