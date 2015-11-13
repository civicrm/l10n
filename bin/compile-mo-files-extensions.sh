#!/bin/bash

# Exit on errors
set -e

function usage() {
  cat <<EOT
compile-mo-files-extensions.sh - compiles the .po files to binary .mo format
for CiviCRM extensions managed by Transifex. At runtime, gettext uses the
compiled .mo format to translate strings (faster).

Run this from the base directory of the civicrm-l10n-extensions repository.
Since this is mainly a maintenance script for the CiviCRM infrastructure,
the script will assume the repository is in ~/repositories/ if the current
directory does not seem to be the correct repository.

If you compile all files (default), the script will attempt to resync the
compiled .mo files to download.civicrm.org.

NB: extensions use the full locale name, unlike core (ex: fr is fr_FR).
The short extension name is the "file" attribute in the info.xml of
the extension.

Usage:

  ./bin/compile-mo-files-extensions.sh [shortextname] [locale]

Examples:

  ./bin/compile-mo-files-extensions.sh i18nexample
  ./bin/compile-mo-files-extensions.sh i18nexample fr_FR

EOT

  exit 1;
}

function compile_po () {
  ext=$1
  lang=$2

  if [ ! -d "mo/$ext/$lang/" ]; then
    mkdir -p mo/$ext/$lang/
  fi

  echo -n "compiling $ext [ $lang ] ... "
  msgfmt po/$ext/$lang/$ext.po -o mo/$ext/$lang/$ext.mo
  echo "done"
}

function compile_po_for_ext () {
  ext=$1

  # Skip empty source .pot files
  # Ex: check if "po/example/pot/example.pot" has a non-zero size.
  # This can happen when extensions do not have any ts() strings in them.
  if [ ! -s "po/$ext/pot/$ext.pot" ]; then
    echo "skipping $ext, po/$ext/pot/$ext.pot is empty."
    return
  fi

  # Check if there are translations for the extensions.
  # This can happen if the extension has no strings, or was not sent to Transifex.
  # http://stackoverflow.com/questions/6363441/check-if-a-file-exists-with-wildcard-in-shell-script
  if ls po/$ext/??_?? &> /dev/null ; then
    langs=`ls -1d po/$ext/??_??`

    for lang in $langs; do
      l=`basename $lang`
      compile_po $ext $l
    done
  else
    echo "** $ext has no translations (probably no strings in the ext)."
  fi
}

if [ "$1" = "--help" -o "$1" = "-h" ]; then
  usage
fi

if [ ! -d "po" ]; then
  if [ -d "$HOME/repositories/civicrm-l10n-extensions/po" ]; then
    cd $HOME/repositories/civicrm-l10n-extensions
  else
    echo "ERROR: Could not find the location of the civicrm-l10n-extensions repository."
    echo ""
    usage
  fi
fi

if [ -n "$1" ]; then
  ext=$1

  if [ -d "po/$ext" ]; then
    if [ -n "$2" ]; then
      lang=$2
      compile_po $ext $lang
    else
      compile_po_for_ext $ext
    fi
  else
    echo "Error: $1: invalid locale (not found in the ./po/ directory)."
    exit 1
  fi
else
  extensions=`ls -1d po/*`

  for ext in $extensions; do
    e=`basename $ext`
    compile_po_for_ext $e
  done

  # To avoid annoying people who may be using this script,
  # check that we are running as the l10n user.
  user=`whoami`

  if [ "$user" = "l10n" ]; then
    echo -n "Rsync to download.civicrm.org ... "
    rsync --delete -ra mo /var/www/download.civicrm.org/public/civicrm-l10n-extensions/
    echo "done!"
  fi
fi
