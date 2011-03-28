#!/bin/bash

langs=`ls -1d po/?? po/??_?? | cut -d/ -f2`
pots=`for pot in po/pot/*.pot; do basename $pot .pot; done`

for lang in $langs; do
  echo $lang
  for pot in $pots; do
    msgmerge --no-fuzzy-matching --quiet --update po/$lang/$pot.po po/pot/$pot.pot
  done
done
