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

    local code=$1
    local input=$2
    local middle=$3
    local lateral=$4
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
   
    # ├
    # ┤
    # └
    # ┘
    # ┌
    # ┐
    # ─
    case $code in
        "1")

            wid=$(printf "%s\n" "$head" | wc -L)
            calc=$(( ( lineWidth - wid ) / 2 ))

            line=$(
                printf "%0.s " $(seq 0 $(( $calc - 3 ))) | sed "s/ /$middle/g" 
                printf "%s" "$head"
                printf "%0.s " $(seq 0 $(( $calc - 3 ))) | sed "s/ /$middle/g" 
            )

        ;;
        "2")

        ;;
        "3")

        ;;
        "4")
            
        ;;
        *)
            printf "TESTE!\n"
        ;;
    esac

    printf "%s\n" "$line"

    # printf "┌"
    # printf "%0.s─" $(seq 0 $(( $lineWidth - 4 )))
    # printf "┐\n"
    # printf "├"
    # printf "%0.s─" $(seq 0 $(( $lineWidth - 4 )))
    # printf "┤\n"

    # printf "└"
    # printf "%0.s─" $(seq 0 $(( $lineWidth - 4 )))
    # printf "┘\n"

    # wid=$(printf "%s\n" "$head" | wc -L)
    # calc=$(( ( lineWidth - wid ) / 2 ))
}


function table(){

	local raw=$1
    local code=$2

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
                    half1[count1]=$(printf " %s \n" "${output[i]}")
                    ((count1++))
                elif (( $i >= ((${#output[@]} - 2)) )); then
                    half2[count2]=$(printf " %s \n" "${output[i]}")
                    ((count2++))
                fi
            done

            tab1=$(printf "%s\n" "${half1[@]}" | column -t -s ' ' -o ' │ ' | sed 's/^ \+//')
            tab2=$(printf "%s\n" "${half2[@]}" | sed 's/^ \+//')
            header=$(printf "%s\n" "$tab2" | awk 'NR==1 { print $0 }' | sed 's/ //g')


            # printf "%s\n" "$tab1"
            getWidth 1 "$tab1" "─" "│" "$header"
            # local code=$1
            # local input=$2
            # local middle=$3
            # local lateral=$4
            # local head=$5
            

        ;;


        *)


        ;;


    esac


	# printf "┌──────┐\n"
    # printf "├──────┤\n"
	# printf "│		 │"
    # printf "└──────┘\n"
}