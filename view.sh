#!/bin/bash
#
#
# view.sh

#VER SE VAI PRECISAR SER UM DAEMON

IFS=$'\n'
intro(){ 

	local output

    output=$(cat <<- EOF
			=============#==================#=============
			============# Welcome to Snarch! #============
			=============#==================#=============
		EOF
    )
	printf "%s\n" "$output"
}

choose(){

	local output

    output=$(cat <<- EOF
			What operation you need to be done?
			[1]: Just automate already
			[2]: Show me the volumes
			[3]: Take a snapshot
			[4]: Verify snapshot viability			
			[ENTER]: default [1]
		EOF
	)
	printf "%s\nYour choice: " "$output"

    read option

    if [[ -z $option ]]; then
        option="1"
    elif (( $option > 4 || $option < 1 )); then
        printf "\nINVALID OPTION!\n"
        exit
    fi
}

function print(){

    printf "%s\n" $1
}

function table(){

	output=$1

	printf "%s\n" "$output"

	lineWidth=$(echo "$output" | wc -L)

    ceil=$(
        printf "┌"
        printf "%0.s─" $(seq 0 $(( $lineWidth - 3 )))
        printf "┐"
    )
    
    floor=$(
        printf "└"
        printf "%0.s─" $(seq 0 $(( $lineWidth - 3 )))
        printf "┘"
    )

	# printf "┌──────┐\n"
    # printf "├──────┤\n"
	# printf "│		 │"
    # printf "└──────┘\n"
}