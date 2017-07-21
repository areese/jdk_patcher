#!/usr/bin/env bash
#
# Copyright 2017 Yahoo Inc.
# Licensed under the terms of the 3-Clause BSD license. See LICENSE file in the project root for details.
#
# This script ruins the jdk.

SCRIPT_DIR="$(dirname "$([[ -L "${BASH_SOURCE[0]}" ]] && readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")"

dryrun=0;

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
-d <java_dir>   JAVA_HOME, the JDK to patch the jsse.jar of
-b <backup_dir> Directory to save the backed up class files in.  You'll want these to revert the change.
-c <class_name> Class name as in the jdk, example:  sun/security/ssl/SupportedEllipticCurvesExtension.class
-n dry run, don't update the jdk, just extract classes.
-s <source dir> Source dir containing the classes to replace.  should have the class in the correct path src/sun/security/ssl/SupportedEllipticCurvesExtension.class
EOF
}


#######################################
# Parse args into global values.
#
# Globals:
#   BACKUP_DIR: where to store the extracted class files.
#   replaced_classes: array of class paths that will be replaced.
#   JAVA_DIR equivalent to JAVA_HOME, the path to the jdk we're patching.
#   SOURCE_DIR: dir containing the replacement classes
# Arguments:
#   Flags...
# Returns:
#   None
#######################################
function parse_args {
  optspec=":b:c:d:hns:"
  while getopts "$optspec" optchar; do
    case ${optchar} in
    b)
      BACKUP_DIR=$OPTARG
      ;;
    c)
      replaced_classes+=($OPTARG)
      ;;
    d)
      JAVA_DIR=$OPTARG
      ;;
    h)
      usage
      exit 2
      ;;
    n)
      dryrun=1
      ;;
    s)
      SOURCE_DIR=$OPTARG
      ;;
    *)
      if (( $OPTERR != 1 )) || [[ "${optspec:0:1}" == ":" ]]; then
      echo "Non-option argument: '-${OPTARG}'" >&2
      fi
      ;;
    esac
  done
}

function backup_jdk_classes {
  echo Classes: ${replaced_classes[@]}

  # replaced_classes is a list of class paths in jsse.jar we're going to extract and replace.
  # -C <dir> doesn't work with jar
  mkdir -p ${BACKUP_DIR}

  # enter the backup directory
  pushd ${BACKUP_DIR}
  for class_name in ${replaced_classes[@]}; do
    echo Extracting ${class_name} into ${PWD}
    $JAVA_DIR/bin/jar xvf "$JSSE_JAR" "$class_name"
  done
  popd
}

function replace_jdk_classes {
  echo Classes: ${replaced_classes[@]}

  # replaced_classes is a list of class paths in jsse.jar we're going to extract and replace.
  # enter the backup directory
  pushd ${SOURCE_DIR}
  for class_name in ${replaced_classes[@]}; do
    echo Replacing ${class_name} from ${PWD}
    $JAVA_DIR/bin/jar uvf "$JSSE_JAR" "$class_name"
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

  JSSE_JAR=$(find "${JAVA_DIR}" -name jsse.jar)

  echo JAVA_DIR: ${JAVA_DIR}
  echo JSSE_JAR: ${JSSE_JAR}
  echo BACKUP_DIR: ${BACKUP_DIR}

  echo JSSE_JAR sha1sum before: $(sha1sum $JSSE_JAR) 

  # First we want to save all of the classes, so they can be reversed later.
  backup_jdk_classes

  # then we replace the existing classes with the new classes.
  if [[ 1 != $dryrun ]]; then
    replace_jdk_classes
  fi

  echo JSSE_JAR sha1sum after: $(sha1sum $JSSE_JAR) 
}

declare -a replaced_classes

# Allow inclusion or run
if ((${#BASH_SOURCE[@]} == 1)); then
  main "$@"
fi
