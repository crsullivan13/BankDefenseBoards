#!/bin/bash

set -euo pipefail

. ./functions

OUT1=outputs/attack/sepbanksW-slowdown.csv
OUT2=outputs/attack/sepbanksW-bw.csv
OUT3=outputs/attack/sepbanksW-llc.csv

victimSizes=(64 128 192 256 320 512)
victimIterations=50000
victimTypes=read
victimCore=3
victimBank=0

attackerSize=128

declare -a slowdowns
declare -a bw
declare -a missrate

windowSize=$1

declare -a bwsolo
declare -a bwdiff
declare -a bwsame
declare -a llcsolo
declare -a llcdiff
declare -a llcsame

index=0
for victimSize in ${victimSizes[@]}; do
    slowdowns[$index]+="$victimSize "
    slowdowns[$index]+="1.00 "

    bw[$index]+="$victimSize "
    missrate[$index]+="$victimSize "

    echo "Type,BW,Slowdown,LLC_Access,LLC_Miss,LLC_Missrate"

    for ((test=1; test<=$windowSize; test++)); do
	echo "Iteration $test"
   	BkPLLSolo $victimCore $victimSize $victimTypes $victimIterations $victimBank
	bwsolo[$test]=$solo
	llcsolo[$test]=$l2missrate

    	#Attackers on different bank than victim
    	BkPLLWriteAttackers $attackerSize 1
    	sleep 3
    	BkPLLCorun $victimCore $victimSize $victimTypes $victimIterations $victimBank
	bwdiff[$test]=$slow
	llcdiff[$test]=$l2missrate
    	killall $BKPLL
    	wait &> /dev/null

    	#Attackers on same bank as victim
    	BkPLLWriteAttackers $attackerSize $victimBank
    	sleep 3
    	BkPLLCorun $victimCore $victimSize $victimTypes $victimIterations $victimBank
	bwsame[$index]=$slow
	llcsame[$index]=$l2missrate
    	killall $BKPLL
    	wait &> /dev/null

    	#sleep 3
    done


    #get medians
    solobw=$(echo "${bwsolo[@]}" | xargs -n1  | sort -n | datamash median 1) 
    samebw=$(echo "${bwsame[@]}" | xargs -n1  | sort -n | datamash median 1) 
    diffbw=$(echo "${bwdiff[@]}" | xargs -n1  | sort -n | datamash median 1) 

    #calc slowdown
    slowdowns[$index]+="$(bc <<< "scale=2; $solobw/$diffbw") "
    slowdowns[$index]+="$(bc <<< "scale=2; $solobw/$samebw") "

    unset sameslow
    unset diffslow

    bw[$index]+="$solobw "
    bw[$index]+="$diffbw "
    bw[$index]+="$samebw "

    unset bwsolo
    unset bwsame
    unset bwdiff    

    missrate[$index]+="$(echo "${llcsolo[@]}" | xargs -n1  | sort -n | datamash median 1) "
    missrate[$index]+="$(echo "${llcdiff[@]}" | xargs -n1  | sort -n | datamash median 1) "
    missrate[$index]+="$(echo "${llcsame[@]}" | xargs -n1  | sort -n | datamash median 1) "

    unset llcsolo
    unset llcdiff
    unset llcsame

    index=$((index+1))

    echo ""
done

> $OUT1
> $OUT2
> $OUT3

echo "WSS,Solo,DiffBank,SameBank" >> $OUT1
echo "WSS,SoloBW,DiffBankBW,SameBankBW" >> $OUT2
echo "WSS,SoloMissRate,DiffMissRate,SameMissRate" >> $OUT3

for out in "${slowdowns[@]}"; do
    printf '%s\n' $out | paste -sd ',' >> $OUT1
done

for out in "${bw[@]}"; do
    printf '%s\n' $out | paste -sd ',' >> $OUT2
done

for out in "${missrate[@]}"; do
    printf '%s\n' $out | paste -sd ',' >> $OUT3
done
