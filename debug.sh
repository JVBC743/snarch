#!/bin/bash
#
#
# debug.sh

function debug(){

    local option=$1
    local input=$2
    
    (( $DEBUG != "1" )) && return

    case $option in

        "--print")
                if [ -e "/dev/fd/3" ] 2>/dev/null; then
                    printf "\u001b[35m[ %(%D - %T)T ] %s\u001b[0m\n" -1 "$input" >&3
                fi
            ;;
        
        "--close")
            exec 3>&-
            kill "$DEBUG_PID" >/dev/null
            wait "$DEBUG_PID" >/dev/null
            rm -f "$PIPE_DEBUG"

        ;;
        "--open")
            PIPE_DEBUG="/tmp/debug_pid_$$"
            mkfifo "$PIPE_DEBUG"

            while read -r input; do
                echo -e "$input"
            done < "$PIPE_DEBUG" &
            
            DEBUG_PID=$!

            exec 3> "$PIPE_DEBUG"
            trap 'debug --close' EXIT INT TERM

        ;;
        *)
            printf "INVALID OPTION!!!\n"
        ;;


    esac
}
