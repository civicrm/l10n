#!/bin/bash

set -e
set -x

function usage() {
  cat <<EOT
build-unified-pots.sh - builds .pot files for the last 3 versions of CiviCRM.

Usage:

- Prepare a CiviCRM checkout that also has all of the sub-repositories, ex:
  /path/to/repositories/civicrm/{joomla,wordpress,packages}
  where the 'civicrm' directory corresponds to civicrm-core.git.

- Make sure your repository is up to date (git fetch --all).

- Run this script (where 4.7.12 is the latest version of CiviCRM):
    $ ./bin/build-unified-pots.sh ~/repositories/civicrm po/pot '4.6 4.7.12' 2>&1 | tee pots.log

  or, for master:
    $ ./bin/build-unified-pots.sh ~/repositories/civicrm po/pot '4.6 master' 2>&1 | tee pots.log

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
[ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] && usage
[ ! -d "$2" ]                             && echo "ERROR: $2: directory not found." && usage
[ -n "$4" ]                               && echo 'ERROR: provide releases as one, space-separated string' && usage


root="$1"
potdir="$2"
releases=`echo "$3" | tr ' ' '\n'`

temp=`mktemp -d`

for rel in $releases; do
  mkdir -p $temp/$rel
  mkdir -p $temp/pot/$rel

  pushd .

  # Get fresh codebase

  # we use ${rel:1} so that v4.3 => 4.3, except for "master".
  # r=${rel:1}
  # if [ "$rel" = "master" ]; then
  #  r="master"
  # fi

  echo "Copying $root ($rel) to $temp/$rel ..."
  cd $root
  git fetch
  git checkout $rel
  git archive $rel | tar -xC $temp/$rel

# Dropped because it is not really used (translations use 't' instead of 'ts')
# and Drupal7 is heading for EOL (i.e. we're not going to fix it).
#   echo "Copying $root/drupal (7.x-$rel) to $temp/$rel/drupal ..."
#   mkdir -p $temp/$rel/drupal
#   cd $root/drupal
#   git fetch
#   git checkout 7.x-$rel
#   git archive 7.x-$rel | tar -xC $temp/$rel/drupal

  if [ -d $root/joomla ]; then
    echo "Copying $root/joomla ($rel) to $temp/$rel/joomla ..."
    mkdir -p $temp/$rel/joomla
    cd $root/joomla
    git fetch
    git checkout $rel
    git archive $rel | tar -xC $temp/$rel/joomla
  else
    echo "Skipping missing $root/joomla."
    echo "As of CiviCRM 4.6 there aren't any strings in it, but that could change in the future?"
  fi

  if [ -d $root/wordpress ]; then
    echo "Copying $root/wordpress ($rel) to $temp/$rel/wordpress ..."
    mkdir -p $temp/$rel/wordpress
    cd $root/wordpress
    git fetch
    git checkout $rel
    git archive $rel | tar -xC $temp/$rel/wordpress
  else
    echo "Skipping missing $root/wordpress."
    echo "As of CiviCRM 4.6 there aren't any strings in it, but that could change in the future?"
  fi

  echo "Copying $root/packages ($rel) to $temp/$rel/packages ..."
  mkdir -p $temp/$rel/packages
  cd $root/packages
  git fetch
  git checkout $rel
  git archive $rel | tar -xC $temp/$rel/packages

  mkdir $temp/$rel/xml/default
  echo '<?php define("CIVICRM_CONFDIR", ".");' > $temp/$rel/settings_location.php
  echo '<?php define("CIVICRM_UF", "Drupal");' > $temp/$rel/xml/default/civicrm.settings.php

  if [ -f $temp/$rel/composer.json ]; then
    echo "Running composer install ..."
    cd $temp/$rel
    composer install -v
  fi

  echo "Running GenCode.php ..."
  cd $temp/$rel/xml
  php GenCode.php schema/Schema.xml | grep -v Generating

  popd

  if [ -f $temp/tools/bin/scripts/create-pot-files.sh ]; then
    echo "Executing: $temp/tools/bin/scripts/create-pot-files.sh $temp/$rel $temp/pot/$rel"
    $temp/tools/bin/scripts/create-pot-files.sh $temp/$rel $temp/pot/$rel
  else
    echo "Executing: create-pot-files.sh $temp/$rel $temp/pot/$rel"
    bin/create-pot-files.sh $temp/$rel $temp/pot/$rel
  fi
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
