#!/bin/bash

function pathError {
	echo Wrong path
	exit 2
}

function help {
   echo
	echo -----------------------------------------------------------
   echo This is help about using bash_backup
	echo This program creates a backup of files with certain extention 
	echo from the specified path and saves it to the specified path
	echo You need to write a string like:
	echo bash_backup.sh [fromPath] [extention] [toPath] [keys]
	echo
	echo [keys]:
	echo -e "\t-h, --help: describes the usage of this program"
	echo
	echo -e "\t-p [n], --period [n]: sets a period in minutes for"
	echo -e "\tcreating backups. [n] must be > 0 or == -1. If the"
	echo -e "\tvalue of [n] == -1, the period will be cleared."
	echo
	echo -e "\t-i, --integrity: not only creating backup tar, but" 
   echo -e "\tchecking it's control sum too"
	echo	
	echo -e "\t-a [n], --amount [n]: if the amount of backups is"
	echo -e "\talready [n], the program deletes the oldest ones"
	echo -e "\t[n] must be > 0"
	echo -----------------------------------------------------------
	echo

	exit 1
}



fromPath=$1
extention=$2
toPath=$3
keys=()

if [[ $* == "-h" || $* == "--help" ]]; then
	help
fi

n=0
for i in "${@}"; do
	n=$((n+1))
	if [[ $n -ge 4 ]]; then
		keys[n-4]=$i
	fi
done

keysLen=${#keys[*]}

maxAmount=0
period=0
integrityChecker=0

if [[ $keysLen != 0 ]]; then
	for ((i=0; i<=$keysLen; i++)); do
		if [[ ${keys[$i]} == '-a' || ${keys[$i]} == '--amount' ]]; then
			if ! [[ "${keys[$i+1]}" =~ ^[0-9]+$ ]]; then
				echo "Amount of available backups must be a number"
				exit 2
			fi
			maxAmount=${keys[$i+1]}
		elif [[ ${keys[$i]} == '-p' || ${keys[$i]} == '--period' ]]; then
			if ! [[ ${keys[$i+1]} =~ ^[0-9]+$ || ${keys[$i+1]} == "-1" ]]; then
            echo "Period must be a number"
            exit 2
                        fi      
                        period=${keys[$i+1]}
		elif [[ ${keys[$i]} == '-i' || ${keys[$i]} == '--integrity' ]]; then
			integrityChecker=1
      fi  
	done	
fi

mkdir temp
dirTemp=$PWD/temp
mkdir "$dirTemp/tar"

cd "$toPath" || pathError
if [[ $maxAmount != 0 ]]; then
   backups=($(find "$toPath/" -maxdepth 1 -type f -name "backup_*.tar" | LC_ALL=C sort))
	backupsAmount=${#backups[*]}
   if [[ $backupsAmount -ge $maxAmount ]]; then
      countDeleted=0
      for b in $backups; do
         rm "$b"
         if [[ $countDeleted -ge $((backupsAmount - maxAmount)) ]]; then
   	         break
         fi
         countDeleted=$((countDeleted + 1))
      done
   fi
fi


if [[ $period == "-1" ]]; then
	crontab -r
	echo Period is cleared
	rm -rf "$dirTemp"
	exit 0
elif [[ $period -gt 0 ]]; then
	string="$PWD/bash_backup.sh $fromPath $extention $toPath"
	if [[ $maxAmount -gt 0 ]]; then
		string+=" -a $maxAmount"
	fi
	if [[ $integrityChecker == 1 ]]; then
		string+=" -i"
	fi
	echo "*/$period * * * * $string" >> "$dirTemp"/cronTemp.txt
	crontab "$dirTemp"/cronTemp.txt
	rm "$dirTemp"/cronTemp.txt	
	echo "Period is setted in $period minutes"
	exit 0
elif [[ $period == 0 ]]; then
	period=0	
else
	echo Error of period value 
	echo Check --help for available values of period
	rm -rf "$dirTemp"
	exit 2
fi


touch "$dirTemp"/files
if [[ $integrityChecker == 1 ]]; then
	touch "$dirTemp"/check_sum
fi

cd "$fromPath" || pathError

has=0
for f in *; do
	fileExt=${f##*.}
	if [[ -f  "$f" ]] && [[ $extention == .$fileExt ]]; then
		echo "$f" >> "$dirTemp"/files
		has=1
	fi
done

if [[ $integrityChecker == 1 ]]; then
	for f in *; do
   	fileExt=${f##*.}
      if [[ -f  "$f" ]] && [[ $extention == .$fileExt ]]; then      
                        md5sum "$f" >> "$dirTemp"/check_sum
               break
      fi
	done
fi


if [[ $has == 0 ]]; then
	echo No files with this extantion
	rm -rf "$dirTemp"
	exit 1
fi

currTime="$(date +%Y%m%d%H%M%S)"
tar -cf "$toPath/backup_$currTime.tar" -T "$dirTemp"/files
tar -C "$dirTemp/tar" -xf "$toPath/backup_$currTime.tar"


if [[ $integrityChecker == 1 ]]; then
	sumOfFiles=$(cat "$dirTemp"/check_sum)
	for f in "$dirTemp"/tar/*; do
		sum=($(md5sum "$f"))
		if [[ "$sumOfFiles" != *"$sum"* ]]; then
			echo Fail in calculating sums
			rm -rf "$dirTemp"
			exit 2
		fi
	done
	echo The sum is right
fi

echo The tar is made succesfully
rm -rf "$dirTemp"
exit 0
