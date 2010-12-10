#!/bin/bash

[ "$1" == "" ] && echo 'source locale missing' && exit 1
[ "$2" == "" ] && echo 'target locale missing' && exit 1

echo "porting from $1 to $2"

pots=`for pot in po/pot/*.pot; do basename $pot .pot; done`
for pot in $pots; do
  echo -n $pot
  msgcat --use-first po/$2/$pot.po po/$1/$pot.po | sponge po/$2/$pot.po
  msgmerge --update po/$2/$pot.po po/pot/$pot.pot
  msgattrib --no-obsolete --no-wrap po/$2/$pot.po | sponge po/$2/$pot.po
done

echo
echo "porting from $2 to $1"

pots=`for pot in po/pot/*.pot; do basename $pot .pot; done`
for pot in $pots; do
  echo -n $pot
  msgcat --use-first po/$1/$pot.po po/$2/$pot.po | sponge po/$1/$pot.po
  msgmerge --update po/$1/$pot.po po/pot/$pot.pot
  msgattrib --no-obsolete --no-wrap po/$1/$pot.po | sponge po/$1/$pot.po
done
