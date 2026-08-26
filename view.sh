#!/bin/bash
#
#
# view.sh

IFS=$'\n'

function getWidth(){

    local input=$1
    local middle=$2
    local lateralLeft=$3
    local lateralRight=$4
    local head=$5

    local array=(`printf "%s\n" "$input" | sed 's/\x1b\[[0-9;]*m//g'`)

    # printf "%s\n" "${array[@]}"

    local line=""

    lines=$(
        for i in ${array[@]}; do
            printf "%s\n" "$i" | sed 's/\x1b\[[0-9;]*m//g' | wc -L
        done
    )
    # lineWidth=$(printf "%s\n" "${array[@]}" | sed 's/\x1b\[[0-9;]*m//g' | wc -L)
    lineWidth=$(printf "%s" "$lines" | sort -n | tail -n 1)

    if (( $lineWidth <= 0 )); then
        printf "The width must not be null!\nYou either didn't insert a input or the calculation is wrong!\n"
        exit
    fi
   
    
    [[ ! -z $input ]] && { 
        wid=$(printf "%s\n" "$head" | sed 's/\x1b\[[0-9;]*m//g' | wc -L)
        calc=$(( ( lineWidth - wid ) / 2 ))
    }
    
    local minus=2
    line=$(

        if (( $wid % 2 != 0 )); then
            minus=3
        fi
        printf "%s" "$lateralLeft"
        printf "%0.s " $(seq 0 $(( $calc - $minus ))) | sed "s/ /$middle/g" 
        printf "%s" "$head"
        printf "%0.s " $(seq 0 $(( $calc - 2 ))) | sed "s/ /$middle/g" 
        printf "%s\n" "$lateralRight"

    )

    printf "%s\n" "$line"

}

function table(){

	local raw=$1
    local code=$2

    raw=(`printf "%s\n" "$raw"`)

     case $code in
        "1")
            column_count=$(
                for i in "${raw[@]}"; do
                    printf "%s\n" "$i" | grep -o " " | wc -l
                done
            )
            column_length=$(
                printf "%s\n" "$column_count" | sort -r | awk -F' ' ' NR==1 {
                    print $0
                }'
            )
            
            output=(`

                (
                    for ((i=1;i<=$column_length; i++)); do
                        printf "%s\n" "${raw[@]}" |\
                            awk -F' ' -v col="$i" '{ print $col}' | tr "\n" " "
                        echo ""
                    done
                ) | awk -F' ' '{
                    if (NF == 1) {
                        NF = 3
                    }

                    for (i = 1; i <= NF; i++) {
                        if (i == 1) {
                            $i = "| "$i" :"
                        } else {
                            $i = ""$i" |"
                        }
                    }
                    print
                }' | column -t -s " " -o " "
            `)

            for ((i=0;i<"${#output[@]}";i++)); do

                (( i == 0 )) && {
                    getWidth "${output[i]}" "─" "┌" "┐" ""
                }

                if grep -q "#" <<< "${output[i]}"; then
                    func=$(
                        printf "%s\n" "${output[i]}" | sed -e "s/://" -e "s/#//" |\
                        tr -d "|" | sed -E "s/ +$|^ +//g" | tr " " "#"
                    )
                    getWidth "${output[i]}" "─" "├" "┤" ""
                    getWidth "${output[i]}" " " "│" "│" "$func"
                    getWidth "${output[i]}" "─" "└" "┘" ""
                else
                    printf "%s\n" "${output[i]}" | tr -d "+" | sed "s/|/│/g"
                    
                fi
            done

        ;;
        "2")

            for i in "${raw[@]}"; do
                printf "#%s#\n" "$i"
            done
			
		

        ;;
        *)

        ;;
    esac
  
    return 0

	# printf "┌──────┐\n"
    # printf "├──────┤\n"
	# printf "│		 │"
    # printf "└──────┘\n"
}

function intro() {
    local purple="\e[38;2;186;85;211m"
    local cyan="\e[38;2;0;191;255m"
    local reset="\e[0m"


    banner=$(

        printf "${purple}  ██████╗███╗   ██╗${cyan} ██████╗█████╗  ███████╗██╗  ██╗${reset}\n"
        printf "${purple} ██╔════╝████╗  ██║${cyan}██╔══██║██╔══██╗██╔════╝██║  ██║${reset}\n"
        printf "${purple} ███████╗██╔██╗ ██║${cyan}███████║█████ ╔╝██║     ███████║${reset}\n"
        printf "${purple} ╚════██║██║╚██╗██║${cyan}██╔══██║██╔══██╗██║     ██╔══██║${reset}\n"
        printf "${purple} ███████║██║ ╚████║${cyan}██║  ██║██║  ██║███████╗██║  ██║${reset}\n"
        printf "${purple} ╚══════╝╚═╝  ╚═══╝${cyan}╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝${reset}\n"

    )

    printf "%s\n" "$banner"
    
    printf "${cyan}"

    getWidth "$banner" "─" "┌" "┐" ""
    getWidth "$banner" "─" "├" "┤" "[ Author: João Victor Brum de Castro ]"
    getWidth "$banner" "─" "├" "┤" "[ Automated Snapshot & Recovery Manager ]"
    getWidth "$banner" "─" "├" "┤" "[ Alpha - v0.2.1 $warning]"
    getWidth "$banner" "─" "└" "┘" ""

    printf "${reset}"

}

function choose(){

	local input=$1
    local warning=""
	# local green="\u001b[30;42m"
	local reset="\e[0m"
    local cyan="\e[30;46m"
    option=1

    (( $DEBUG == "1" )) && warning=" - DEBUG MODE "
    (( $DEBUG != "1" )) && warning=""

    output=""
    case "$input" in
        "1")
            opt1="[1]: Just automate already!"
            opt2="[2]: Show me the volumes."
            opt3="[3]: Take a snapshot."
            opt4="[4]: Verify snapshot viability."
            opt5="[0]: Exit the script"

            clear
            intro

            while true; do
                [ $option -eq 1 ] && \
                printf "${cyan}[ $opt1 ]${reset}\n[ $opt2 ]\n[ $opt3 ]\n[ $opt4 ]\n[ $opt5 ]\n"
                [ $option -eq 2 ] && \
                printf "[ $opt1 ]\n${cyan}[ $opt2 ]${reset}\n[ $opt3 ]\n[ $opt4 ]\n[ $opt5 ]\n" 
                [ $option -eq 3 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n${cyan}[ $opt3 ]${reset}\n[ $opt4 ]\n[ $opt5 ]\n" 
                [ $option -eq 4 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n[ $opt3 ]\n${cyan}[ $opt4 ]${reset}\n[ $opt5 ]\n" 
                [ $option -eq 5 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n[ $opt3 ]\n[ $opt4 ]\n${cyan}[ $opt5 ]${reset}\n" 

                read -rsn3 key
                case "$key" in
                    $'\u001b[A')
                        ((option--))
                        [ $option -lt 1 ] && option=5
                        ;;
                        
                    $'\u001b[B')
                        ((option++))
                        [ $option -gt 5 ] && option=1
                        ;;
                        
                    "") break ;;
                esac
                tput cuu 5
                tput ed
            done

            trap exit SIGINT
        ;;
		"2")
            opt1="[1]: ROLLBACK"
            opt2="[2]: COMMIT"
            opt3="[3]: LET ME SEE THE DAMN LOG FILE!"

            clear
            cat "$NOW"_log.txt
        
            table "WHICH OPTION DO YOU WANT TO CHOOSE?" 3

            while true; do
                [ $option -eq 1 ] && \
                printf "${cyan}[ $opt1 ]${reset}\n[ $opt2 ]\n[ $opt3 ]\n"
                [ $option -eq 2 ] && \
                printf "[ $opt1 ]\n${cyan}[ $opt2 ]${reset}\n[ $opt3 ]\n" 
                [ $option -eq 3 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n${cyan}[ $opt3 ]${reset}\n" 
                read -rsn3 key
                case "$key" in
                    $'\u001b[A')
                        ((option--))
                        [ $option -lt 1 ] && option=3
                        ;;
                        
                    $'\u001b[B')
                        ((option++))
                        [ $option -gt 3 ] && option=1
                        ;;
                        
                    "") break ;;
                esac
                tput cuu 3
                tput ed
            done

            trap exit SIGINT
        ;;
        *)
            printf "INVALID OPTION FOR THE 'CHOOSE' FUNCTION!!!\n"
        ;; 
    esac

	unset output
    unset input
}