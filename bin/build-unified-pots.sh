#!/bin/bash

function usage() {
  cat <<EOT
build-unified-pots.sh - builds .pot files for the last 3 versions of CiviCRM.

Usage:

- Prepare a directory that has all of the CiviCRM git repositories, ex:
  /path/to/repositories/civicrm-{core,drupal,joomla,wordpress,packages}

  In other words:
    $ mkdir -p ~/repositories/civicrm
    $ cd ~/repositories/civicrm
    $ git clone https://github.com/civicrm/civicrm-core.git
    $ git clone https://github.com/civicrm/civicrm-drupal.git
    $ git clone https://github.com/civicrm/civicrm-joomla.git
    $ git clone https://github.com/civicrm/civicrm-wordpress.git
    $ git clone https://github.com/civicrm/civicrm-packages.git

  WARNING: the script assumes you are tracking "origin",
  the script will "git pull origin $release" for each repo.

- Run this script:
    $ ./bin/build-unified-pots.sh ~/repositories/civicrm po/pot 'v4.1 v4.2 v4.3' 2>&1 | tee pots.log
    $ ./bin/build-unified-pots.sh ~/repositories/civicrm po/pot 'v4.1 v4.2 master' 2>&1 | tee pots.log

- Push the new strings to Transifex.

NB: since the migration to git, as of 4.3, we hardcode for now that v4.1 and v4.2
are fetched from SVN, and v4.3 from git.

NB: use the "patience" diff algorithm from git to generate cleaner diffs:
    $ git config --global diff.algorithm patience

For more information:
http://wiki.civicrm.org/confluence/display/CRMDOC/Localisation+stack
EOT

  exit 1;
}

SVNROOT="http://svn.civicrm.org/civicrm/branches"

[ "$1" = "--help" ] && usage
[ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] && usage
[ ! -d "$2" ]                             && echo "ERROR: $2: directory not found." && usage
[ -n "$4" ]                               && echo 'ERROR: provide releases as one, space-separated string' && usage


root="$1"
potdir="$2"
releases=`echo "$3" | tr ' ' '\n'`

temp=`mktemp -d`

for rel in $releases; do
  ## This can be useful to debug the build process or to test on a trunk checkout
  ## (if you use this, comment out the 'get fresh codebase' block below)
  # cp -r /path/to/civicrm $temp/v4.1

  mkdir -p $temp/$rel
  mkdir -p $temp/pot/$rel

  pushd .

  # Get fresh codebase
  # starting 4.3, civicrm is using git
  # assuming that before that, we are fetching from SVN
  # when we drop support for 4.2, we can cleanup this code.
  if [ "$rel" = "v4.2" -o "$rel" = "v4.1" -o "$rel" = "v4.0" ]; then
    svn export -q --ignore-externals --force "$SVNROOT/$rel" "$temp/$rel"
  else
    # we use ${rel:1} so that v4.3 => 4.3, except for "master".
    r=${rel:1}
    if [ "$rel" = "master" ]; then
      r="master"
    fi

    echo "Copying $root/civicrm-core ($r) to $temp/$rel ..."
    cd $root/civicrm-core
    git pull
    git archive $r | tar -xC $temp/$rel

    echo "Copying $root/civicrm-drupal (7x-$r) to $temp/$rel/drupal ..."
    mkdir -p $temp/$rel/drupal
    cd $root/civicrm-drupal
    git checkout 7.x-$r
    git pull
    git archive 7.x-$r | tar -xC $temp/$rel/drupal

    echo "Copying $root/civicrm-joomla ($r) to $temp/$rel/joomla ..."
    mkdir -p $temp/$rel/joomla
    cd $root/civicrm-joomla
    git checkout $r
    git pull
    git archive $r | tar -xC $temp/$rel/joomla

    echo "Copying $root/civicrm-wordpress ($r) to $temp/$rel/wordpress ..."
    mkdir -p $temp/$rel/wordpress
    cd $root/civicrm-wordpress
    git checkout $r
    git pull
    git archive $r | tar -xC $temp/$rel/wordpress

    echo "Copying $root/civicrm-packages ($r) to $temp/$rel/packages ..."
    mkdir -p $temp/$rel/packages
    cd $root/civicrm-packages
    git checkout $r
    git pull
    git archive $r | tar -xC $temp/$rel/packages
  fi

  mkdir $temp/$rel/xml/default
  echo '<?php define("CIVICRM_CONFDIR", ".");' > $temp/$rel/settings_location.php
  echo '<?php define("CIVICRM_UF", "Drupal");' > $temp/$rel/xml/default/civicrm.settings.php

  echo "Running GenCode.php ..."
  cd $temp/$rel/xml
  php GenCode.php schema/Schema.xml | grep -v Generating

  popd

  echo "Executing: create-pot-files.sh $temp/$rel $temp/pot/$rel"
  bin/create-pot-files.sh $temp/$rel $temp/pot/$rel
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

rm -r $temp

cat <<EOT

ALL DONE

Next step is to review the new strings with "git diff".
You are strongly encouraged to use the "patience" algorightm otherwise
the diffs will seem bigger than they actually are:

    $ git status
    $ git diff --patience

If it all looks good, commit the changes:

    $ git add po/pot/*
    $ git tag 4.3.1
    $ git push --tags

After that, you can push the source pot files to Transifex:

    $ tx push -s

If a new component was added to CiviCRM (i.e. you have a new something.pot
that was created), it needs to be added to Transifex. For example:

    $ tx set --auto-local -r civicrm.pcp 'po/<lang>.po' --source-lang en --source-file po/pot/pcp.pot --execute
    $ tx push -s -r civicrm.pcp
    $ tx pull -a -r civicrm.pcp

NB: use the "patience" diff algorithm from git to generate cleaner diffs:
    $ git config --global diff.algorithm patience

EOT
