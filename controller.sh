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
    print "The local language of your system must be in 'en_US'!\n"
    exit
}

! ping -c 1 1.1.1.1 > /dev/null 2>&1 && {
    print "The system needs to have internet connection!\n"
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
    choose

    case $option in
        "1")
            $DEBUG_PRINT "[CONTROLLER]: VERIFYING SNAPSHOT VIABILITY..."

            viability=$(snapshotViability)
            if grep -i "IMPOSSIBLE" <<< $viability; then
                table "$viability" 1
                exit
            fi
            takeSnapshot

            $DEBUG_PRINT "[CONTROLLER]: UPDATING THE SYSTEM..."

            # update_initialization=$(date +"%H:%M:%S - %Y/%m/%d")
            update
            # update_ending=$(date +"%H:%M:%S - %Y/%m/%d")

            $DEBUG_PRINT "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

            verifyBinaries
            
            $DEBUG_PRINT "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

            verifyPacman

            $DEBUG_PRINT "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."

            verifyJournal
        ;;
        "2")

            return=$(fetchVolumes 0)           
            table "$return" 2
        ;;
        "3")
            printf "TESTE OPÇÃO 3\n"
        ;;
        "4")
            # snapshotViability

            return=$(snapshotViability)
            table "$return" 1
        ;;
        *)
            printf "TESTE!\n"
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



