#!/bin/bash

set -e
set -x

function usage() {
  cat <<EOT
build-unified-pots.sh - builds .pot files for the last 3 versions of CiviCRM.

Usage:

- Setup buildkit and make sure that civibuild is in your PATH

- Run this script (where 6.0 is the latest stable version of CiviCRM and 5.75 is the current ESR):
    $ ./bin/build-unified-pots.sh po/pot '6.0 5.75' 2>&1 | tee pots.log

- Use diff-check.php to see if the changes make sense. Spot-check new strings
  and make sure few strings were removed (strings may be moved to civicrm-common,
  but there should not be a huge amount of strings removed).

  For example:

  To display strings added or removed:
    $ ./bin/diff-check.php | less

  To display a summary per file:
    $ ./bin/diff-check.php | grep -E '^(\# FILE|Removed|Added|Unchanged)'

  To view a total summary:
    $ ./bin/diff-check.php | grep -E '^(Removed|Added|Unchanged)' | awk '{foo[$1] += $2} END {for (f in foo) {print f, foo[f]}}'

- Push the new strings to Transifex.

NB: We usually build the po files that are compatible for the last 3 versions
of CiviCRM. For example, as of 4.6, this means the po files will be compatible
with CiviCRM 4.6, 4.5 and 4.4.

For more information:
https://lab.civicrm.org/dev/translation/-/wikis/Pushing-new-strings-to-transifex
EOT

  exit 1;
}

[ "$1" = "--help" ] && usage
[ -z "$1" ] && usage

if [ ! $(which civibuild) ]; then
  echo "civibuild not found in your PATH";
  exit 1;
fi

potdir="po/pot"
releases=`echo "$1" | tr ' ' '\n'`

temp=`mktemp -d`

for rel in $releases; do
  mkdir -p $temp/$rel
  mkdir -p $temp/pot/$rel
  site="l10n-$rel"

  # Sometimes the extraction fails midway and it is annoying to rebuild
  if [ ! -d "$HOME/buildkit/build/$site" ]; then
    civibuild create $site --type standalone-clean --civi-ver $rel
  fi

  echo "Executing: create-pot-files.sh ~/buildkit/build/$site/web/core $temp/pot/$rel"
  bin/create-pot-files.sh ~/buildkit/build/$site/web/core $temp/pot/$rel
done

pots=`for pot in $temp/pot/*/*.pot; do basename $pot .pot; done | sort -u | grep -v ^drupal-civicrm$`

# merge per-release files into unified ones
echo "Merging pots files of various versions: $pots ..."
for pot in $pots; do
  echo " * merging $pot.pot files"
  msgcat --use-first $temp/pot/*/$pot.pot > $potdir/$pot.pot
done

# drop strings in common-base.pot from other files
for pot in $pots; do
  [ $pot == 'common-base' ] && continue
  echo " * dropping common-base strings from $pot.pot"
  common=`tempfile`
  msgcomm $potdir/$pot.pot $potdir/common-base.pot > $common
  msgcomm --unique $potdir/$pot.pot $common | sponge $potdir/$pot.pot
  rm $common
done

# drop strings in common-components.pot from other files
for pot in $pots; do
  [ $pot == 'common-base' ]       && continue
  [ $pot == 'common-components' ] && continue
  echo " * dropping common-components strings from $pot.pot"
  common=`tempfile`
  msgcomm $potdir/$pot.pot $potdir/common-components.pot > $common
  msgcomm --unique $potdir/$pot.pot $common | sponge $potdir/$pot.pot
  rm $common
done

rm -rf $temp

# Remove the buildkit sites
for rel in $releases; do
  echo 'y' | civibuild destroy l10n-$rel
done

cat <<EOT

ALL DONE

Next step is to review the new strings with "git diff".
You are strongly encouraged to use the "patience" algorightm otherwise
the diffs will seem bigger than they actually are:

    $ git status
    $ ./bin/diff-check.php | less
    $ ./bin/diff-check.php | grep -E '^\# .*(removed|added|unchanged)'
    $ ./bin/diff-check.php | grep -E '^\# .*(removed|added|unchanged)' | awk '{foo[$1] += $2} END {for (f in foo) {print f, foo[f]}}'

If it all looks good, commit the changes:

    $ git add po/pot/*
    $ git commit -m "New strings for version 5.xx"
    $ git tag 5.21
    $ git push --tags

After that, you can push the source pot files to Transifex:

    $ tx push -s

If a new component was added to CiviCRM (i.e. you have a new something.pot
that was created), it needs to be added to Transifex. For example:

    $ tx set --auto-local -r civicrm.pcp 'po/<lang>.po' --source-lang en --source-file po/pot/pcp.pot --execute
    $ tx push -s -r civicrm.pcp
    $ tx pull -a -r civicrm.pcp

EOT
