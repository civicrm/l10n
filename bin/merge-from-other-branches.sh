#!/bin/bash

dir=`mktemp -d`
pots=`for pot in po/pot/*.pot; do basename $pot .pot; done`
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
      msgcat --no-location --use-first $dir/$rel/po/$lang/*.po | msgattrib --no-fuzzy --no-obsolete --translated > $dir/$rel/po/$lang.po
    fi
  done

  echo creating $lang.po
  find $dir/?.? -name $lang.po | sort -r | xargs msgcat --use-first > $dir/$lang.po

  for pot in $pots; do
    if [ -a po/$lang/$pot.po ]; then
      echo updating $lang/$pot.po
      msgcat --use-first po/$lang/$pot.po $dir/$lang.po | sponge po/$lang/$pot.po
      msgmerge --quiet --update po/$lang/$pot.po po/pot/$pot.pot
      msgattrib --no-obsolete --no-wrap po/$lang/$pot.po | sponge po/$lang/$pot.po
    fi
  done

done

rm -r $dir

find po -name *~ -exec rm {} \;
