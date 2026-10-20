#!/bin/bash
#
#
# controller.sh

DEBUG_PID=0
PIPE_DEBUG=""
DEBUG="0"

LVM_SUPPRESS_FD_WARNINGS=1
TODAY=$(date +"%Y-%m-%d")
NOW=$(date +"%Y_%m_%d_%H.%M.%S")
LOCAL=$(pwd)


LOG_FILE='"$NOW"_log.txt'
OUTPUT=""
PERFECTION=1
EFI=""

declare -Ag LVM

#HAS THESE INDEXES:
# vg_name
# vg_size
# vg_free
# lv_size
# lv_per_vg
# twenty_percent
# snapshot_viability
# snapshot_name
# snapshot_size
# snapshot_data

declare -ag LV
declare -Ag UPDATE

#HAS THESE INDEXES:
# system_updated
# update_initialization
# update_finalization
# kernel_updated
# packages
# packages_number

UPDATE["system_updated"]="NO"
UPDATE["kernel_updated"]="NO"

source $LOCAL/update.sh
source $LOCAL/lvm.sh
source $LOCAL/log.sh
source $LOCAL/view.sh
source $LOCAL/debug.sh

function system() {

	local code="$1"
	case $code in

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
							rm -rf /boot_backup
							rm -f "\$STATE_FILE"
							
						;;
						"APPLYING_UPDATE")
							printf "SNARCH HAS BEEN INTERRUPTED WHILE EXECUTING THE UPDATE PHASE.\n"
							printf "THE SYSTEM IS GOING TO ROLLBACK THE SNAPSHOTS FOR THE SECURITY OF THE SYSTEM.\n"

							.$LOCAL/controller.sh "APPLYING_UPDATE" "\$SNAPSHOT_DATE"
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
				"$phase" -ne "APPLYING_UPDATE" ||\
				"$phase" -ne "UPDATE_FINISHED" ]] && {
				
				renderTraces "THE SECOND SET STATE ARGUMENT MUST HAVE A VALID ARGUMENT TO WORK!" "--square"
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

			printf "FINISHING THE SCRIPT!\n"

			fetchVolumes --arrange

			[[ ${UPDATE["system_updated"]} == "YES" ]] && {

				[[ -d "/boot_backup" ]] && {
					debug --print "[CONTROLLER]: REVERTING THE '$EFI' DIRECTORY."
					cp -r /boot_backup/* $EFI/
					sync
					rm -rf /boot_backup
				}

				snapshotManagement --rollback

				renderTraces "THE SCRIPT IS GOING TO REBOOT YOUR SYSTEM AFTER THE UPDATE." "--square"

				for i in {10..1}; do
					printf "%s\n" "$i"
					sleep 1
				done

				reboot
			}

			for lv in ${LV[@]}; do

				if [[ -z ${LVM["$lv.snapshot_name"]} ]]; then
					printf "NO SNAPSHOTS WERE CREATED YET!\n"
				else
					snapshotsToDelete=$(printf "%s\n" ${LVM["$lv.snapshot_name"]} |  grep "snap_$NOW*")
					snapshotManagement --delete $snapshotsToDelete
				fi
			done

			debug --print "[CONTROLLER]: REMOVING SNARCH CLEANER FILE..."
			rm -f /etc/systemd/system/snarch_cleaner_$NOW.service
			debug --print "[CONTROLLER]: REMOVING SNARCH CLEANER SERVICE FILE..."
			rm -f /etc/systemd/system/snarch_$NOW.service
			debug --print "[CONTROLLER]: REMOVING SNARCH CLEANER TIMER FILE..."
			rm -f /etc/systemd/system/snarch_$NOW.timer

			renderTraces "THE SCRIPT HAS BEEN INTERRUPTED AFTER RECEIVING THE INTERRUPT SIGNAL..." "--square"

			exit

		;;

		*)
            printf "INVALID OPTION '$code' FOR THE 'SYSTEM' FUNCTION!!!\n"
			return 10
		;;
	esac

	return 0
}

function preUpdate(){
	
	local output
	local status

	system "--boot-checker"

	[[ $? -ne 0 ]] && {
		return 10
	}

	system "--set-state" "PRE_UPDATE"

	[[ $? -ne 0 ]] && {
		return 10
	}

	counter=0

	for lv in "${LV[@]}"; do
		vg_name="${LVM["$lv.vg_name"]}"
			
		remove_remaining=$(cat <<- EOF
				[Unit]
				Description=Clean the rest of the snapshot after the rollback on $NOW
				After=local-fs.target

				[Service]
				Type=oneshot
				ExecStart=/usr/bin/bash -c "rm -rf /dev/$vg_name/snap_$NOW* && rm -rf /dev/mapper/$vg_name-snap_$NOW*"
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

    snapshotViability > /dev/null

    [[ $? -eq 10 ]] && {
        rm -f /etc/systemd/system/snarch_cleaner*
		renderTraces "The creation of the snapshot(s) is not viable for this environment!" "--square"
        return 10
    }

	renderTraces "$(snapshotViability)" "--table"

    debug --print "[CONTROLLER]: INITIALIZING THE SNAPSHOT CREATION..."

    snapshotManagement --create

	[[ $? -ne 0 ]] && {
		return 10
	}
	fetchVolumes --arrange

	return 0
}

function update(){

	system "--set-state" "APPLYING_UPDATE"

	debug --print "[CONTROLLER]: UPDATING THE SYSTEM..."
            
	renderTraces "UPDATING THE SYSTEM!" "--square"

	makeUpdate --check

	exit_code=${PIPESTATUS[0]}

	[[ $exit_code -eq 10 ]] && {
		renderTraces "THE UPDATE CHECKING PROCESS HAS BEEN INTERRUPTED!" "--square"
		return 10
	}

	[[ $exit_code -eq 127 ]] && {
		renderTraces "A NON-CRITICAL ERROR HAS OCCURRED! PLEASE, CHECK THE PROBLEM YOURSELF." "--square"
		return 10
	}

	[[ $exit_code -ne 0 ]] && {
		system "--clean-up"
		return 10
	}

	EFI=$(findEFI) #DEVERIA EU COLOCAR O CAMINHO DA PARTIÇÃO MONTADA EFI NO ARRAY DO LVM?

	[[ ${UPDATE["kernel_updated"]} == "YES" ]] && {
		mkdir /boot_backup
		renderTraces "THE '/boot_backup' DIRECTORY HAS BEEN CREATED!" --square
        cp -r $EFI/* /boot_backup/
	}

	makeUpdate --make

	exit_code=${PIPESTATUS[0]}

	[[ $exit_code -eq 127 ]] && {
		renderTraces "A NON-CRITICAL ERROR HAS OCCURRED! PLEASE, CHECK THE PROBLEM YOURSELF." "--square"
		return 10
	}

	[[ $exit_code -ne 0 ]] && {
		system "--clean-up"
		return 10
	}

	system "--set-state" "UPDATE_FINISHED"

	rm -f /var/lib/snarch/state
	debug --print "[CONTROLLER]: THE UPDATE HAS BEEN COMPLETED WITH SUCCESS..."

	fetchVolumes --arrange

	return 0
}

function postUpdate(){

	debug --print "[CONTROLLER]: SYSTEM UPDATED, NOW VERIFYING BINARIES..."

	renderTraces "VERIFYING BINARIES!" "--square"

	verifyBinaries

	exit_code=$?

	[[ $exit_code -eq 11 ]] && {
		PERFECTION=0
	}
	
	debug --print "[CONTROLLER]: BINARIES VERIFIED, NOW VERIFYING PACMAN LOGS..."

	renderTraces "VERIFYING PACMAN!" "--square"

	verifyPacman

	exit_code=$?

	[[ $exit_code -eq 11 ]] && {
		PERFECTION=0
	}

	debug --print "[CONTROLLER]: PACMAN LOGS VERIFIED, NOW VERIFYING SYSTEM LOGS..."
	
	renderTraces "VERIFYING THE SYSTEM LOGS!" "--square"

	verifyJournal ${UPDATE["update_initialization"]} ${UPDATE["update_finalization"]}

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

		system --clean-up
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
		renderTraces "$output" "--square"
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

	fetchVolumes --arrange

	[[ $? -ne 0 ]] && {
		exit
	}

    case $option in
		
        "1")

			exec 3>&1 4>&2
			exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' > "${NOW}_log.txt")) 2>&1

			local process_initialization=$(date +"%H:%M:%S")
			local process_finalization=""
            
            preUpdate
			
			[[ $? -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE PRE-UPDATE!\n"
				exit
			}

			UPDATE["update_initialization"]=$(date +"%H:%M:%S")
			update 
			UPDATE["update_finalization"]=$(date +"%H:%M:%S")

			[[ $? -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE UPDATE!\n"
				exit
			}

			postUpdate
			
			process_finalization=$(date +"%H:%M:%S")

			local first=1

			summary=$(

				printf "NAME GROUP SIZE USAGE KERNEL_UPDATED PACKAGES_UPDATED ELAPSED_TIME\n"
				for lv in ${LV[@]}; do

					local kernel_val=""
					local pkgs_val=""
					local elapsed_time=""

					(( $first == 1 )) && {
						kernel_val=${UPDATE["kernel_updated"]}
						pkgs_val=${UPDATE["packages_number"]}
						start_sec=$(date -d $process_initialization +%s)
						end_sec=$(date -d $process_finalization +%s)
						elapsed_time=$(( end_sec - start_sec ))
						elapsed_time=$(date -u -d "@$elapsed_time" +"%T")

						first=0
					}
					
					printf "%s %s %s %s%% %s %s %s\n" \
					${LVM["$lv.snapshot_name"]} \
					${LVM["$lv.vg_name"]} \
					${LVM["$lv.snapshot_size"]} \
					${LVM["$lv.snapshot_data"]} \
					$kernel_val \
					$pkgs_val \
					$elapsed_time
				done	
			)

			renderTraces "$summary" "--table"

			exit_code=${PIPESTATUS[0]}

			[[ $exit_code -eq 11 ]] && {
				output=$(cat <<- EOF
						SEEMS LIKE THAT YOUR ENVIRONMENT HAS NO DETECTABLE PROBLEMS.
						YOU MIGHT NEED TO VERIFY THE SYSTEM LOGS IN THE CASE OF ERRORS.
						ALL THE MESSAGES DISPLAYED IN THE TERMINAL CAN BE FOUND IN THE '"$NOW"_log.txt' FILE.
						ALSO, YOUR SNAPSHOT WILL BE REMOVED IN THE NEXT '$two_days' AT '$hour'
					EOF
				)

				renderTraces "$output" "--square"
				exit
			}
			
			[[ $exit_code -ne 0 ]] && {
				printf "THE SCRIPT HAS BEEN INTERRUPTED AFTER THE POST-UPDATE!\n"
				exit
			}
			
			exec 1>&3 2>&4
			exec 3>&- 4>&-

			veredict
        ;;
        "2")
            renderTraces "$(fetchVolumes "--all")  " "--table"
        ;;
        "3")
			snapshotViability

			[[ $? -ne 0 ]] && {
				printf "IT'S NOT POSSIBLE TO TAKE A SNAPSHOT BY THE SCRIPT STANDARDS.\n"
				exit
			}

            snapshotManagement --create

			[[ $? -ne 0 ]] && {
				exit
			}
        ;;
        "4")
			renderTraces "$(snapshotViability)" "--table"
        ;;
        *)
            printf "INVALID OPTION '$option' FOR THE 'MAIN' FUNCTION!!!\n"
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