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

    local line=""
    lineWidth=$(printf "%s\n" "${array[@]}" | sed 's/\x1b\[[0-9;]*m//g' | wc -L)

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
    getWidth "$banner" "─" "├" "┤" "[ Automated Snapshot & Recovery Manager ]"
    getWidth "$banner" "─" "├" "┤" "[ v1.0.0 ]"
    getWidth "$banner" "─" "└" "┘" ""

    printf "${reset}"

}
function table(){

	local raw=$1
    local code=$2

    case $code in
        "1")

            raw=(`printf "%s\n" "$raw" | sed 's/^ \+//'`)

            output=(`
                for i in "${raw[@]}"; do
                    printf "%s\n" "$i"
                done
            `)
            main=$(printf "%s\n" "${output[@]:0:${#output[@]}-1}")

            final=$(
                if grep -qi "impossible" <<< "$main"; then
                    printf "┤ \e[41m\e[30m%s\e[0m ├" "${output[-1]}"
                else
                    printf "┤ \e[42m\e[30m%s\e[0m ├" "${output[-1]}"
                fi
            )
            getWidth "$main" "─" "┌" "┐" "" 
            printf "%s\n" "$main"
            getWidth "$main" "─" "├" "┤" "" 
            getWidth "$main" "─" "├" "┤" "$final"
            getWidth "$main" "─" "└" "┘" ""

        ;;
        2)  
            raw=$(
            printf "%s\n" "$raw" \
                | sed -e 's/^/ /' -e '/^$/d' \
                | column -t -s ' ' -o ' │ ' \
                | sed 's/^ \+//'
            )
            
            mapfile -t -d "+" output < <(
                printf "%s\n" "$raw"
            )

            mapfile -t pv < <(
                printf "%s\n" "${output[0]}" | sed -e '/^$/d' | grep -v "="
            )
            
            mapfile -t vg < <(
                printf "%s\n" "${output[1]}" | sed -e '/^$/d' | grep -v "="
            )
            mapfile -t lv < <(
                printf "%s\n" "${output[2]}" | sed '/^$/d' | grep -v "="
            )

            tab1=$(
                (
                    for ((i=0;i<${#pv[@]};i++)); do
                        printf "%s\n" "${pv[i]}"
                    done
                ) | sed 's/^ \+//'
            ) 
            tab2=$(
                (
                    for ((i=0;i<${#vg[@]};i++)); do
                        printf "%s\n" "${vg[i]}"
                    done
                ) | sed 's/^ \+//'
            )
            tab3=$(
                (
                    for ((i=0;i<"${#lv[@]}";i++)); do
                        printf " %s \n" "${lv[i]}"
                    done
                ) | sed 's/^ \+//'
            )

            getWidth "$tab1" "─" "┌" "┐" "PHYSICAL_VOLUME(S)"
            printf "%s\n" "$tab1"
            getWidth "$tab2" "─" "├" "┤" "VOLUME_GROUP(S)"
            printf "%s\n" "$tab2"
            getWidth "$tab3" "─" "├" "┤" "LOGICAL_VOLUME(S)"
            printf "%s\n" "$tab3"
            getWidth "$tab1" "─" "└" "┘" ""

        ;;
        3)
            
            raw=(`echo "$raw" | sed 's/^ \+//'`)
            printf "\u001b[36m"

			formated=$(
				for i in ${raw[@]}; do
					printf "#%s#\n" "$i"
				done
			)

			message=$(
				printf "%s\n" "$formated" | column -t -s '#' -o ' # ' | sed 's/^ \+//'
			)

			getWidth "$message" "#" "#" "#" ""
			printf "%s\n" "$message"
			getWidth "$message" "#" "#" "#" ""
            printf "\u001b[0m"


        ;;

        *)
            printf "INVALID OPTION!!!\n"

        ;;

    esac

	# printf "┌──────┐\n"
    # printf "├──────┤\n"
	# printf "│		 │"
    # printf "└──────┘\n"
}

function choose(){

	local input=$1
    local warning=""
	local green="\u001b[30;42m"
	local reset="\e[0m"
    option=1

    (( $DEBUG == "1" )) && warning="THE DEBUG MODE IS ON!"
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
			printf "%s\n" "$warning"

            while true; do
                [ $option -eq 1 ] && \
                printf "${green}[ $opt1 ]${reset}\n[ $opt2 ]\n[ $opt3 ]\n[ $opt4 ]\n[ $opt5 ]\n"
                [ $option -eq 2 ] && \
                printf "[ $opt1 ]\n${green}[ $opt2 ]${reset}\n[ $opt3 ]\n[ $opt4 ]\n[ $opt5 ]\n" 
                [ $option -eq 3 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n${green}[ $opt3 ]${reset}\n[ $opt4 ]\n[ $opt5 ]\n" 
                [ $option -eq 4 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n[ $opt3 ]\n${green}[ $opt4 ]${reset}\n[ $opt5 ]\n" 
                [ $option -eq 5 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n[ $opt3 ]\n[ $opt4 ]\n${green}[ $opt5 ]${reset}\n" 

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
            cat "$TODAY"_log.txt
            
            table "WHICH OPTION DO YOU WANT TO CHOOSE?" 3

            while true; do
                [ $option -eq 1 ] && \
                printf "${green}[ $opt1 ]${reset}\n[ $opt2 ]\n[ $opt3 ]\n"
                [ $option -eq 2 ] && \
                printf "[ $opt1 ]\n${green}[ $opt2 ]${reset}\n[ $opt3 ]\n" 
                [ $option -eq 3 ] && \
                printf "[ $opt1 ]\n[ $opt2 ]\n${green}[ $opt3 ]${reset}\n" 
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
            printf "INVALID OPTION!!!\n"
        ;;
    esac

	unset output
    unset input
}