#!/bin/bash
#
#
# controller.sh

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG="1"

LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y-%m-%d")
NOW=$(date +"%Y_%m_%d_%H.%M.%S")
LOCAL=$(pwd)

UPDATED=0
PERFECTION=1

source $LOCAL/update.sh
source $LOCAL/lvm.sh
source $LOCAL/log.sh
source $LOCAL/view.sh
source $LOCAL/debug.sh

function system() {

	local arg="$1"
	case $arg in

		"--requirements")

			! grep -Eqi "en_US|C" /etc/locale.conf && { 
				printf "The local language of your system must be in 'en_US'!\n"
				return 10
			}

			! ls /usr/bin | grep -qi "pactree" && { 
				printf "The pactree utility is required for the functioning of the script!\n"
				printf "You may need to execute the following command to install the utility: 'pacman -S pacman-contrib'\n"
				return 10
			}

			! ping -c 1 1.1.1.1 > /dev/null 2>&1 && {
				printf "The system needs to have internet connection!\n"
				return 10
			}

			! ls /usr/bin | grep -qw 'bc' && {
				printf "The basic calculator (bc) package must be in your system!\n"
				printf "You may need to execute the following command to install the utility: 'pacman -S bc'\n"
				return 10
			}

			! ls /usr/lib/ | grep -qw 'systemd' || ! ls /lib/ | grep -qw 'systemd' || ! ls /run/ | grep -qw "systemd" \
			|| ! ps -p 1 | grep -qw "systemd" && {
				
				printf "Your system does not use 'SystemD'. This script does not work for this environment!\n"
				return 10
			}

			! ls /usr/bin/ | grep -qwi "lvm" && {
				printf "Your system does not use the Logical Volume Manager. This script won't work for this environment!\n"
				return 10
			}

			! ls /usr/bin/ | grep -qwi "less" && { 
				printf "Your system does not have the less command. This script will have issues to work for this environment!\n"
				printf "You may need to execute the following command to install the utility: 'pacman -S less'\n"
				return 10
			}

			! grep -Eqi "Arch Linux|archlinux" /etc/os-release && {
				printf "You must use the Arch Linux distro for this program to work.\n"
				return 10
			}

		;;
		"--boot-checker")

			boot_checker=$(cat <<- EOF
					#!/bin/bash
					STATE_FILE="/var/lib/snarch/state"

					[[ ! -f "\$STATE_FILE" ]] && {
						printf "NUTHING,...."
						exit 0
					
					} 

					source "\$STATE_FILE"

					case "\$PHASE" in 
						"PRE_UPDATE")
							printf "SNARCH HAS BEEN INTERRUPTED IN PRE-UPDATE PROCESS.\nCLEANING SOME LOCK FILES..."
							rm -f /var/lib/pacman/db.lck
							rm -rf /backup_kernel
							rm -f "\$STATE_FILE"
							
						;;
						"APLLYING_UPDATE")
							printf "SNARCH HAS BEEN INTERRUPTED WHILE EXECUTING THE UPDATE PHASE.\n"
							printf "THE SYSTEM IS GOING TO ROLLBACK THE SNAPSHOTS FOR THE SECURITY OF THE SYSTEM.\n"

							.$LOCAL/controller.sh "APLLYING_UPDATE" "\$SNAPSHOT_DATE"
							rm -f "\$STATE_FILE"
							rm -f /etc/systemd/system/snarch-recovery.service

							reboot

						;;
						*)
							rm -f "\$STATE_FILE"
						;;
					esac

				EOF
			)

			printf "%s\n" "$boot_checker" > /usr/local/bin/snarch-boot-checker
			chmod +x /usr/local/bin/snarch-boot-checker

		;;
		"--set-state")

			local phase=$2

			[[ -z "$phase" ||\
				"$phase" -ne "PRE_UPDATE" ||\
				"$phase" -ne "APLLYING_UPDATE" ||\
				"$phase" -ne "UPDATE_FINISHED" ]] && {
				
				table "THE SECOND SET STATE ARGUMENT MUST HAVE A VALID ARGUMENT TO WORK!" 2
				return 10
			}
			
			! ls /var/lib | grep -q "snarch" && {
				mkdir -p /var/lib/snarch
			}

			printf "PHASE=%s\n" "$phase" > /var/lib/snarch/state
			printf "SNAPSHOT_DATE=%s\n" "$NOW" >> /var/lib/snarch/state
			sync
		;;


		"--clean-up")

			printf "INTERRUPT SIGNAL DETECTED!\n"

			snapshotsToDelete=(`fetchVolumes 3`)
			them=(`
				printf "%s\n" "${snapshotsToDelete[@]}" | grep "snap_$NOW*" \
				| awk -F" " '{ print $1 }' | sed 's/snap_//g'
			`)

			(( $UPDATED == 1 )) && {

				[[ -d "/backup_kernel" ]] && {
					debug --print "[CONTROLLER]: REVERTING THE '/boot' DIRECTORY\n"
					cp -p -r /backup_kernel/* /boot/
					rm -rf /backup_kernel
				}

				snapshotManagement --rollback
				table "THE SCRIPT IS GOING TO REBOOT YOUR SYSTEM SINCE YOU HAVE INTERRUPTED IT AFTER THE UPDATE. ANY PROBLEMS FROM NOW MAY BE NOT FROM THE MALFUNCTIONING OF THE SCRIPT." 2

				sleep 5

				reboot

			}

			[[ -n $them ]] && {
				
				for i in ${them[@]}; do
					snapshotManagement --delete $i
				done
			}

			rm -f /etc/systemd/system/snarch_cleaner_$NOW.service
			rm -f /etc/systemd/system/snarch_$NOW.service
			rm -f /etc/systemd/system/snarch_$NOW.timer

			table "THE SCRIPT HAS BEEN INTERRUPTED AFTER RECEIVING THE INTERRUPT SIGNAL..." 2

			sleep 2

			exit 1

		;;

		*)
            printf "INVALID OPTION FOR THE 'SYSTEM' FUNCTION!!!\n"
			return 10
		;;
	esac

	return 0
}

function preUpdate(){

	system "--boot-checker"

	[[ $? -ne 0 ]] && {
		return 10
	}

	system "--set-state" "PRE_UPDATE"

	[[ $? -ne 0 ]] && {
		return 10
	}

	volume_groups=(`fetchVolumes 2 | awk -F' ' '{ print $1 }'`)

	counter=0

	for i in ${volume_groups[@]:1}; do
	
		remove_remaining=$(cat <<- EOF
				[Unit]
				Description=Clean the rest of the snapshot after the rollback on $NOW
				After=local-fs.target

				[Service]
				Type=oneshot
				ExecStart=/usr/bin/bash -c "rm -rf /dev/$i/snap_$NOW* && rm -rf /dev/mapper/$i-snap_$NOW*"
				RemainAfterExit=no

				[Install]
				WantedBy=multi-user.target

			EOF
		)

		service=$(cat <<- EOF
				[Unit]
				Description=Snarch Boot Recovery and Checkpoint Evaluation
				DefaultDependencies=no
				After=local-fs.target
				Before=sysinit.target multi-user.target

				[Service]
				Type=oneshot
				ExecStart=/usr/local/bin/snarch-boot-checker
				RemainAfterExit=yes

				[Install]
				WantedBy=sysinit.target

			EOF
		)

		printf "%s\n" "$service" > /etc/systemd/system/snarch-recovery.service
		printf "%s\n" "$remove_remaining" > /etc/systemd/system/snarch_cleaner_$NOW-$counter.service

		systemctl daemon-reload
    	systemctl enable snarch_cleaner_$NOW-$counter.service
		systemctl enable snarch-recovery.service

		((counter++))

	done

    debug --print "[CONTROLLER]: VERIFYING SNAPSHOT VIABILITY..."

    snapshotViability >/dev/null 

    [[ $? -eq 10 ]] && {
        rm -f /etc/systemd/system/snarch_cleaner*
		table "The creation of the snapshot(s) is not viable for this environment!" 2
        return 10
    }

	table "$(snapshotViability)" 1

    snapshotManagement --create

	return 0

}

function update(){

	system "--set-state" "APLLYING_UPDATE"

	debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."
            
	table "UPDATING THE SYSTEM!" 2

	makeUpdate

	[[ $? -ne 0 ]] && {

		snapshotsToDelete=(`fetchVolumes 3`)
		them=(
			`printf "%s\n" "${snapshotsToDelete[@]}" | grep "snap_$NOW*" \
			| awk -F" " '{ print $1 }' | sed 's/snap_//g'` 
		)

		for i in ${them[@]}; do
			snapshotManagement --delete $i
		done

		rm -f /etc/systemd/system/snarch_cleaner_$NOW.service
		return 10
	}

	system "--set-state" "UPDATE_FINISHED"

	rm -f /var/lib/snarch/state

	return 0
}

function postUpdate(){

	debug --print "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

	table "VERIFYING BINARIES!" 2

	verifyBinaries

	exit_code=$?

	[[ $exit_code -eq 11 ]] && {
		PERFECTION=0
	}
	
	debug --print "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

	table "VERIFYING PACMAN!" 2

	verifyPacman

	exit_code=$?

	[[ $exit_code -eq 11 ]] && {
		PERFECTION=0
	}

	debug --print "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."
	
	table "VERIFYING THE SYSTEM LOGS!" 2

	update_initialization=$(date +"%H:%M:%S")
	update_finalization=$(date +"%H:%M:%S")

	verifyJournal "$update_initialization" "$update_finalization"

	exit_code=$?

	[[ $exit_code -eq 11 ]] && {
		PERFECTION=0
	}

	[[ $PERFECTION -eq 1 ]] && {

		return 11
	}

	return 0
}

function veredict(){

	choose "2"

	[[ $option -eq 1 ]] && {

		[[ -d "/backup_kernel" ]] && {
			debug --print "[CONTROLLER]: REVERTING THE '/boot' DIRECTORY\n"
			cp -p -r /backup_kernel/* /boot/
			rm -rf /backup_kernel
		}

		snapshotManagement --rollback

		exit_code=$?

		[[ $exit_code -ne 1 ]] && {

			snapshotsToDelete=(`fetchVolumes 3`)
			them=(
				`printf "%s\n" "${snapshotsToDelete[@]}" | grep "snap_$NOW*" \
				| awk -F" " '{ print $1 }' | sed 's/snap_//g'` 
			)

			for i in ${them[@]}; do
				snapshotManagement --delete $i
			done

			rm -f /etc/systemd/system/snarch_cleaner_$NOW.service
			exit
		}

		table "YOUR SYSTEM WILL BE REBOOTED FOR A FULL RECOVERY. DON'T INTERRUPT THE COUNTING IN ANY WAY!" 2

		for i in {10..1}; do
			printf "%s\n" "$i"
			sleep 1
		done

		reboot
	}
		
	[[ $option -eq 2 ]] && {

		rm -f /etc/systemd/system/snarch_cleaner_$NOW.service
		two_days=$(date -d "2 days" "+%A")
		hour=$(date "+%H:%M:%S")
		
		service=$(cat <<- EOF
				[Unit]
				Description=Command to delete the snapshot.

				[Service]
				Type=oneshot

				ExecStart=/bin/bash -c "cd $LOCAL && ./controller.sh $NOW && rm /etc/systemd/system/snarch_$NOW*"
			EOF
		)

		timer=$(cat <<- EOF
				[Unit]
				Description=Timer to delete the snapshot

				[Timer]
				OnCalendar=$two_days *-*-* $hour
				Persistent=true

				[Install]
				WantedBy=timers.target
			EOF
		)

		printf "%s\n" "$service" > /etc/systemd/system/snarch_$NOW.service
		printf "%s\n" "$timer" > /etc/systemd/system/snarch_$NOW.timer

		systemctl daemon-reload
		systemctl enable --now snarch_$NOW.timer

		output=$(cat <<- EOF
				THE SERVICE AND TIMER TO DELETE THE SNAPSHOT HAVE BEEN CREATED IN '/etc/systemd/system/'
				ALL THE MESSAGES DISPLAYED IN THE TERMINAL CAN BE FOUND IN THE '"$NOW"_log.txt' FILE.
				ALSO, YOUR SNAPSHOT WILL BE REMOVED IN THE NEXT '$two_days' AT '$hour'
				IN THE MEAN TIME, YOU CAN VERIFY THE SNAPSHOT FOR ANY CORRECTIONS
			EOF
		)
		table "$output" 2
	}

	[[ $option -eq 3 ]] && {

		less "$NOW"_log.txt

		clear
		veredict

	}
}

function main(){

	choose 1

    trap exit SIGINT

	[[ $option -eq "5" ]] && {
		printf "EXITING THE SCRIPT...\n"
		exit
	}

	trap 'system "--clean-up"' SIGINT

	system "--requirements"

	[[ $? -ne 0 ]] && {
		exit
	}

    case $option in
		
        "1")
            
            preUpdate | tee >(sed 's/\x1b\[[0-9;]*m//g' > "$NOW"_log.txt)
			exit_code=${PIPESTATUS[0]}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE PRE-UPDATE!\n"
				exit
			}

			pendingUpdates=(`
				verifyPendingUpdates "1" | grep -Ev "downloading|databases"
			`)

			UPDATED=1

			update | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$NOW"_log.txt)
			exit_code=${PIPESTATUS[0]}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE UPDATE!\n"
				exit
			}

			postUpdate | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$NOW"_log.txt)

			gatherData=(`
				snapshotManagement --gather
			`)

			summary=$(
				for ((i=0;i<"${#gatherData[@]}";i++)); do
					printf "%s %s\n" "${gatherData[i]}" "${pendingUpdates[i]}"
				done
			)

			table "$summary" 1 | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$NOW"_log.txt)
			 
			exit_code=${PIPESTATUS[0]}

			[[ $exit_code -eq 11 ]] && {
				output=$(cat <<- EOF
						SEEMS LIKE THAT YOUR ENVIRONMENT HAS NO DETECTABLE PROBLEMS.
						YOU MIGHT NEED TO VERIFY THE SYSTEM LOGS IN THE CASE OF ERRORS.
						ALL THE MESSAGES DISPLAYED IN THE TERMINAL CAN BE FOUND IN THE '"$NOW"_log.txt' FILE.
						ALSO, YOUR SNAPSHOT WILL BE REMOVED IN THE NEXT '$two_days' AT '$hour'
					EOF
				)

				table "$output" 2
				exit
			}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE POST-UPDATE!\n"
				exit
			}
			
			veredict

        ;;
        "2")
            return=$(fetchVolumes 0)           
            table "$return" 1
        ;;
        "3")
			return=$(snapshotViability)
            if grep -qi "impossible" <<< $return; then
				printf "IT'S NOT POSSIBLE TO TAKE A SNAPSHOT BY THE SCRIPT STANDARDS.\n"
				exit
			fi
            snapshotManagement --create
        ;;
        "4")
            return=$(snapshotViability)
            table "$return" 1
        ;;
        *)
            printf "INVALID OPTION FOR THE 'MAIN' FUNCTION!!!\n"
			exit
        ;;
    esac

}

if [[ "$1" -eq "APPLYING_UPDATE" && -n "$2" ]]; then

	snapshotManagement --rollback $2
	
elif [[ -n $1 ]]; then
	snapshotManagement --delete $1
	exit
fi

debug --open
main
debug --close