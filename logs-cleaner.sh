#!/bin/bash

TITLE="Logs Cleaner"
VERSION=1.0
RELEASE_DATE="22/10/2025"
AUTHOR="ElSutien"

# CONFIG CONSTANTS
LOG_PATH="/var/log/freeradius/radacct"  #Path of logs
THRESHOLD="80"   #Maximum percentage of used space to trigger erase proccess


# FUNCTION get percentage of used space for logs disk
# Returns 0 for success; 1 for failure
# Echoes number of percentage (w/o percentage symbol)
function getUsedDiskTotal () {
  df -h ${LOG_PATH} | tail -n1 | awk '{print $5}' | sed 's/%//' && return 0 || return 1
}



# FUNCTION get a List of files ordered by age (older first) from PWD
# Params:
#   1: varname for the list to be populated. Each element has only the path of the file.
# Returns: 0 for success; 1 for failure
function getFilesByAge () {
  local fileL=$(find . -type f)
  local fileRawL=""
  
  while IFS= read -r iwline; do
    fdate=$(date -r "$iwline" "+%s")
    [ -n "$fileRawL" ] && fileRawL+=$'\n'
    fileRawL+="$fdate $iwline"
  done <<<"$fileL"
  
  local tmp=$(echo "$fileRawL" | sort -g | awk '{print $2}')
  
  eval $1="\"$tmp\""
}




function main () {
  #Check if space if above limit
  
  local actdu=$(getUsedDiskTotal)  #Get actual disk usage
  [ $? -ne 0 ] && echo "ERROR: could not fetch disk usage" && return 1
  
  echo "Used space: ${actdu}%"
  
  if [ $actdu -lt ${THRESHOLD} ]; then  #If usage is below limit, exit
    echo "Disk is not above limit (${actdu}%). Refusing to clean logs."
    return 0
  fi
  
  pushd $LOG_PATH || exit 100  #Move to directory
  
  #Get file list (can take few minutes)
  local fileList
  getFilesByAge fileList
  
  local flag=1
  
  while [ $flag -eq 1 ]; do
    local aux=$(echo "$fileList" | head -n5) #Get first 5 files
    fileList=$(echo "$fileList" | tail -n+6) #Remove choosen files from list
    echo "+ Deleting: $aux"
    rm $aux
    
    actdu=$(getUsedDiskTotal)
    echo "+ Used space after removal: ${actdu}%"
    if [ $actdu -lt ${THRESHOLD} ]; then
      echo "Reached under-space limit target (${actdu}%)"
      flag=0
    fi
  done
  
  exit 0
}





main
exit $?