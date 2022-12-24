# bash_backup

Comments are written in Russian

This is help about using bash_backup
This program creates a backup of files with certain extention 
from the specified path and saves it to the specified path
You need to write a string like:
bash_backup.sh [fromPath] [extention] [toPath] [keys]

	[keys]:

  	-h, --help: describes the usage of this program
	
  	-p [n], --period [n]: sets a period in minutes for
	creating backups. [n] must be > 0 or == -1. If the
	value of [n] == -1, the period will be cleared.
	
	-i, --integrity: not only creating backup tar, but
  	checking it's control sum too
  
	-a [n], --amount [n]: if the amount of backups is
	already [n], the program deletes the oldest ones
	[n] must be > 0
