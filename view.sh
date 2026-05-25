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

getWidth(){

    local input=$1
    local middle=$2
    local lateralLeft=$3
    local lateralRight=$4
    local head=$5

    local array=(`printf "%s\n" "$input"`)

    # pra pegar a largura de uma tabela crua de forma dinâmica
    # for ((i=0;i<"${#array[@]}";i++)); do 

    #     lineWidth=$(printf "%s\n" "${array[i]}" | wc -L)
    # done
   
    #CONSIDERAR A LARGURA DO CABEÇALHO PARA CASO DO TAMANHO DA LARGURA SER IMPAR OU PAR.

    local line=""
    lineWidth=$(printf "%s\n" "${array[@]}" | wc -L)

    if (( $lineWidth <= 0 )); then
        printf "The width must not be null!\nYou either didn't insert a input or the calculation is wrong!\n"
        exit
    fi
   
    
    [[ ! -z $input ]] && { 
        wid=$(printf "%s\n" "$head" | wc -L)
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

    # CÓDIGOS: 
    # 1) output vindo da função 'snapshotViability' do arquivo 'lvm.sh'
    # 2) output vindo da função 'fetchVolumes' do 'lvm.sh'

    case $code in
        "1")

            declare -a half1
            declare -a half2

            output=(`printf "%s\n" "$raw" | sed 's/^ \+//'`)
            count1=0
            count2=0

            for ((i=0;i<${#output[@]};i++)); do

                if (( $i < ((${#output[@]} - 2)) )); then
                    half1[count1]=$(printf " %s \n" "${output[i]}")
                    ((count1++))
                elif (( $i >= ((${#output[@]} - 2)) )); then
                    half2[count2]=$(printf " %s \n" "${output[i]}")
                    ((count2++))
                fi
            done

            tab1=$(printf "%s\n" "${half1[@]}" | column -t -s ' ' -o ' │ ' | sed 's/^ \+//')
            tab2=$(printf "%s\n" "${half2[@]}" | sed 's/^ \+//')
            header1=$(printf "%s\n" "$tab2" | awk 'NR==1 { print $0 }' | sed "s/ //g")
            header2=$(printf "%s\n" "$tab2" | awk 'NR==2 { print $0 }' | sed "s/ //g")

            ( 
                getWidth "$tab1" "─" "┌" "┐" ""
                printf "%s\n" "$tab1"
                getWidth "$tab1" "─" "├" "┤" "$header1"
                getWidth "$tab1" " " "│" "│" "$header2"
                getWidth "$tab1" "─" "└" "┘" "" 
            )

        ;;
        2)  
            raw=$(printf "%s\n" "$raw" | sed -e '/^$/d' -e 's/^ \+//')
            
            mapfile -t -d "+" output < <(
                printf "%s\n" "$raw"
            )

            mapfile -t pv < <(
                printf "%s\n" "${output[0]}" | sed -e '/^$/d'
            )
            mapfile -t vg < <(
                printf "%s\n" "${output[1]}" | sed -e '/^$/d'
            )
            mapfile -t lv < <(
                printf "%s\n" "${output[2]}" | sed '/^$/d'
            )

            tab1=$(
                (
                    for ((i=0;i<${#pv[@]};i++)); do
                        printf " %s \n" "${pv[i]}"
                    done
                ) | column -t -s ' ' -o ' │ ' | sed 's/^ \+//'
            ) 
            tab2=$(
                (
                    for ((i=0;i<${#vg[@]};i++)); do
                        printf " %s \n" "${vg[i]}"
                    done
                ) | column -t -s ' ' -o ' │ ' | sed 's/^ \+//'
            )
            tab3=$(
                (
                    for ((i=0;i<${#lv[@]};i++)); do
                        printf " %s \n" "${lv[i]}"
                    done
                ) | column -t -s ' ' -o ' │ ' | sed 's/^ \+//'
            ) 

            getWidth "$tab1" "─" "┌" "┐" "PHYSICAL VOLUME(S)"
            printf "%s\n" "$tab1"
            getWidth "$tab1" "─" "├" "┤" "VOLUME GROUP(S)"
            printf "%s\n" "$tab2"
            getWidth "$tab1" "─" "├" "┤" "LOGICAL VOLUME(S)"
            printf "%s\n" "$tab3"
            getWidth "$tab1" "─" "└" "┘" ""

        ;;
        3)

        ;;


        *)


        ;;


    esac

	# printf "┌──────┐\n"
    # printf "├──────┤\n"
	# printf "│		 │"
    # printf "└──────┘\n"
}