#!/bin/bash

function usage() {
  cat <<EOT
git-checkout-all.sh - helper script to clone all git repositories.

Usage:

- Prepare a directory that has all of the CiviCRM git repositories, ex:
  $ mkdir ~/repositories/civicrm/

- Run this script:
  $ ./bin/git-checkout-all.sh ~/repositories/civicrm/
EOT

  exit 1;
}

DEST=$1

# Check if a destination directory was specified
if [ -z $DEST -o "$DEST" == "--help" -o "$DEST" == "-h" ]; then
  usage
fi

# Check if the directory exists
if [ ! -d $DEST ]; then
  echo "ERROR: $DEST does not exist."
  usage
fi

# Check if the directory was empty
ls -1 $DEST | wc -l | grep -q '^0$' || {
  echo "ERROR: $DEST seems non-empty. You should use an empty directory."
  usage
}

cd $DEST

git clone https://github.com/civicrm/civicrm-core.git
git clone https://github.com/civicrm/civicrm-drupal.git
git clone https://github.com/civicrm/civicrm-joomla.git
git clone https://github.com/civicrm/civicrm-wordpress.git
git clone https://github.com/civicrm/civicrm-packages.git
git clone https://github.com/CiviCRM42/civicrm42-core.git
git clone https://github.com/CiviCRM42/civicrm42-drupal.git
git clone https://github.com/CiviCRM42/civicrm42-joomla.git
git clone https://github.com/CiviCRM42/civicrm42-wordpress.git
git clone https://github.com/CiviCRM42/civicrm42-packages.git

