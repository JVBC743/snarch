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

source update.sh
source lvm.sh
source log.sh
source view.sh

! grep -iq "en_US" /etc/locale.conf && { 
    print "The local language of your system must be in 'en_US'!\n"
    exit
}

! ping -c 1 google.com > /dev/null 2>&1 && {
    print "The system needs to have internet connection!\n"
    exit
}

# ! bc && {
#     printf "The basic calculator (bc) package must be in your system!\n" 
# }

intro
choose

case $option in
    "1")
        update
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
