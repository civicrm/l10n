#!/bin/bash

langs=`ls -1d po/?? po/??_?? | cut -d/ -f2`

for lang in $langs; do
  echo compiling $lang
  msgcat --use-first po/$lang/*.po | msgfmt -o po/$lang/civicrm.mo -
done
