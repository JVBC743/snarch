#!/bin/bash
#
#
# view.sh

IFS=$'\n'

function getWidth(){

    local input=$1
    local middle=$2
    local lateral_left=$3
    local lateral_right=$4
    local head=$5

    local clean_input=$(printf "%s\n" "$input" | sed 's/\x1b\[[0-9;]*m//g')
    local clean_head=$(printf "%s\n" "$head" | sed 's/\x1b\[[0-9;]*m//g')

    local width_line=$(printf "%s\n" "$clean_input" | wc -L)

    (( $width_line <= 0 )) && {
        printf "The width must not be null!\nYou either didn't insert a input or the calculation is wrong!\n"
        exit 1
    }

    local width_head=$(printf "%s\n" "$clean_head" | wc -L)
    local space=$(( width_line - width_head - 2 ))
    
    local left=$(( space / 2 ))
    local right=$(( space - left ))

    fill_left=$(printf "%*s" "$left" '' | sed "s/ /$middle/g")
    fill_right=$(printf "%*s" "$right" '' | sed "s/ /$middle/g")

    printf "%s%s%s%s%s\n" "$lateral_left" "$fill_left" "$head" "$fill_right" "$lateral_right"

}

function renderTraces(){

	local raw=$1
    local code=$2
    local output=""

    raw=(`printf "%s\n" "$raw"`)
    
     case $code in
        "--table")
            column_length=$(
                printf "%s\n" "${raw[@]}" | awk '{ print NF }' | sort -rn | head -n1
            )
           
            mid_way=(`
                for ((i=1;i<=$column_length; i++)); do
                    printf "%s\n" "${raw[@]}" |\
                        awk -F' ' -v col="$i" '{ print $col}' | tr "\n" " "
                    echo ""
                done
            `)
            column_length=$(
                printf "%s\n" "${mid_way[@]}" | awk '{ print NF }' | sort -rn | head -n1
            )
            output=(`
                printf "%s\n" "${mid_way[@]}" | awk -F' ' -v max="$column_length" '{
                    printf "| %s :", $1

                    for (i = 2; i <= max; i++) {
                        printf " %s |", $i
                    }
                    
                    print ""
                }' | column -t -s " " -o " "
            `)

            for ((i=0;i<"${#output[@]}";i++)); do

                (( $i == 0 )) && {
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
                    printf "%s\n" "${output[i]}" | sed "s/|/│/g"
                fi
            done

            ! printf "%s\n" "${output[@]}" | grep -q "#" && {
                getWidth "${output[1]}" "─" "└" "┘" ""
            }
        ;;
        "--square")

            output=$(
                printf "# %s #\n" "${raw[@]}" | column -t -s "#" -o "#"
            )
            getWidth "$output" "#" "#" "#" ""
            printf "%s\n" "$output"
            getWidth "$output" "#" "#" "#" ""
        ;;
        *)
            printf "INVALID OPTION FOR THE 'renderTraces' FUNCTION!!!\n"
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
    getWidth "$banner" "─" "├" "┤" "[ Alpha - v0.3.1 $warning]"
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
            opt1="[1]: ROLLBACK EVERYTHING!"
            opt2="[2]: ALRIGHT, COMMIT AS IT IS."
            opt3="[3]: LET ME SEE THE DAMN LOG FILE!"

            clear
            cat "$NOW"_log.txt
        
            renderTraces "--table" "HOW DO YOU WANT TO PROCEED?" 2

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