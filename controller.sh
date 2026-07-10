#!/bin/bash
#
#
# controller.sh

source update.sh
source lvm.sh
source log.sh
source view.sh
source debug.sh

! grep -Eqi "en_US|C" /etc/locale.conf && { 
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
DEBUG="0"
FUNCTION_DEBUG=""
LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y_%m_%d_%H.%M.%S")

function main(){
    intro
    choose 1

    case $option in

        "1")
            (
                debug --print "[CONTROLLER]: VERIFYING SNAPSHOT VIABILITY..."

                viability=$(snapshotViability)
                if grep -qi "IMPOSSIBLE" <<< $viability; then
                    table "$viability" 1
                    exit
                fi
                snapshotManagement --create

                debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."

                # update_initialization=$(date +"%H:%M:%S - %Y/%m/%d")
                updating=$(update)

                if grep "NO UPDATES AVAILABLE FOR NOW" <<< $updating; then
                    snapshotManagement --delete
                    exit
                fi
                printf "%s\n" "$updating"

                # update_ending=$(date +"%H:%M:%S - %Y/%m/%d")

                debug --print "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

                verifyBinaries
                
                debug --print "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

                verifyPacman

                debug --print "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."

                verifyJournal
            ) | tee -a "$TODAY"_log.txt

            choose "2"

            if (( $option == "1" )); then

                snapshotManagement --rollback
                debug --close

                printf "Your system will be rebooted for a full recovery.\n YOU CAN JUST PRESS CTRL + C TO STOP THE COUNTING.\n"

               for i in {10..1}; do
                    printf "%s\n" "$i"
                    sleep 1
                done

                reboot

            elif (( $option == "2" )); then

                three_days_from_now=$(date -d "3 days" | awk -F' ' '{ print $1 }')
				local=$(pwd)
				service=$(cat <<- EOF
						[Unit]
						Description=Command to delete the snapshot.

						[Service]
						Type=oneshot

						ExecStart=$local/controller.sh $TODAY
					EOF
				)
				timer=$(cat <<- EOF
						[Unit]
						Description=Timer to delete the snapshot

						[Timer]
						OnCalendar=$three_days_from_now *-*-* 00:00:00
						Persistent=true

						[Install]
						WantedBy=timers.target
					EOF
				)

				printf "%s\n" "$service" > /etc/systemd/system/snarch_$TODAY.service
				printf "%s\n" "$timer" > /etc/systemd/system/snarch_$TODAY.timer

				systemctl daemon-reload
				systemctl enable --now snarch_$TODAY.timer

				printf "The service and timer to delete the snapshot have been created in '/etc/systemd/system/'\n"
                printf "All the messages displayed in the terminal can be found in the '%s_log.txt' file.\n" "$TODAY"
				printf "Also, your snapshot will be REMOVED in the next $three_days_from_now day 12 AM\n\n"
				printf "In the mean time, you can verify the snapshot for any corrections\n"

            fi
            ;;
        "2")

            return=$(fetchVolumes 0)           
            table "$return" 2
        ;;
        "3")
            snapshotManagement --create
        ;;
        "4")

            return=$(snapshotViability)
            table "$return" 1
        ;;
        *)
            printf "INVALID OPTION!!!\n"
        ;;
    esac

}

if [[ -n "$1" ]]; then
	snapshotManagement --delete $1
fi

debug --open
main
debug --close