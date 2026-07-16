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

! ls /usr/lib/ | grep -qw 'systemd' || ! ls /lib/ | grep -qw 'systemd' || ! ls /run/ | grep -qw "systemd" \
|| ! ps -p 1 | grep -qw "systemd" && {
    
    printf "Your system does not use 'SystemD'. This script does not work for this environment!\n"
    exit
}

! command -v lvm && {
    printf "Your system does not use the Logical Volume Manager. This script won't work for this environment!\n"
    exit
}

! grep -Ei "Arch Linux|archlinux" /etc/os-release && {
	printf "You must use the Arch Linux distro for this program to work.\n"
	exit
}

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG="1"
LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y_%m_%d_%H.%M.%S")

function main(){
    intro
    choose 1
    trap exit SIGINT

    case $option in

        "1")

			remove_remaining=$(cat <<- EOF
					[Unit]
					Description=Clean the rest of the snapshot after the rollback on $TODAY
					After=local-fs.target
					
					[Service]
					Type=oneshot
					ExecStart=/usr/bin/bash -c "rm -rf /dev/base/snap_$TODAY* && rm -rf /dev/mapper/base-snap_$TODAY*"
					RemainAfterExit=no

					[Install]
					WantedBy=multi-user.target

				EOF
			)

			printf "%s\n" "$remove_remaining" > /etc/systemd/system/snarch_cleaner_$TODAY.service

			systemctl daemon-reload
			systemctl enable snarch_cleaner_$TODAY.service
            
            debug --print "[CONTROLLER]: VERIFYING SNAPSHOT VIABILITY..."

            viability=$(snapshotViability)
            if grep -qi "IMPOSSIBLE" <<< $viability; then
                table "$viability" 1
				rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
                exit
            fi

            pending_updates=$(verifyPendingUpdates | tee -a "$TODAY"_log.txt) 

            if grep -qi "^linux" <<< "$pending_updates"; then

                debug --print "[CONTROLLER]: WARNING! THERE IS A UPDATE REGARDING THE LINUX KERNEL! THE SYSTEM WILL TAKE A COPY OF YOUR '/boot' DIRECTORY AND INSERT IN A NEW FOLDER IN THE ROOT DIRECTORY CALLED 'backup_kernel'.\n"
                sleep 3
                mkdir -p /backup_kernel
                cp -p -r /boot/* /backup_kernel
            fi

            snapshotManagement --create

            debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."

            # update_initialization=$(date +"%H:%M:%S - %Y/%m/%d")
            updating=$(update | tee -a "$TODAY"_log.txt)
            printf "%s\n" "$updating"

            if grep "NO UPDATES AVAILABLE FOR NOW" <<< $updating; then
                snapshotManagement --delete
                debug --close
				rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
                exit
            fi

            # update_ending=$(date +"%H:%M:%S - %Y/%m/%d")

            debug --print "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

            verifyBinaries | tee -a "$TODAY"_log.txt
            
            debug --print "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

            verifyPacman | tee -a "$TODAY"_log.txt

            debug --print "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."

            verifyJournal | tee -a "$TODAY"_log.txt
            
            choose "2"

            if (( $option == "1" )); then

                if [[ -d "/backup_kernel" ]]; then
                    debug --print "[CONTROLLER]: REVERTING THE '/boot' DIRECTORY\n"
                    cp -p -r /backup_kernel/* /boot/
                    rm -rf /backup_kernel

                fi

                snapshotManagement --rollback
                
                printf "Your system will be rebooted for a full recovery.\n YOU CAN JUST PRESS CTRL + C TO STOP THE COUNTING.\n"

               for i in {10..1}; do
                    printf "%s\n" "$i"
                    sleep 1
                done

                reboot

            elif (( $option == "2" )); then

				rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
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