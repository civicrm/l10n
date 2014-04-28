#!/bin/bash

function usage() {
  cat <<EOT
create-pot-files-extensions.sh - builds .pot files for CiviCRM extensions.

Usage:
  ./bin/create-pot-files-extensions.sh [short name] [src dir] [dest dir]

Example:
  ./bin/create-pot-files-extensions.sh
  ./bin/create-pot-files-extensions.sh i18example ~/repository/ca.bidon.i18nexample/  ~/repository/ca.bidon.i18nexample/po/pots/

In the recommended use-case, you should run this command when your working
directory is the base directory of your extension, e.g. where the info.xml
is located.

The .pot file will be placed in l10n/pot/{extname}.pot.
Translations should be located in, for example, l10n/fr_FR/LC_MESSAGES/{extname}.po
and be compiled as l10n/fr_FR/LC_MESSAGES/{extname}.mo

NB: this program uses the "sponge" command, which you can get by installing the
"moreutils" package under Debian/Ubuntu.

EOT

  exit 1;
}

[ "$1" == "--help" ] && usage
[ "$1" == "-h" ] && usage

extname="$1"
root="$2"
potdir="$3"

# In the typical use-case, we are invoked from the working directory of the extension
# and we can use the info.xml to get the extension name
if [ "$1" == "" ]; then
  test ! -f "info.xml" && echo "Error: Could not find info.xml in the current directory `pwd`" && usage

  # Extract the tag "<file>i18nexample</file>" from the info.xml
  # We first extract the line with the "file" tag, then extract the 'file' value.
  # the regexp is a bit more generous than necessary, in case everything is on one line.
  extname=`grep '<file>' info.xml | sed 's|\s*<file>\(.*\)</file>\s*|\1|'`

  test "$extname" == "" && echo 'Error: could not find the file tag from info.xml' && usage

  root="."

  # The automatic string extractor passes an environment variable to set the potdir.
  if [ -d "$POTDIR" ]; then
    potdir=$POTDIR
  else
    potdir="l10n/pot/"
  fi

  # At this point we can assume that we are in the right place, and can create
  # the pot target directory if necessary.
  if [ ! -d "$potdir" ]; then
    echo " * Creating target pot directory: $potdir"
    mkdir -p "$potdir"
  fi
fi

# Ensure that the source and target directory exist
test ! -e "$root" && echo "Error: $root source does not exist"  && usage
test ! -d "$root" && echo "Error: $root source not a directory" && usage

test ! -e "$potdir" && echo "Error: $potdir target does not exist (please create it if necessary)" && usage
test ! -d "$potdir" && echo "Error: $portidr target not a directory" && usage

# Test whether the sponge command is installed
which sponge > /dev/null
if [ $? -ne 0 ]; then
  echo "Could not find the sponge command. sudo apt-get install moreutils ?"
  usage
fi

header=`tempfile`
now=`date +'%F %R%z'`

# Replace the generation timestamp in the header
# and set the Project-Id-Version to that of the extension
sed -e "s/NOW/$now/" \
    -e "s/Project-Id-Version: CiviCRM/Project-Id-Version: $extname/" \
    `dirname $0`/header > $header

# create base POT file
echo " * Building ${extname}.pot"
cp $header $potdir/${extname}.pot
`dirname $0`/extractor.php extension $root >> $potdir/${extname}.pot
msguniq $potdir/${extname}.pot | sponge $potdir/${extname}.pot

rm $header

echo " * All done"
echo ""
echo "Generated file: $potdir/${extname}.pot"
echo "Feel free to commit it to your git repository."
echo ""
echo "You can also request on the CiviCRM Extensions forum to add it to Transifex:"
echo "[URL here]"
echo ""
echo "For more information:"
echo "[wiki URL here]"

