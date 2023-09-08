#!/bin/env bash
# shellcheck disable=SC2059

trap '_error_ $? $LINENO' ERR


declare -A LXDTOOLS_KEYWORD
declare -A LXDTOOLS_VAR  
#declare -A LXDTOOLS_ENV

readonly LXDREMOTE=/usr/local/bin/lxdtools/lxdremote.sh

# https://www.shellhacks.com/bash-colors/
readonly TEXT_RED="\e[31m"
readonly TEXT_GREEN="\e[32m"
readonly TEXT_NORMAL="\e[0m"

# Mapping from our commands to the real LXD CLI commands
readonly LXDTOOLS_KEYWORD=( 
[START]="lxc start" 
[STOP]="lxc stop" 
[RESTART]="lxc restart" 
[DELETE]="lxc delete" 
[RESTORE]="lxc restore" 
[RUN]="lxc run" 
[INIT]="lxc init" 
[LAUNCH]="lxc launch" 
[STORAGE]="lxc storage" 
[CONFIG]="lxc config" 
[DEVICE]="lxc config device" 
[NETWORK]="lxc network" 
[PROFILE]="lxc profile" 
[PUSH]="lxc file push" 
[PULL]="lxc file pull" 
[COPY]="lxc copy" 
[MOVE]="lxc move" 
[EXEC]="lxc exec"
[INFO]="lxc info"
[LIST]="lxc list"
[SNAPSHOT]="lxc snapshot"
[APPENDIT]="lxc exec"
)

#[SLEEP]="SLEEP" 
#[LOG]="LOG" 
#[EXIT]="EXIT" 
#[BEGIN]="BEGIN" 
#[END]="END" 

# VARIABLES
LXDTOOLS_VAR=( 
[DIALECT]=1 
[LOGLEVEL]=1 
[VERBOSE]=1 
[LOG_PRINT_TIMESTAMP]=1 
[LOG_PRINT_LOGLEVEL]=0 
[CONTAINER]=""
[STARTTIME]=0
[SPLITTIME]=0
[ENDTIME]=0
[STATUS]=0
)

LXDTOOLS_TEXT=( 
[TOTAL_TIME]="Total Time: {{TIMER-TOTAL}}s"
[SPLIT_TIME]="Time: Split: {{TIMER-SPLIT}}s Total: {{TIMER-TOTAL}}s"
[SLEEPING]="Sleeping: {{SLEEP}}s"
[EXITING]="Exiting: Status: {{STATUS}} {{MSG}}"
[STATUS]="Status: {{STATUS}}"
)

# Set environment variables
#LXDTOOLS_ENV=(
#[HOSTNAME]="$(hostname)"
#)

LXDTOOLS_HOSTNAME="$(hostname)"
export LXDTOOLS_HOSTNAME

################################################################################
#  ___       _                        _ 
# |_ _|_ __ | |_ ___ _ __ _ __   __ _| |
#  | || '_ \| __/ _ \ '__| '_ \ / _` | |
#  | || | | | ||  __/ |  | | | | (_| | |
# |___|_| |_|\__\___|_|  |_| |_|\__,_|_|
#  
################################################################################

function _error_
{
   local errno=$1
   local line=$2

   printf "${TEXT_RED}" >&2
   printf "Error %s at line %d\n" "${errno}" "${line}" >&2

   local i=0
   local line_no
   local function_name
   local file_name
   while caller $i ;do ((i++)) ; done | while read -r line_no function_name file_name;do echo -e "\t$file_name:$line_no\t$function_name" ;done >&2

   printf "${TEXT_NORMAL}" >&2
}



################################################################################
function _log_
################################################################################
(
   local loglevel=$1
   local msg=$2
   local date

   if (( loglevel > LXDTOOLS_VAR[LOGLEVEL] )); then
      return
   fi

   date=$(date --rfc-3339=ns)

   if (( LXDTOOLS_VAR[LOG_PRINT_TIMESTAMP] == 1 )); then
      printf "%s " "${date}" >&2
   fi

   if (( LXDTOOLS_VAR[LOG_PRINT_LOGLEVEL] == 1 )); then
      printf "%s " "{${loglevel}}" >&2
   fi

   printf "%s\n" "${msg}" >&2
)

################################################################################
function _run_
################################################################################
{
   local func=$1
   shift
   #local PARAMS="$@"

   _log_ 1 "${func} $@"

   #local verbose
   local cmd
   #local status

#TODO
#   if (( LXDTOOLS_VAR[VERBOSE] == 1 )); then
#      verbose="-v"
#   else
#      verbose=""
#   fi

   # Find the real command prefix from the keyword provided
   if [[ -n "${LXDTOOLS_KEYWORD[${func}]}" ]]; then
   	cmd="${LXDTOOLS_KEYWORD[${func}]}"
   fi

   for P in "$@"
   do
      # Quote contents with spaces
      if [[ "${P}" == *" "* ]]; then
         P="\"${P}\""
      fi

      if [[ -z "${cmd}" ]]; then
      	cmd="${P}"
      else
      	cmd="$cmd $P"
      fi
   done

   _log_ 3 "${func} ${cmd}"

   # Capture output and trim leading/trailing space and blank lines (does not work!)
   OUT=$(eval "${cmd}" 2>&1 | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' | sed '/^$/d')
   LXDTOOLS_VAR[STATUS]=$?

   _log_ 2 "${func} Status: ${LXDTOOLS_VAR[STATUS]}"

   if [[ ${LXDTOOLS_VAR[STATUS]} -gt 0 ]]; then
	   printf "${TEXT_RED}"
	   printf "%s\n" "${OUT}"
	   printf "${TEXT_NORMAL}"
   fi

   if [[ ${LXDTOOLS_VAR[STATUS]} -eq 0 && ${LXDTOOLS_VAR[VERBOSE]} -eq 1 && -n "${OUT}" ]]; then
	   printf "${TEXT_GREEN}"
	   printf "%s\n" "${OUT}"
	   printf "${TEXT_NORMAL}"
   fi
}

################################################################################
function _hostrun_
################################################################################
{
   local func=$1
   shift
   local cmd="$*"
   #shift
   #local PARAMS="$@"

   _log_ 1 "$*"

   eval "${cmd}"
   LXDTOOLS_VAR[STATUS]=$?

   _log_ 2 "${func} Status: ${LXDTOOLS_VAR[STATUS]}"
}


################################################################################
function _runcontainer_
################################################################################
# Run commands that pass the container as the first or only parameter
# Allow the CONTAINER parameter to be optional and pick it up from the global
# CONTAINER variable if not provided
################################################################################
{
   local func=$1
   local container=$2

   if [[ $# -eq 1 ]]; then
      shift 1
   fi

   if [[ $# -ge 2 ]]; then
      shift 2
   fi

   if [[ -z "${container}" ]]; then
      if [[ -z "${LXDTOOLS_VAR[CONTAINER]}" ]]; then
         _exit_ 1 "CONTAINER variable not set"
      fi

      container=${LXDTOOLS_VAR[CONTAINER]}
   fi

   _log_ 1 "${func} $*"
   _run_ "${func}" "${container}" "$@"
}


###############################################################################
function _remote_
###############################################################################
{
   local func
   local container

   func="$1"
   container="$2"
   shift 2

   _log_ 1 "${func}" "lxc exec" "${container}" "--" "${LXDREMOTE}" "${func}" "$@"
   _run_ "${func}" lxc exec "${container}" "--" "${LXDREMOTE}" "${func}" "$@"
}


################################################################################
function _exit_
################################################################################
{
   local value=$1
   local msg=$2

   if [[ "${value}" -gt 0 ]]; then
   	printf "${TEXT_RED}" >&2
   else
   	printf "${TEXT_GREEN}" >&2
   fi

   _log_ 0 "${msg}"

   printf "${TEXT_NORMAL}"
   exit "${value}"
}


###############################################################################
function _replace_
###############################################################################
{
   local haystack=$1
   local needle=$2
   local replace=$3
   echo "${haystack//$needle/$replace}"
}


###############################################################################
function _isinteger_
###############################################################################
(
   local value=$1

   if [[ "${value}" =~ ^[0-9]*$ ]]; then
      echo 1
   else
      echo 0
   fi
)


###############################################################################
#   ____                                          _     
#  / ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |___ 
# | |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` / __|
# | |__| (_) | | | | | | | | | | | (_| | | | | (_| \__ \
#  \____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|___/
#                                                      
###############################################################################

function ASSIGN
{
   var=$1
   value=$2
   eval "$var=$value"
}

################################################################################
function SET
################################################################################
{
   # If the command is just SET and nothing else, dump all of the tokens
   if [ $# == 0 ]; then
      DUMP
      return
   fi

   local key
   local value
   
   key=$1
   value=$2

   _log_ 2 "${FUNCNAME[0]} $key $value"

   # Validate array key exists
   if [ ! -v "LXDTOOLS_VAR[$key]" ]; then
      _exit_ 1 "${FUNCNAME[0]}: Unknown parameter ${key}"
   else
      LXDTOOLS_VAR[$key]="$value"
   fi
}


################################################################################
function DUMP
################################################################################
{
   _log_ 2 "${FUNCNAME[0]} \n== Var Dump Start =="
   for key in "${!LXDTOOLS_VAR[@]}"; do
      printf "%-30s %s\n" "${key}" "${LXDTOOLS_VAR[$key]}"
   done
   _log_ 2 "${FUNCNAME[0]} \n== Var Dump End   =="
}


################################################################################
function SUCCESS
################################################################################
{
   if [[ ${LXDTOOLS_VAR[STATUS]} == 0 ]]; then
      return 1
   else
      return 0
   fi
}

################################################################################
function FAILURE
################################################################################
{
   if [[ ${LXDTOOLS_VAR[STATUS]} != 0 ]]; then
      return 1
   else
      return 0
   fi
}


################################################################################
function STATUS
################################################################################
{
   echo "${LXDTOOLS_VAR[STATUS]}"
}


################################################################################
function LOG 
################################################################################
{ 
   local loglevel="$1"
   shift
   _log_ "${loglevel}" "$@"
}

################################################################################
function SLEEP 
###############################################################################
{
   local sleep=$1
   local out

   if  [ "$(_isinteger_ "${sleep}")" == 0 ]; then
      _exit_ 1 "${FUNCNAME[0]}" "Invalid sleep value"
   fi 

   out=$(_replace_ "${LXDTOOLS_VAR[FMT_SLEEPING]}" "{{SLEEP}}" "${sleep}")

   _log_ 1 "${FUNCNAME[0]} ${out}"
   sleep "${sleep}"
}

###############################################################################
function EXIT  
###############################################################################
{
   local value=$1
   local msg=$2
   local out

   out=$(_replace_ "${T[EXITING]}" "{{STATUS}}" "${value}")
   out=$(_replace_ "${out}" "{{MSG}}" "${msg}")

   _exit_ "${value}" "${FUNCNAME[0]}" "${out}"
}


###############################################################################
function TIMER-START  
###############################################################################
{
   LXDTOOLS_STARTTIME=$(date +"%s")
   SPLITTIME=LXDTOOLS_STARTTIME
   ENDTIME=LXDTOOLS_STARTTIME
}

###############################################################################
function TIMER-SPLIT  
###############################################################################
{
   local now
   local out

   now=$(date +"%s")
   local total=$((now-LXDTOOLS_STARTTIME))
   local split=$((now-SPLITTIME))

   out=$(_replace_ "${LXDTOOLS_TEXT[SPLIT_TIME]}" "{{TIMER-TOTAL}}" "${total}")
   out=$(_replace_ "${out}" "{{TIMER-SPLIT}}" "${split}")

   _log_ 1 "${FUNCNAME[0]} ${out}"

   # Reset the start timer 
   SPLITTIME=$(date +"%s")
}

###############################################################################
function TIMER-TOTAL  
###############################################################################
{
   local out
   
   ENDTIME=$(date +"%s")
   local total=$((ENDTIME-LXDTOOLS_STARTTIME))

   out=$(_replace_ "${LXDTOOLS_TEXT[TOTAL_TIME]}" "{{TIMER-TOTAL}}" "${total}")

   _log_ 1 "${FUNCNAME[0]} ${out}"
}

###############################################################################
#function REPLACE
###############################################################################
#{
#   _log_ 1 "${FUNCNAME[0]} $*"
#
#   local container
#   local token
#   local replace
#   local filepath
#
#   container=$1
#   token=$2
#   replace=$3
#   filepath=$4
#
#   if [[ -z "${token}" ]]; then
#      _exit_ 1 "Cannot seach for nothing, provide a token"
#   fi
#
#   # these run locally so don't see files in the container
#   # they would have to be run with lxc exec
#
#   #if [[ ! -f "${filepath}" ]]; then
#   #   _exit_ 1 "File not found: (${filepath})"
#   #fi
#
#   #if [[ ! -r "${filepath}" ]]; then
#   #   _exit_ 1 "File not readable: (${filepath})"
#   #fi
#
#   #if [[ ! -w "${filepath}" ]]; then
#   #   _exit_ 1 "File not writeable: (${filepath})"
#   #fi
#
#   cmd="lxc exec ${container} -- sed --in-place \"s/${token}/${replace}/g\" \"${filepath}\""
#   _run_ "REPLACE" ${cmd}
#}

###############################################################################
#function APPEND
###############################################################################
#{
#   _log_ 1 "${FUNCNAME[0]} $*"
#
#   local container
#   #local string
#   #local filepath
#
#   container=$1
#   shift
#   params=$@
#   #string=$2
#   #filepath=$3
#
#   cmd="lxc exec ${container} -- ${LXDREMOTE} \"${string}\" \"${filepath}\""
#   _run_ "APPEND" ${cmd}
#}

################################################################################
#function ENV
################################################################################
#{
#   local token
#
#   if [[ ! -v "${LXDTOOLS_ENV[${token}]}" ]]; then
#      _exit_ 1 "Environment variable (${token}) does not exist"
#   fi
#
#   echo "${LXDTOOLS_ENV[${token}]}"
#}


###############################################################################
#function EXEC  
###############################################################################
#{
#   if [[ -z "${LXDTOOLS_VAR[CONTAINER]}" ]]; then
#      _exit_ 1 "CONTAINER variable not set"
#   fi
#
#   _run_ "${FUNCNAME[EXEC]}" "${LXDTOOLS_VAR[CONTAINER]}" "--" "$@" ; }
#}



################################################################################
#  _____                 _   _                 
# |  ___|   _ _ __   ___| |_(_) ___  _ __  ___ 
# | |_ | | | | '_ \ / __| __| |/ _ \| '_ \/ __|
# |  _|| |_| | | | | (__| |_| | (_) | | | \__ \
# |_|   \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
#
################################################################################

# lxc base operations
function INIT     { _run_ "${FUNCNAME[0]}" "$@" ; }
function LAUNCH   { _run_ "${FUNCNAME[0]}" "$@" ; }
function CONFIG   { _run_ "${FUNCNAME[0]}" "$@" ; }
function DEVICE   { _run_ "${FUNCNAME[0]}" "$@" ; }
function STORAGE  { _run_ "${FUNCNAME[0]}" "$@" ; }
function NETWORK  { _run_ "${FUNCNAME[0]}" "$@" ; }
function PROFILE  { _run_ "${FUNCNAME[0]}" "$@" ; }

# container
function STOP     { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }
function START    { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }
function RESTART  { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }
function DELETE   { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }
function INFO     { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }
function LIST     { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }

function EXEC     { _run_ "${FUNCNAME[0]}" "${LXDTOOLS_VAR[CONTAINER]}" "--" "$@" ; }

# snapshot
function SNAPSHOT { _run_ "${FUNCNAME[0]}" "$@" ; }
function COPY     { _run_ "${FUNCNAME[0]}" "$@" ; }
function MOVE     { _run_ "${FUNCNAME[0]}" "$@" ; }
function RESTORE  { _runcontainer_ "${FUNCNAME[0]}" "$@" ; }
# DELETE and INFO are covered under container

# file
function PUSH   { _run_ "${FUNCNAME[0]}" "$@" ; }
function PULL   { _run_ "${FUNCNAME[0]}" "$@" ; }


# Run any generic command on the host (local)
function HOST   { _hostrun_ "${FUNCNAME[0]}" "$@" ; }


# Commands supported by lxdremote script
# Container has to be passed in as the first parameter to the _remote_ function
function REPLACE { _remote_ "${FUNCNAME[0]}" "$@" ; }
function APPEND  { _remote_ "${FUNCNAME[0]}" "$@" ; }

