#!/bin/bash

langs=`ls -1d po/?? po/??_?? | cut -d/ -f2`

for lang in $langs; do
  echo compiling $lang
  msgcat po/$lang/LC_MESSAGES/*.po | msgfmt -o po/$lang/civicrm.mo -
done
