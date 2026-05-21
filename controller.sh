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

source update.sh
source lvm.sh
source log.sh
source view.sh

! grep -iq "en_US" /etc/locale.conf && \
{ 
    print "The local language of your system must be in 'en_US'!";\
    exit; 
}

! ping -c 1 google.com > /dev/null 2>&1 && \
{
    print "The system needs to have internet connection!";\
    exit;
}

intro
choose

case $option in
    "1")
        printf "TESTE OPÇÃO 1\n"
    ;;
    "2")
        fetchVolumes 0
    ;;
    "3")
        printf "TESTE OPÇÃO 3\n"
    ;;
    "4")
        # print "$(snapshotViability)"
        table "$(snapshotViability)" 1
    ;;
    *)
        printf "TESTE!\n"
    ;;
esac
