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
  if [ -d "$HOME/repositories/civicrm-l10n-core/po" ]; then
    cd $HOME/repositories/civicrm-l10n-core
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

  if [ "$user" = "gitlab-runner" ]; then
    for i in $(cat conf/distributed_languages.txt); do
      mkdir -p workdir/l10n/$i/LC_MESSAGES
      cp workdir/mo/$i/civicrm.mo workdir/l10n/$i/LC_MESSAGES/
    done

    pushd workdir
    tar cfz civicrm-l10n-daily.tar.gz l10n
    md5sum civicrm-l10n-daily.tar.gz > civicrm-l10n-daily.tar.gz.MD5SUMS

    echo -n "gsutil rsync civicrm-l10n-daily.tar.gz to gcloud bucket for download.civicrm.org ... "
    ~/bin/gsutil/gsutil rsync civicrm-l10n-daily.tar.gz gs://civicrm/civicrm-l10n-core/archives/
    ~/bin/gsutil/gsutil rsync civicrm-l10n-daily.tar.gz.MD5SUMS gs://civicrm/civicrm-l10n-core/archives/

    echo -n "gsutil rsync all .mo files to gcloud bucket for download.civicrm.org ... "
    ~/bin/gsutil/gsutil rsync -r ./mo gs://civicrm/civicrm-l10n-core/mo/
    echo "done!"

    rm civicrm-l10n-daily.tar.gz*
    popd
  fi
fi
