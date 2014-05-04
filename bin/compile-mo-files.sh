#!/bin/bash

function usage() {
  cat <<EOT
compile-mo-files.sh - compiles the .po files to binary .mo format
At runtime, gettext uses the compiled .mo format to translate strings (faster).

Usage:

  ./bin/compile-mo-files.sh [locale]

Example:

  ./bin/compile-mo-files.sh
  ./bin/compile-mo-files.sh fr

EOT

  exit 1;
}

function compile_po () {
  lang=$1

  if [ ! -d "mo/$lang" ]; then
    mkdir -p mo/$lang
  fi

  echo -n "compiling $lang ... "
  msgcat --use-first po/$lang/*.po | msgfmt -o mo/$lang/civicrm.mo -
  echo "done"
}

if [ "$1" = "--help" -o "$1" = "-h" ]; then
  usage
fi

# This makes it easier to configure crons on civi infrastructure,
# while still making it possible to use this script in other places.
if [ ! -d "po" ]; then
  if [ -d "$HOME/repositories/civicrm-l10n/po" ]; then
    cd $HOME/repositories/civicrm-l10n
  else
    echo "ERROR: Could not find the location of the civicrm-l10n repository."
    echo ""
    usage
  fi
fi

if [ -n "$1" ]; then
  if [ -d "po/$1" ]; then
    compile_po $1
  else
    echo "Error: $1: invalid locale (not found in the ./po/ directory)."
    exit 1
  fi
else
  langs=`ls -1d po/?? po/??_?? | cut -d/ -f2`
  
  for lang in $langs; do
    compile_po $lang
  done

  # To avoid annoying people who may be using this script,
  # check that we are running as the l10n user.
  user=`whoami`

  if [ "$user" = "l10n" ]; then
    echo -n "Rsync to download.civicrm.org ... "
    rsync --delete -ra mo l10n@download.civicrm.org:/var/www/download.civicrm.org/public/civicrm-l10n-core/
    echo "done!"
  fi
fi

