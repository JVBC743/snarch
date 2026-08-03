#!/bin/bash
#
#
# controller.sh

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG="1"

LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y_%m_%d_%H.%M.%S")
LOCAL=$(pwd)
CURRENT_VIEW=""

source $LOCAL/update.sh
source $LOCAL/lvm.sh
source $LOCAL/log.sh
source $LOCAL/view.sh
source $LOCAL/debug.sh

function preUpdate(){

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
        rm -f /etc/systemd/system/snarch_cleaner_$TODAY.service
        table "$viability" 1
        exit
    }

    snapshotManagement --create

}

function update(){
	debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."
            
	table "UPDATING THE SYSTEM!" 3

	# update_initialization=$(date +"%H:%M:%S - %Y/%m/%d")

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
		exit
	}
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
	verifyJournal 

}
function choosing(){

	choose "2"

	[[ $option -eq 1 ]] && {

		[[ -d "/backup_kernel" ]] && {
			debug --print "[CONTROLLER]: REVERTING THE '/boot' DIRECTORY\n"
			cp -p -r /backup_kernel/* /boot/
			rm -rf /backup_kernel
		}

		snapshotManagement --rollback

		table "YOUR SYSTEM WILL BE REBOOTED FOR A FULL RECOVERY. PRESS CTR + C TO STOP." 3

		for i in {10..1}; do
			printf "%s\n" "$i"
			sleep 1
		done

		reboot
	}
		
	[[ $option -eq 2 ]] && {

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
		table "$output" 3
	}
}

function main(){

	choose 1
    trap exit SIGINT

	[[ $option -eq "5" ]] && {
		option="0"
	}

    case $option in

        "1")
            
            preUpdate
			update
			postUpdate
			choosing

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
		"0")
            printf "EXITING THE SCRIPT...\n"
			exit
        ;;
        *)
            printf "INVALID OPTION!!!\n"
			exit
        ;;
    esac

}

if [[ -n "$1" ]]; then
	snapshotManagement --delete $1
	exit
fi

debug --open
main | tee >(sed 's/\x1b\[[0-9;]*m//g' > "$TODAY"_log.txt)
# debug --close