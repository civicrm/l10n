#!/bin/bash

function usage() {
  cat <<EOT
create-pot-files-extensions.sh - builds .pot files for CiviCRM extensions.

Usage:
  ./bin/create-pot-files-extensions.sh [short name] [src dir] [dest dir]

Example:
  ./bin/create-pot-files-extensions.sh i18example ~/repository/ca.bidon.i18nexample/  ~/repository/ca.bidon.i18nexample/po/pots/

NB: this program uses the "sponge" command, which you can get by installing the
"moreutils" package under Debian/Ubuntu.

EOT

  exit 1;
}

[ "$1" == "--help" ] && usage
[ "$1" == "-h" ] && usage

[ "$1" == "" ] && echo 'extension name missing' && usage

[ "$2" == "" ] && echo 'source dir missing'     && usage
test ! -e "$2" && echo 'source does not exist'  && usage
test ! -d "$2" && echo 'source not a directory' && usage

[ "$3" == "" ] && echo 'target dir missing'     && usage
test ! -e "$3" && echo 'target does not exist (please create it if necessary)'  && usage
test ! -d "$3" && echo 'target not a directory' && usage

# Test whether the sponge command is installed
which sponge > /dev/null
if [ $? -ne 0 ]; then
  echo "Could not find the sponge command."
  usage
fi

extname="$1"
root="$2"
potdir="$3"

header=`tempfile`
now=`date +'%F %R%z'`
sed "s/NOW/$now/" `dirname $0`/header > $header

# $componets are the dirs with strings generating per-component $component.po files
# components=`ls -1 $root/CRM $root/templates/CRM | grep -v :$ | grep -v ^$ | grep -viFf bin/basedirs | sort -u | xargs | tr [A-Z] [a-z]`

# Helper function for extracting strings from xml/templates
# which are mostly component-specific. We also run a msguniq on
# them because later msgcomm calls tends to filter out strings
# that repeat themselves in {component}.po files.
function smarty_extractor {
  ME=$1
  root=$2
  potdir=$3
  input=$4
  component=$5

  `dirname $ME`/smarty-extractor.php $root $root/$input >> ${potdir}/${component}.pot
  msguniq $potdir/${component}.pot | sponge $potdir/${component}.pot
}

# create base POT file
set -x 

echo " * building ${extname}.pot"
cp $header $potdir/${extname}.pot
`dirname $0`/extractor.php extension $root >> $potdir/${extname}.pot
msguniq $potdir/${extname}.pot | sponge $potdir/${extname}.pot

# FIXME: smarty extraction?

rm $header
