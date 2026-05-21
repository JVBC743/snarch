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

function table(){

	local raw=$1
    local code=$2

	# lineWidth=$(echo "$raw" | wc -L)

    # ceil=$(
    #     printf "┌"
    #     printf "%0.s─" $(seq 0 $(( $lineWidth - 3 )))
    #     printf "┐"
    # )
    
    # floor=$(
    #     printf "└"
    #     printf "%0.s─" $(seq 0 $(( $lineWidth - 3 )))
    #     printf "┘"
    # )

    # CÓDIGOS: 
    # 1) output vindo da função 'snapshotViability' do arquivo 'lvm.sh'

    case $code in
        "1")

            declare -a half1
            declare -a half2

            output=(`printf "%s\n" "$raw" | sed 's/^ \+//'`)
            count1=0
            count2=0

            for ((i=0;i<${#output[@]};i++)); do

                if (( $i < ((${#output[@]} - 2)) )); then
                    half1[count1]=$(printf "%s\n" "${output[i]}")
                    ((count1++))
                elif (( $i >= ((${#output[@]} - 2)) )); then
                    half2[count2]=$(printf "%s\n" "${output[i]}")
                    ((count2++))
                fi
            done

            printf "%s\n" "${half1[@]}" | column -t -s ' ' -o '│'
            echo -e "-----\n"
            printf "%s\n" "${half2[@]}"

        ;;


        *)


        ;;


    esac


	# printf "┌──────┐\n"
    # printf "├──────┤\n"
	# printf "│		 │"
    # printf "└──────┘\n"
}