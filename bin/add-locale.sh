#!/bin/bash

[ -z "$1" ] && echo 'locale missing' && exit 1

echo "adding $1 locale"

pots=`for pot in po/pot/*.pot; do basename $pot .pot; done`

mkdir -p po/$1

for pot in $pots; do
  msginit -i po/pot/$pot.pot -o po/$1/$pot.po -l $1 --no-translator
done
