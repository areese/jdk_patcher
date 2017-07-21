#!/usr/bin/env bash
#
# This script ruins the jdk.

SCRIPT_DIR="$(dirname "$([[ -L "${BASH_SOURCE[0]}" ]] && readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")"

#######################################
# Print usage information.
#
# Globals:
# Arguments:
#   None
# Returns:
#   None
#######################################
function usage() {
column -t -s $'\t' <<EOF
-d <java_dir>
-b <backup_dir>
-c <class_name>
EOF
}


#######################################
# Parse args into global values.
#
# Globals:
# Arguments:
#   Flags...
# Returns:
#   None
#######################################
function parse_args() {
  optspec=":b:c:d:h"
  while getopts "$optspec" optchar; do
    case "${optchar}" in
    b)
      BACKUP_DIR="$OPTARG"
      ;;
    c)
      replaced_classes+=($OPTARG)
      ;;
    d)
      JAVA_DIR="$OPTARG"
      ;;
    h)
      usage
      exit 2
      ;;
    *)
      if (( $OPTERR != 1 )) || [[ "${optspec:0:1}" == ":" ]]; then
      echo "Non-option argument: '-${OPTARG}'" >&2
      fi
      ;;
    esac
  done
}

function backup_classes() {
  echo Classes: "${replaced_classes[@]}"

  # replaced_classes is a list of class paths in jsse.jar we're going to extract and replace.
  # -C <dir> doesn't work with jar
  mkdir -p ${BACKUP_DIR}

  # enter the backup directory
  pushd ${BACKUP_DIR}
  for class_name in "${replaced_classes[@]}"; do
    echo "Extracting ${class_name} into ${PWD}"
    $JAVA_DIR/bin/jar xvf $JSSE_JAR $class_name
  done
  popd
}

function main() {
  # fail on errors
  set -e
  # debugging is nice
  #set -x

  JAVA_DIR=$JAVA_HOME
  parse_args "$@"

  JSSE_JAR=$(find ${JAVA_DIR} -name jsse.jar)

  echo "JAVA_DIR: ${JAVA_DIR}"
  echo "JSSE_JAR: ${JSSE_JAR}"
  echo "BACKUP_DIR: ${BACKUP_DIR}"

  backup_classes
}

declare -a replaced_classes

# Allow inclusion or run
if ((${#BASH_SOURCE[@]} == 1)); then
  main "$@"
fi
