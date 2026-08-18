#!/bin/bash
#
#
# controller.sh

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG="0"

LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y_%m_%d_%H.%M.%S")
LOCAL=$(pwd)

UPDATED=0

source $LOCAL/update.sh
source $LOCAL/lvm.sh
source $LOCAL/log.sh
source $LOCAL/view.sh
source $LOCAL/debug.sh

function requirements() {
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

	return 0
}

function preUpdate(){


	volume_groups=(`fetchVolumes 2 | awk -F' ' '{ print $1 }'`)

	counter=0

	for i in ${volume_groups[@]:1}; do
	
		remove_remaining=$(cat <<- EOF
				[Unit]
				Description=Clean the rest of the snapshot after the rollback on $TODAY
				After=local-fs.target

				[Service]
				Type=oneshot
				ExecStart=/usr/bin/bash -c "rm -rf /dev/$i/snap_$TODAY* && rm -rf /dev/mapper/$i-snap_$TODAY*"
				RemainAfterExit=no

				[Install]
				WantedBy=multi-user.target

			EOF
		)

		printf "%s\n" "$remove_remaining" > /etc/systemd/system/snarch_cleaner_$TODAY-$counter.service
		systemctl daemon-reload
    	systemctl enable snarch_cleaner_$TODAY-$counter.service
		((counter++))

	done

    debug --print "[CONTROLLER]: VERIFYING SNAPSHOT VIABILITY..."

    snapshotViability >/dev/null 

    [[ $? -eq 10 ]] && {
        rm -f /etc/systemd/system/snarch_cleaner*
		table "The creation of the snapshot(s) is not viable for this environment!" 3
        return 10
    }

	table "$(snapshotViability)" 1

    snapshotManagement --create

	return 0

}

function update(){
	debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."
            
	table "UPDATING THE SYSTEM!" 3

	update_initialization=$(date +"%Y-%m-%d %H:%M:%S")

	makeUpdate

	[[ $? -ne 0 ]] && {

		snapshotsToDelete=(`fetchVolumes 3`)
		them=(
			`printf "%s\n" "${snapshotsToDelete[@]}" | grep "snap_$TODAY*" \
			| awk -F" " '{ print $1 }' | sed 's/snap_//g'` 
		)

		for i in ${them[@]}; do
			snapshotManagement --delete $i
		done

		rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
		return 10
	}

	update_finalization=$(date +"%Y-%m-%d %H:%M:%S")

	return 0
}

function postUpdate(){

	debug --print "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

	table "VERIFYING BINARIES!" 3

	verifyBinaries 
	
	debug --print "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

	table "VERIFYING PACMAN!" 3

	verifyPacman

	debug --print "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."
	
	table "VERIFYING THE SYSTEM LOGS!" 3

	verifyJournal "$update_initialization" "$update_finalization"

	return 0

}

function choosing(){

	snappers=$(fetchVolumes 3 | grep "snap*" | awk -F' ' '{ print " " $1, $3, $4 "%" }')
	snappers=$(
		(
			printf " SNAPSHOT_NAME SIZE CHANGED \n"
			printf "%s\n" "$snappers"
		) | column -t -s ' ' -o ' │ '
	)
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
				`printf "%s\n" "${snapshotsToDelete[@]}" | grep "snap_$TODAY*" \
				| awk -F" " '{ print $1 }' | sed 's/snap_//g'` 
			)

			for i in ${them[@]}; do
				snapshotManagement --delete $i
			done

			rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
			exit
		}

		table "YOUR SYSTEM WILL BE REBOOTED FOR A FULL RECOVERY. DON'T INTERRUPT THE COUNTING IN ANY WAY!" 3

		for i in {10..1}; do
			printf "%s\n" "$i"
			sleep 1
		done

		reboot
	}
		
	[[ $option -eq 2 ]] && {

		rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
		two_days=$(date -d "2 days" "+%A")
		hour=$(date "+%H:%M:%S")
		
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
				OnCalendar=$two_days *-*-* $hour
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
				ALSO, YOUR SNAPSHOT WILL BE REMOVED IN THE NEXT '$two_days' AT '$hour'
				IN THE MEAN TIME, YOU CAN VERIFY THE SNAPSHOT FOR ANY CORRECTIONS
			EOF
		)
		table "$output" 3
	}

	[[ $option -eq 3 ]] && {

		less "$TODAY"_log.txt

		clear
		choosing

	}
}
cleanup() {
    
	printf "INTERRUPT SIGNAL DETECTED!\n"

	snapshotsToDelete=(`fetchVolumes 3`)
	them=(`
		printf "%s\n" "${snapshotsToDelete[@]}" | grep "snap_$TODAY*" \
		| awk -F" " '{ print $1 }' | sed 's/snap_//g'
	`)

	(( $UPDATED == 1 )) && {

		[[ -d "/backup_kernel" ]] && {
			debug --print "[CONTROLLER]: REVERTING THE '/boot' DIRECTORY\n"
			cp -p -r /backup_kernel/* /boot/
			rm -rf /backup_kernel
		}

		snapshotManagement --rollback
		table "THE SCRIPT IS GOING TO REBOOT YOUR SYSTEM SINCE YOU HAVE INTERRUPTED IT AFTER THE UPDATE. ANY PROBLEMS FROM NOW MAY BE NOT FROM THE MALFUNCTIONING OF THE SCRIPT." 3

		sleep 5

		reboot

	}

	[[ -n $them ]] && {
		
		for i in ${them[@]}; do
			snapshotManagement --delete $i
		done
	}

	rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
	rm -f /etc/systemd/system/snarch_$TODAY.service
	rm -f /etc/systemd/system/snarch_$TODAY.timer

	table "THE SCRIPT HAS BEEN INTERRUPTED AFTER RECEIVING THE INTERRUPT SIGNAL..." 3

	sleep 2

	exit 1
}

function main(){

	choose 1

    trap exit SIGINT

	[[ $option -eq "5" ]] && {
		printf "EXITING THE SCRIPT...\n"
		exit
	}

	trap cleanup SIGINT

	requirements

	[[ $? -ne 0 ]] && {
		
		exit
	}

    case $option in
		"0")
            printf "EXITING THE SCRIPT...\n"
			exit
        ;;
		
        "1")
            
            preUpdate | tee >(sed 's/\x1b\[[0-9;]*m//g' > "$TODAY"_log.txt)
			exit_code=${PIPESTATUS[0]}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE PRE-UPDATE!\n"
				exit
			}

			UPDATED=1

			update | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$TODAY"_log.txt)
			exit_code=${PIPESTATUS[0]}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE UPDATE!\n"
				exit
			}

			postUpdate | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$TODAY"_log.txt)
			exit_code=${PIPESTATUS[0]}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE POST-UPDATE!\n"
				exit
			}
			
			choosing

        ;;
        "2")
            return=$(fetchVolumes 0)           
            table "$return" 2
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

if [[ -n "$1" ]]; then
	snapshotManagement --delete $1
	exit
fi

debug --open
main 
debug --close