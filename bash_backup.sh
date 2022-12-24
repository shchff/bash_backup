#!/bin/bash

#функция, которую вызывают при ошибке в пути
function pathError {
	echo Wrong path
	exit 2
}

#функция вызова help
function help {
	echo
	echo —---------------------------------------------------------
	echo This is help about using bash_backup
	echo This program makes a backup of files with certain extention
	echo from the specified path and saves it to the specified path
	echo You need to write a string like:
	echo bash_backup.sh [fromPath] [extention] [toPath] [keys]
	echo
	echo [keys]:
	echo -e "\t-h, —help: describes the usage of this program"
	echo
	echo -e "\t-p [n], —period [n]: sets a period in minutes for"
	echo -e "\tcreating backups. [n] must be > 0 or == -1. If the"
	echo -e "\tvalue of [n] == -1, the period will be cleared."
	echo
	echo -e "\t-i, —integrity": not only creating backup tar, but
	echo -e "\tchecking it's control sum too"
	echo
	echo -e "\t-a [n], —amount [n]: if the amount of backups is"
	echo -e "\talready [n], the program deletes the oldest ones"
	echo -e "\t[n] must be > 0"
	echo —---------------------------------------------------------
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

#заполняем массив ключей
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

#выставляем значения переменных ключей
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

#создаём временную директорию, в которой будем хранить временные файлы
mkdir temp
dirTemp=$PWD/temp

#создаём директорию, в которой будем хранить файлы для архивирования
mkdir "$dirTemp/tar"

#переходим в директорию, куда будем сохранять архив
cd "$toPath" || pathError

#этот участок кода удаляет старые архивы, если их количество больше maxAmount
if [[ $maxAmount != 0 ]]; then
	backups=($(find "$toPath" -maxdepth 1 -type f -name "backup_??????????????.tar" | LC_TIME=C sort)) #массив архивов в toPath, отсортированный по дате
	backupsAmount=${#backups[@]} #их количество
	if [[ $backupsAmount -ge $maxAmount ]]; then
	countDeleted=0
	#удаляем лишние до тех пор, пока их не будет maxAmount
		for b in ${backups[*]}; do
			rm "$b"
			countDeleted=$((countDeleted + 1))
			if [[ $countDeleted -ge $((backupsAmount - maxAmount + 1)) ]]; then
				break
			fi
		done
	fi
fi

#crontab - таблица планирования, "демон", текущие задачи можно посмотреть, написав crontab -l
if [[ $period == "-1" ]]; then
	crontab -r #очищаем период
	echo Period is cleared
	rm -rf "$dirTemp"
	exit 0
elif [[ $period -gt 0 ]]; then
	#формируем строку для вызова
	string="$PWD/bash_backup.sh $fromPath $extention $toPath"
	if [[ $maxAmount -gt 0 ]]; then
		string+=" -a $maxAmount"
	fi
	if [[ $integrityChecker == 1 ]]; then
		string+=" -i"
	fi
	#записываем в cron период создания архива в минутах и строку
	echo "*/$period * * * * $string" » "$dirTemp"/cronTemp.txt
	crontab "$dirTemp"/cronTemp.txt
	rm -rf "$dirTemp"
	echo "Period is setted in $period minutes"
	exit 0
elif [[ $period == 0 ]]; then
	period=0
else
	echo Error of period value
	echo Check —help for available values of period
	rm -rf "$dirTemp"
	exit 2
fi

#во временной папке создаём файл, куда будем записывать названия файлов и файл с контрольной суммой, если необходимо
touch "$dirTemp"/files.txt
if [[ $integrityChecker == 1 ]]; then
	touch "$dirTemp"/check_sum.txt
fi

#переходим в директорию, откуда берём файлы для бэкапа
cd "$fromPath" || pathError

has=0
for o in *; do #пробегаем всем объектам директории
	if [[ -f "$o" ]] && [[ $extention == ".${o##*.}" ]]; then #если объект является файлом и у него нужное нам расширение, то заносим его в список
		echo "$o" » "$dirTemp"/files.txt
		if [[ $has == 0 ]]; then #если такие файлы есть, то потом при проверке код будет работать, елси нет, то программа прервётся
			has=1
		fi
	fi
done

#проделываем то же самое, если нужна контрольная сумма, но один раз, так как она одинаковая у всех файлов, md5sum делает её
if [[ $integrityChecker == 1 ]]; then
	for o in *; do
		if [[ -f "$o" ]] && [[ $extention == ".${o##*.}" ]]; then
			md5sum "$o" » "$dirTemp"/check_sum.txt
			break
		fi
	done
fi

if [[ $has == 0 ]]; then #вышеупомянутый вылет
	echo No files with this extantion
	rm -rf "$dirTemp"
	exit 1
fi

#tar создаёт архив
currTime="$(date +%Y%m%d%H%M%S)" #время для названия
tar -c -f "$toPath/backup_$currTime.tar" -T "$dirTemp"/files.txt #cоздаёт архив со временем в названии извлекая названия из file.txt
tar -C "$dirTemp/tar" -x -f "$toPath/backup_$currTime.tar" #сменяет директорию на папку с файлами для архивации и извлекая их по названиям кладёт .tar

#проверка контрольной суммы
if [[ $integrityChecker == 1 ]]; then
	damaged=0
	sumOfFiles=$(cat "$dirTemp"/check_sum.txt) #изначально подсчитанная сумма
	for f in "$dirTemp"/tar/*; do #проверка для каждого файла в архиве
		sum=($(md5sum "$f")) #сумма файла
		if [[ "$sumOfFiles" != *"${sum[0]}"* ]]; then #если суммы не равны, то устанавливаем флаг, который потом будет проверяться в условии
			if [[ $damaged == 0 ]]; then
				damaged=1
				break
			fi
		fi
	done
	if [[ $damaged == 1 ]]; then #вышеупомянутое условие
		echo Fail in calculating sums. Some file is damaged
		rm -rf "$dirTemp"
		exit 1
	fi
	echo The sum is right
fi

echo The tar is made succesfully
rm -rf "$dirTemp"
exit 0
