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

  if [ ! -d "workdir/mo/$lang" ]; then
    mkdir -p workdir/mo/$lang
  fi

  echo -n "compiling $lang ... "
  msgcat --use-first po/$lang/*.po | msgfmt -o workdir/mo/$lang/civicrm.mo -
  echo "done"
}

if [ "$1" = "--help" -o "$1" = "-h" ]; then
  usage
fi

# This makes it easier to configure crons on civi infrastructure,
# while still making it possible to use this script in other places.
if [ ! -d "po" ]; then
  if [ -d "$HOME/l10n/civicrm-l10n-core/po" ]; then
    cd $HOME/l10n/civicrm-l10n-core
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

  if [ "$user" = "jenkins" ]; then
    mkdir -p $WORKSPACE/publish

    # Copy over the .mo files included in the daily tar.gz
    for i in $(cat conf/distributed_languages.txt); do
      mkdir -p workdir/l10n/$i/LC_MESSAGES
      cp workdir/mo/$i/civicrm.mo workdir/l10n/$i/LC_MESSAGES/
    done

    pushd workdir
    mkdir -p $WORKSPACE/publish/archives
    tar cfz $WORKSPACE/publish/archives/civicrm-l10n-daily.tar.gz l10n
    md5sum $WORKSPACE/publish/archives/civicrm-l10n-daily.tar.gz > $WORKSPACE/publish/archives/civicrm-l10n-daily.tar.gz.MD5SUMS
    popd

    # Copy over the .mo files to publish on gcloud
    # The jenkins job picks up the files in this directory and takes care of pushing.
    for lang in $langs; do
      mkdir -p $WORKSPACE/publish/mo/$lang
      cp workdir/mo/$lang/civicrm.mo $WORKSPACE/publish/mo/$lang/civicrm.mo
    done
  fi
fi
