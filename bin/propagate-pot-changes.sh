#!/bin/bash

langs=`ls -1d po/?? po/??_?? | cut -d/ -f2`
pots=`ls -1 po/*.pot | cut -d/ -f2 | cut -d. -f1`

for lang in $langs; do
  echo; echo $lang
  for pot in $pots; do
    msgmerge -U --no-wrap po/$lang/LC_MESSAGES/$pot.po po/$pot.pot
  done
done
