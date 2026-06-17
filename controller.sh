#!/bin/bash
#
#
# controller.sh

# SÍMBOLOS PARA A TABELA:

# ┌ ┐ ┘ └ 
# ┏ ┓ ┛ ┗
# ╔ ╗ ╝ ╚
# ┬ ┴ ┤ ├
# ╦ ╩ ╣ ╠

# ─
# ━
# ═
# ╌

# │
# ┃
# ║
# ╎

# ├
# ┤
# └
# ┘
# ┌
# ┐
# ─


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

intro
choose

case $option in
    "1")

        snapshot
        printf "[CONTROLLER]: UPDATING THE SYSTEM\n"
        sleep 1
        update
        printf "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES\n"
        log=$(verifyBinaries)
        if [[ -z "$log" ]]; then
            printf "[CONTROLLER]: NO ERRORS FOUND. EXITING..."
            exit
        fi

        printf "%s\n" "$log"

    ;;
    "2")
        # fetchVolumes 0
        table "$(fetchVolumes 0)" 2
    ;;
    "3")
        printf "TESTE OPÇÃO 3\n"
    ;;
    "4")
        # snapshotViability
        table "$(snapshotViability)" 1
    ;;
    *)
        printf "TESTE!\n"
    ;;
esac
