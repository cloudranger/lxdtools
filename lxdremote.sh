#!/usr/bin/env bash
# shellcheck disable=SC2059

#trap '_error_ $? $LINENO' ERR


################################################################################
#  ___       _                        _ 
# |_ _|_ __ | |_ ___ _ __ _ __   __ _| |
#  | || '_ \| __/ _ \ '__| '_ \ / _` | |
#  | || | | | ||  __/ |  | | | | (_| | |
# |___|_| |_|\__\___|_|  |_| |_|\__,_|_|
#  
################################################################################

################################################################################
function _exit_
################################################################################
{
   local value=$1
   local msg=$2

   echo "${msg}" >&2
   exit "${value}"
}


###############################################################################
#   ____                                          _     
#  / ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |___ 
# | |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` / __|
# | |__| (_) | | | | | | | | | | | (_| | | | | (_| \__ \
#  \____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|___/
#                                                      
###############################################################################


###############################################################################
function REPLACE
###############################################################################
{
   local token
   local replace
   local filepath

   token="$1"
   replace="$2"
   filepath="$3"

   if [[ -z "${token}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: Cannot seach for nothing, provide a token"
   fi

   if [[ ! -f "${filepath}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: File not found: (${filepath})"
   fi

   if [[ ! -r "${filepath}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: File not readable: (${filepath})"
   fi

   if [[ ! -w "${filepath}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: File not writeable: (${filepath})"
   fi

   sed --in-place "s/${token}/${replace}/g" "${filepath}"
   return $?
}


###############################################################################
function APPEND
##############################################################################
{
   local string
   local filepath

   string="$1"
   filepath="$2"

   if [[ ! -f "${filepath}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: File not found: (${filepath})"
   fi

   if [[ ! -r "${filepath}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: File not readable: (${filepath})"
   fi

   if [[ ! -w "${filepath}" ]]; then
      _exit_ 1 "${FUNCNAME[0]}: File not writeable: (${filepath})"
   fi

   echo "${string}" >> "${filepath}"
   return $?
}


##############################################################################
function TEST
##############################################################################
{
   echo "${FUNCNAME[0]} $*"
   return 0
}


##############################################################################
# MAIN
##############################################################################

cmd="$1"
shift

if [[ -z $(declare -F "${cmd}") ]]; then
   _exit_ 1 "Command does not exist: ${cmd}"
fi

$cmd "$@"
