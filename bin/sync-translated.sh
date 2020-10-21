#!/bin/bash

function usage() {
  cat <<EOT
sync-translated.sh - Copies translated strings from one language
to untranslated strings of the other language.

Usage:
  ./bin/sync-translated.sh [src] [dst]

Example:
  ./bin/sync-translated.sh fr_FR fr_CA
EOT

  exit 1;
}

[ -z "$1" ] && echo 'Error: source locale missing' && usage
[ -z "$2" ] && echo 'Error: target locale missing' && usage

echo "porting from $1 to $2"

pots=`for pot in po/$1/*.po; do basename $pot .po; done`
for pot in $pots; do
  echo $pot
  msgcat --use-first po/$2/$pot.po po/$1/$pot.po | sponge po/$2/$pot.po
  # msgmerge --update po/$2/$pot.po po/pot/$pot.pot
  # msgattrib --no-obsolete po/$2/$pot.po | sponge po/$2/$pot.po
done

# [ML] 2014-05-07 do not sync both way, too risky.
# echo
# echo "porting from $2 to $1"
#
# pots=`for pot in po/pot/*.pot; do basename $pot .pot; done`
# for pot in $pots; do
#   echo -n $pot
#   msgcat --use-first po/$1/$pot.po po/$2/$pot.po | sponge po/$1/$pot.po
#   msgmerge --update po/$1/$pot.po po/pot/$pot.pot
#   msgattrib --no-obsolete po/$1/$pot.po | sponge po/$1/$pot.po
# done
