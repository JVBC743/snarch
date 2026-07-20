#!/bin/bash
#
#
# controller.sh


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

! ls /usr/bin/ | grep -qi "lvm" && { #tirar para n aparecer no menu dps
    printf "Your system does not use the Logical Volume Manager. This script won't work for this environment!\n"
    exit
}

! grep -Eqi "Arch Linux|archlinux" /etc/os-release && {
	printf "You must use the Arch Linux distro for this program to work.\n"
	exit
}

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG="1"
LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y_%m_%d_%H.%M.%S")
LOCAL=$(pwd)

source $LOCAL/update.sh
source $LOCAL/lvm.sh
source $LOCAL/log.sh
source $LOCAL/view.sh
source $LOCAL/debug.sh

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

            pending_updates=$(verifyPendingUpdates) 

            if grep -qi "^linux" <<< "$pending_updates"; then

                debug --print "[CONTROLLER]: WARNING! THERE IS A UPDATE REGARDING THE LINUX KERNEL! THE SYSTEM WILL TAKE A COPY OF YOUR '/boot' DIRECTORY AND INSERT IN A NEW FOLDER IN THE ROOT DIRECTORY CALLED 'backup_kernel'.\n"
                sleep 3
                mkdir -p /backup_kernel
                cp -p -r /boot/* /backup_kernel
            fi

            snapshotManagement --create

            debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."
            output=$(cat <<- EOF
					UPDATING THE SYSTEM!
				EOF
			)
			table "$output" "3"
            # update_initialization=$(date +"%H:%M:%S - %Y/%m/%d")
            updating=$(update)
            printf "%s\n" "$updating"

            if grep "NO UPDATES AVAILABLE FOR NOW" <<< $updating; then
                snapshotManagement --delete
                debug --close
				rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
                exit
            fi

            # update_ending=$(date +"%H:%M:%S - %Y/%m/%d")

            debug --print "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."
			output=$(cat <<- EOF
					VERIFYING BINARIES!
				EOF
			)
			table "$output" "3"
            verifyBinaries 
            
            debug --print "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."
			output=$(cat <<- EOF
					VERIFYING PACMAN!
				EOF
			)
			table "$output" "3"
            verifyPacman

            debug --print "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."
			output=$(cat <<- EOF
					VERIFYING THE SYSTEM LOGS!
				EOF
			)
			table "$output" "3"
            verifyJournal 
            
            choose "2"

            if (( $option == "1" )); then

                if [[ -d "/backup_kernel" ]]; then
                    debug --print "[CONTROLLER]: REVERTING THE '/boot' DIRECTORY\n"
                    cp -p -r /backup_kernel/* /boot/
                    rm -rf /backup_kernel

                fi

                snapshotManagement --rollback
                
				output=$(cat <<- EOF
						YOUR SYSTEM WILL BE REBOOTED FOR A FULL RECOVERY. 	 
						YOU CAN JUST PRESS "CTRL + C" TO STOP THE COUNTING. 
					EOF
				)
				printf "%s\n" "$output"
               	for i in {10..1}; do
                    printf "%s\n" "$i"
                    sleep 1
                done

                reboot

            elif (( $option == "2" )); then

				rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
                three_days_from_now=$(date -d "3 days" | awk -F' ' '{ print $1 }')
				
				service=$(cat <<- EOF
						[Unit]
						Description=Command to delete the snapshot.

						[Service]
						Type=oneshot

						ExecStart=/bin/bash -c "cd $LOCAL && ./controller.sh $TODAY && rm /etc/systemd/system/snarch_$TODAY*"
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

				output=$(cat <<- EOF
						THE SERVICE AND TIMER TO DELETE THE SNAPSHOT HAVE BEEN CREATED IN '/etc/systemd/system/'
						ALL THE MESSAGES DISPLAYED IN THE TERMINAL CAN BE FOUND IN THE '"$TODAY"_log.txt' FILE.
						ALSO, YOUR SNAPSHOT WILL BE REMOVED IN THE NEXT '$three_days_from_now' AT 12 AM
						IN THE MEAN TIME, YOU CAN VERIFY THE SNAPSHOT FOR ANY CORRECTIONS
					EOF
				)
				table "$output" "3"
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
	exit
fi

debug --open
main | tee -a "$TODAY"_log.txt
debug --close