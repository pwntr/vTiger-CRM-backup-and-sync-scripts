#!/bin/bash

#######################
#  cleaner.sh
#  by imperialWicket
#
#  version 1.0.1
#######################

# cleaner usage function
usage()
{
cat << EOF
cleaner.sh 

This script cleans directories.  It is useful for backup 
and log file directories, when you want to delete older files. 

USAGE:  cleaner.sh [options]

OPTIONS:
   -h      Show this message
   -q      This script defaults to verbose, use -q to turn off messages 
           (Useful when using the cleaner.sh in automated scripts).
   -s      A search string to limit file deletion, defaults to '*' (All files).
   -m      The minimum number of files required in the directory (Files 
           to be maintained), defaults to 5.
   -d      The directory to clean, defaults to the current directory.
   
EXAMPLES: 
   In the current directory, delete everything but the 5 most recently touched 
   files: 
     cleaner.sh
         Same as:
     cleaner.sh -s * -m 5 -d .
   In the /home/myUser directory, delete all files including text "test", except 
   the most recent:
     cleaner.sh -s test -m 1 -d /home/myUser
         Don't ask for any confirmation:
     cleaner.sh -s test -m 1 -d /home/myUser -q              
EOF
}

# Set default values for VARS
SEARCH_STRING='*'
MIN_FILES='5'
DIR='.'
QUIET=0
DELETED=0

# cleaner delete files function
delete()
{
FILES=`ls -1p "$SEARCH_STRING"* 2>/dev/null | grep -vc "/$"`


while [ $FILES -gt $MIN_FILES ]
do
  ls -tr "$SEARCH_STRING"* 2>/dev/null | head -1 | xargs -i rm {}
  FILES=`ls -1p "$SEARCH_STRING"* 2>/dev/null | grep -vc "/$"`
  let "DELETED+=1"
done
}

# cleaner set args and handle help/unknown arguments with usage() function
while getopts  ":s:m:d:qh" flag
do
  #echo "$flag" $OPTIND $OPTARG
  case "$flag" in
    h)
      usage
      exit 0
      ;;
    q)
      QUIET=1
      ;;  
    s)
      SEARCH_STRING=$OPTARG
      ;;
    m)
      MIN_FILES=$OPTARG
      ;;
    d)
      DIR=$OPTARG
      ;;
    ?)
      usage
      exit 1
  esac
done

# cleaner change to requested directory and perform delete with or without verbosity
cd $DIR
CONFIRM_FILES=`ls -1p "$SEARCH_STRING"*`

if [ $QUIET = 0 ]
then
	if [ $MIN_FILES = 0 ]
	then 
	  echo 'Delete the following files (y/n)?'
	else
	  echo Delete the following files except the $MIN_FILES 'most recently touched (y/n)?' 
	fi

	echo $CONFIRM_FILES
	read CONFIRM

	if [ $CONFIRM = y ] || [ $CONFIRM = Y ] || [ $CONFIRM = YES ] || [ $CONFIRM = yes ] || [ $CONFIRM = Yes ]
	then
	  delete
	  if [ $DELETED = 1 ]
	  then
		TEXT='file.'
	  else
		TEXT='files.'
	  fi
	  echo Removed $DELETED $TEXT
	else
	  echo Cleaner canceled.
	fi
else
	delete
fi

# cleaner change back to the original directory
cd $OLDPWD
exit 0
