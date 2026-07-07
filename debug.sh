#!/bin/bash
#
#
# debug.sh

debugIO() {

    while read -r input; do
        echo -e "$input"
    done < "$1"
}

debugPrint() {
    printf "[ %(%D - %T)T ] %s\n" -1 "$1" >&3
}


function debugOpen() {

    PIPE_DEBUG="/tmp/debug_pid_$$"
    mkfifo "$PIPE_DEBUG"
    debugIO "$PIPE_DEBUG" &
    DEBUG_PID=$!
    exec 3> "$PIPE_DEBUG"
    
}

function debugClose(){
    exec 3>&-
    kill "$DEBUG_PID" >/dev/null
    rm -f "$PIPE_DEBUG"
}







