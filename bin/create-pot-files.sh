#!/bin/bash

function usage() {
  cat <<EOT
create-pot-files.sh - builds .pot files for CiviCRM.

Usage:
  ./bin/create-pot-files.sh [src dir] [dest dir]

Example:
  ./bin/create-pot-files.sh ~/repository/civicrm/  ~/repository/org.example.hello/pots/

NB: this program uses the "sponge" command, which you can get by installing the
"moreutils" package under Debian/Ubuntu.

EOT

  exit 1;
}

[ "$1" == "--help" ] && usage
[ "$1" == "-h" ] && usage

[ "$1" == "" ] && echo 'source dir missing'     && usage
test ! -e "$1" && echo 'source does not exist'  && usage
test ! -d "$1" && echo 'source not a directory' && usage

[ "$2" == "" ] && echo 'target dir missing'     && usage
test ! -e "$2" && echo 'target does not exist'  && usage
test ! -d "$2" && echo 'target not a directory' && usage

# Test whether the sponge command is installed
which sponge
if [ $? -ne 0 ]; then
  echo "Could not find the sponge command."
  usage
fi

root="$1"
potdir="$2"

header=`tempfile`
now=`date +'%F %R%z'`
sed "s/NOW/$now/" bin/header > $header

# $componets are the dirs with strings generating per-component $component.po files
components=`ls -1 $root/CRM $root/templates/CRM | grep -v :$ | grep -v ^$ | grep -viFf bin/basedirs | sort -u | xargs | tr [A-Z] [a-z]`

# Helper function for extracting strings from xml/templates
# which are mostly component-specific. We also run a msguniq on
# them because later msgcomm calls tends to filter out strings
# that repeat themselves in {component}.po files.
function smarty_extractor {
  ME=$1
  root=$2
  potdir=$3
  input=$4
  component=$5

  `dirname $ME`/smarty-extractor.php $root $root/$input >> ${potdir}/${component}.pot
  msguniq $potdir/${component}.pot | sponge $potdir/${component}.pot
}

# build the three XML-originating files

echo ' * building menu.pot'
cp $header $potdir/menu.pot
grep -h '<title>' $root/CRM/*/xml/Menu/*.xml | sed 's/^.*<title>\(.*\)<\/title>.*$/\1/'                                             | while read entry; do echo -e "msgctxt \"menu\"\nmsgid \"$entry\"\nmsgstr \"\"\n"; done >> $potdir/menu.pot
`dirname $0`/smarty-extractor.php $root $root/xml/templates/civicrm_navigation.tpl | grep '^msgid "' | sed 's/^msgid "\(.*\)"$/\1/' | while read entry; do echo -e "msgctxt \"menu\"\nmsgid \"$entry\"\nmsgstr \"\"\n"; done >> $potdir/menu.pot
msguniq $potdir/menu.pot | sponge $potdir/menu.pot

echo ' * building countries.pot'
cp $header $potdir/countries.pot
grep ^INSERT $root/xml/templates/civicrm_country.tpl     | cut -d\" -f4                                  | while read entry; do echo -e "msgctxt \"country\"\nmsgid \"$entry\"\nmsgstr \"\"\n"; done >> $potdir/countries.pot

echo ' * building provinces.pot'
cp $header $potdir/provinces.pot
grep '^(' $root/xml/templates/civicrm_state_province.tpl | cut -d\" -f4                                  | while read entry; do echo -e "msgctxt \"province\"\nmsgid \"$entry\"\nmsgstr \"\"\n"; done >> $potdir/provinces.pot

# make sure none of the province names repeat
# FIXME: add country name to context and skip this to do the Right Thing™
msguniq $potdir/provinces.pot | sponge $potdir/provinces.pot

# create base POT file
echo ' * building common-base.pot'
cp $header $potdir/common-base.pot
`dirname $0`/extractor.php base $root >> $potdir/common-base.pot
`dirname $0`/js-extractor.php $root $root/js >> $potdir/common-base.pot
msguniq $potdir/common-base.pot | sponge $potdir/common-base.pot

# create component POT files
for comp in $components; do
  echo ' * building '$comp'.pot'
  cp $header $potdir/$comp.pot
  `dirname $0`/extractor.php $comp $root >> $potdir/$comp.pot
  # drop strings already present in common-base.pot
  common=`tempfile`
  msgcomm $potdir/$comp.pot $potdir/common-base.pot > $common
  msgcomm --unique $potdir/$comp.pot $common | sponge $potdir/$comp.pot
  rm $common
done

# create common-components.pot with strings common to all components (but not base)
paths=''
for comp in $components; do
  paths="$paths $potdir/$comp.pot"
done
echo ' * building common-components.pot'
msgcomm $paths > $potdir/common-components.pot

# Add strings from message templates
echo ' * adding template strings'

smarty_extractor $0 $root $potdir 'xml/templates/civicrm_acl.tpl' 'common-base'
smarty_extractor $0 $root $potdir 'xml/templates/civicrm_data.tpl' 'common-base'
smarty_extractor $0 $root $potdir 'xml/templates/languages.tpl' 'common-base'
smarty_extractor $0 $root $potdir 'xml/templates/civicrm_msg_template.tpl' 'common-base'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/friend_*' 'common-base'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/uf_notify_*' 'common-base'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/case_*' 'case'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/contribution_*' 'contribute'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/event_*' 'event'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/participant_*' 'event'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/membership_*' 'member'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/pcp_*' 'pcp'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/petition_*' 'campaign'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/pledge_*' 'pledge'
smarty_extractor $0 $root $potdir 'xml/templates/message_templates/test_*' 'contribute'

# drop strings in common-components.pot from component POT files
for comp in $components; do
  common=`tempfile`
  msgcomm $potdir/$comp.pot $potdir/common-components.pot > $common
  msgcomm --unique $potdir/$comp.pot $common | sponge $potdir/$comp.pot
  rm $common
done

# drop empty files
find $potdir -empty -exec rm {} \;

# create drupal-civicrm.pot
echo ' * building drupal-civicrm.pot'
cp $header $potdir/drupal-civicrm.pot
find $root/drupal -name '*.inc' -or -name '*.install' -or -name '*.module' -or -name '*.php' | xargs `dirname $0`/php-extractor.php $root $root/CRM/Core/Permission.php >> $potdir/drupal-civicrm.pot

rm $header
