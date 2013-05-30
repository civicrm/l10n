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

  echo -n "compiling $lang ... "
  msgcat --use-first po/$lang/*.po | msgfmt -o po/$lang/civicrm.mo -
  echo "done"
}

if [ "$1" = "--help" -o "$1" = "-h" ]; then
  usage
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
fi

