#!/bin/bash

[ "$1" == "" ] && echo 'source locale missing' && exit 1
[ "$2" == "" ] && echo 'target locale missing' && exit 1

echo "porting from $1 to $2"

pots=`for pot in po/*.pot; do basename $pot .pot; done`
for pot in $pots; do
  echo -n $pot
  msgcat --use-first po/$2/LC_MESSAGES/$pot.po po/$1/LC_MESSAGES/$pot.po | sponge po/$2/LC_MESSAGES/$pot.po
  msgmerge --update po/$2/LC_MESSAGES/$pot.po po/$pot.pot
  msgattrib --no-obsolete --no-wrap po/$2/LC_MESSAGES/$pot.po | sponge po/$2/LC_MESSAGES/$pot.po
done

echo
echo "porting from $2 to $1"

pots=`for pot in po/*.pot; do basename $pot .pot; done`
for pot in $pots; do
  echo -n $pot
  msgcat --use-first po/$1/LC_MESSAGES/$pot.po po/$2/LC_MESSAGES/$pot.po | sponge po/$1/LC_MESSAGES/$pot.po
  msgmerge --update po/$1/LC_MESSAGES/$pot.po po/$pot.pot
  msgattrib --no-obsolete --no-wrap po/$1/LC_MESSAGES/$pot.po | sponge po/$1/LC_MESSAGES/$pot.po
done
