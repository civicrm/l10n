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
    $ ./bin/build-unified-pots.sh ~/repositories/civicrm po/pot 'v4.1 v4.2 v4.3'
    $ ./bin/build-unified-pots.sh ~/repositories/civicrm po/pot 'v4.1 v4.2 master'

- Push the new strings to Transifex.

NB: since the migration to git, as of 4.3, we hardcode for now that v4.1 and v4.2
are fetched from SVN, and v4.3 from git.
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
    svn export --ignore-externals --force "$SVNROOT/$rel" "$temp/$rel"
  else
    cd $root/civicrm-core
    git pull
    git archive $rel | tar -xC $temp/$rel

    mkdir -p $temp/$rel/drupal
    cd $root/civicrm-drupal
    if [ "$rel" = "master" ]; then
      git checkout 7.x-${rel}
      git pull
      git archive 7.x-${rel} | tar -xC $temp/$rel/drupal
    else
      # we use ${rel:1} so that v4.3 => 4.3
      git checkout 7.x-${rel:1}
      git pull
      git archive 7.x-${rel:1} | tar -xC $temp/$rel/drupal
    fi

    mkdir -p $temp/$rel/joomla
    cd $root/civicrm-joomla
    git checkout $rel
    git pull
    git archive $rel | tar -xC $temp/$rel/joomla

    mkdir -p $temp/$rel/wordpress
    cd $root/civicrm-wordpress
    git checkout $rel
    git pull
    git archive $rel | tar -xC $temp/$rel/wordpress

    mkdir -p $temp/$rel/packages
    cd $root/civicrm-packages
    git checkout $rel
    git pull
    git archive $rel | tar -xC $temp/$rel/packages
  fi

  mkdir $temp/$rel/xml/default
  echo '<?php define("CIVICRM_CONFDIR", ".");' > $temp/$rel/settings_location.php
  echo '<?php define("CIVICRM_UF", "Drupal");' > $temp/$rel/xml/default/civicrm.settings.php

  cd $temp/$rel/xml
  php GenCode.php schema/Schema.xml

  popd

  bin/create-pot-files.sh $temp/$rel $temp/pot/$rel
done

pots=`for pot in $temp/pot/*/*.pot; do basename $pot .pot; done | sort -u | grep -v ^drupal-civicrm$`

# merge per-release files into unified ones
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
