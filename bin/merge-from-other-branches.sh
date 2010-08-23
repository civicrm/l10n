#!/bin/bash

dir=`mktemp -d`
pots=`ls -1 po/*.pot | cut -d/ -f2 | cut -d. -f1`
rels=`git branch | grep -o ' [0-9]\.[0-9]$' | sort -r`

langs="$1"
[ "$1" == "" ] && langs=`ls -1d po/?? po/??_?? | cut -d/ -f2`

for rel in $rels; do
  echo exporting $rel
  mkdir $dir/$rel
  git archive $rel | tar -xC $dir/$rel
done

for lang in $langs; do

  for rel in $rels; do
    if [ -a $dir/$rel/po/$lang ]; then
      echo creating $rel/$lang.po
      msgcat --no-location --use-first $dir/$rel/po/$lang/LC_MESSAGES/*.po | msgattrib --no-fuzzy --no-obsolete --translated > $dir/$rel/po/$lang.po
    fi
  done

  echo creating $lang.po
  find $dir/?.? -name $lang.po | sort -r | xargs msgcat --use-first > $dir/$lang.po

  for pot in $pots; do
    if [ -a po/$lang/LC_MESSAGES/$pot.po ]; then
      echo updating $lang/$pot.po
      msgcat --use-first po/$lang/LC_MESSAGES/$pot.po $dir/$lang.po | sponge po/$lang/LC_MESSAGES/$pot.po
      msgmerge --quiet --update po/$lang/LC_MESSAGES/$pot.po po/$pot.pot
      msgattrib --no-obsolete --no-wrap po/$lang/LC_MESSAGES/$pot.po | sponge po/$lang/LC_MESSAGES/$pot.po
    fi
  done

done

rm -r $dir

find po -name *~ -exec rm {} \;
