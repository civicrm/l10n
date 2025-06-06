#!/bin/bash
set -e

#####################################################################
## Variables

## Source code path
SRC=

## Output path
POTDIR=

## The component *.pot files are based roughly on CRM/Foo templates/CRM/Foo.
COMPONENT_POTS="Admin Badge Batch Campaign Case Contribute Event Extension Financial Mailing Member PCP Pledge Project Queue Report"

## The adhoc *.pot files are based on clear file list (but may have some special/less predictable rules).
ADHOC_POTS="common-base countries install menu provinces grant"

## The magic *.pot files are derived from other *.pot files.
MAGIC_POTS="common-components"

## List of chosen *.pot files
POTS=

## Header file to prepend to any *.pot
HEADER_TMPL=bin/header
HEADER=

## Flags to control which actions are performed
DO_SCAN=
DO_DIGEST=
DO_CLEANUP=
FORCE=

#####################################################################
function usage() {
  cat <<EOT
create-pot-files.sh - builds .pot files for CiviCRM.

Usage:
  ./bin/create-pot-files.sh [options] [srcdir] [destdir] [pot1...]

Examples:
  ./bin/create-pot-files.sh ~/repository/civicrm/ ~/repository/l10n/po/pot/
  ./bin/create-pot-files.sh -sd ~/repository/civicrm/ ~/repository/l10n/po/pot/ common-base Admin Contribute

Options:
  -s    Scan targets for strings (Pass #1)
  -d    Digest/dedupe scanned strings (Pass #2)
  -c    Cleanup temp files
  -a    All (scan+digest+cleanup; default)
  -f    Force (Ignore cached results from previous scan)
  -h    Help

Targets:
  $COMPONENT_POTS
  $ADHOC_POTS $MAGIC_POTS

Although you should probably not call this directly. Use build-unified-pots.sh
if you are exporting the strings to Transifex.
http://wiki.civicrm.org/confluence/display/CRMDOC/Pushing+new+strings+to+Transifex

EOT

  exit 1;
}

#####################################################################
## Assert that CLI dependencies are met
function check_deps() {
  for cmd in sponge civistrings msgcomm msguniq mktemp tr grep cut date sed ; do
    if ! which $cmd > /dev/null ; then
      echo "Missing required command: $cmd"
      echo
      case "$cmd" in
        sponge)
          echo 'This program uses the "sponge" command which you can get by installing the'
          echo '"moreutils" package under Debian/Ubuntu or by visting'
          echo 'https://joeyh.name/code/moreutils/'
          ;;
        civistrings)
          echo 'This program uses the "civistrings" command which is bundled with buildkit.'
          echo 'You can download it separately from https://github.com/civicrm/civistrings'
      esac
      exit 1
    fi
  done
}

#####################################################################
## civistrings wrapper with some default options
function _civistrings() {
  civistrings --header="$HEADER" "$@"
}

#####################################################################
## usage: HEADER=$(build_header "$HEADER_TMPL")
function build_header() {
  local tmpl="$1"
  local out="$POTDIR/.header"
  local now=`date +'%F %R%z'`

  cat "$tmpl" \
    | sed "s/NOW/$now/" \
    > "$out"

  echo "$out"
}

#####################################################################
## Build an individual POT file
## usage: build_raw_pot <name>
## example: build_raw_pot Mailing
## example: build_raw_pot install
function build_raw_pot() {
  local name="$1"
  local filepath="$POTDIR/.raw-"$(echo $name | tr '[:upper:]' '[:lower:]').pot

  if [ -f "$filepath" -a -z "$FORCE" ]; then
    echo "[[ Found raw strings for ${name} from previous scan. ]]"
    return
  fi

  echo "[[ Building raw strings for ${name} ]]"

  case "$name" in

    ## Adhoc targets, sorted alphabetically

    common-base)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/{ACL,Activity,Block,common,Contact,Core} \
        {CRM,templates/CRM}/{Custom,Dashlet,Dedupe,Export,Form,Friend} \
        {CRM,templates/CRM}/{Group,Import,Logging,Note,Price,Profile} \
        {CRM,templates/CRM}/{Relationship,SMS,Standalone,Tag,UF,Utils} \
        ang/crmApp* \
        ang/crmAttachment* \
        ang/crmDashboard* \
        ang/crmUi* \
        ang/exportui/ \
        ang/afform/ \
        ext/standaloneusers \
        managed \
        xml/templates/civicrm_acl.tpl \
        xml/templates/civicrm_data.tpl \
        xml/templates/languages.tpl \
        xml/templates/civicrm_msg_template.tpl \
        xml/templates/message_templates/friend_* \
        xml/templates/message_templates/uf_notify_* \
        sql/civicrm_data/ \
        schema/{ACL,Activity,Batch,Contact,Core,Dedupe,Friend} \
        packages/HTML/QuickForm \
        partials/ \
        js/

      ## The CRM/Upgrade folder includes *.tpl files which, for some reason,
      ## have been omitted from past pot's. Omitting these requires more
      ## precise file selection.
      find CRM/Upgrade -name '*.php' | _civistrings -ao "$filepath" -
      _civistrings -ao "$filepath" templates/CRM/Upgrade
      ;;

    common-components)
      ## Not yet; handled in the digest phase. That why it's in MAGIC_POTS
      return
      ;;

    countries)
      cat "$HEADER" > "$filepath"
      grep ^INSERT xml/templates/civicrm_country.tpl \
        | cut -d\" -f4 \
        | while read entry; do
          echo -e "msgctxt \"country\"\nmsgid \"$entry\"\nmsgstr \"\"\n"
        done \
        >> "$filepath"
      ## Hmm, if civicrm_country.tpl used {ts}, then we could just call "civistrings --msgctxt=country"
      ;;

    # This is an exception, because it would require moving the existing Transifex resource
    # we will probably need to do so at some point, but for now the ext uses plain 'ts()' anyway
    grant)
      _civistrings -o "$filepath" \
        ext/civigrant
      ;;

    install)
      _civistrings -o "$filepath" \
        setup/
      ;;

    menu)
      cat "$HEADER" > "$filepath"
      grep -h '<title>' CRM/*/xml/Menu/*.xml \
        | sed 's/^.*<title>\(.*\)<\/title>.*$/\1/' \
        | while read entry; do
          echo -e "msgctxt \"menu\"\nmsgid \"$entry\"\nmsgstr \"\"\n"
        done \
        >> "$filepath"
      grep -h '<desc>' CRM/*/xml/Menu/*.xml \
        | sed 's/^.*<desc>\(.*\)<\/desc>.*$/\1/' \
        | while read entry; do
          echo -e "msgctxt \"menu\"\nmsgid \"${entry//\"/\\\"}\"\nmsgstr \"\"\n"
        done \
        >> "$filepath"
      _civistrings --msgctxt=menu xml/templates/civicrm_navigation.tpl -ao "$filepath"
      ;;

    provinces)
      cat "$HEADER" > "$filepath"
      grep '^(' xml/templates/civicrm_state_province.tpl \
        | cut -d\" -f4 \
        | while read entry; do
          echo -e "msgctxt \"province\"\nmsgid \"$entry\"\nmsgstr \"\"\n"
        done \
        >> "$filepath"
        ## Hmm, if civicrm_country.tpl used {ts}, then we could just call "civistrings --msgctxt=country"
      ;;

    ## Standard targets, sorted alphabetically

    Admin)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ang/crmCxn/ \
        ang/crmStatusPage/ \
        ang/api4Explorer/ \
        settings/
      ;;

    Campaign)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ext/civi_campaign \
        schema/Campaign \
        xml/templates/message_templates/petition_*
      ;;

    Case)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ang/crmCase* \
        ext/civi_case \
        schema/Case \
        xml/templates/message_templates/case_*
      ;;

    Contribute)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ext/civi_contribute \
        schema\Contribute \
        schema\Financial \
        schema\Price \
        xml/templates/message_templates/contribution_* \
        xml/templates/message_templates/payment_* \
        xml/templates/message_templates/test_*
      ;;

    Event)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ext/civi_event \
        schema/Event \
        xml/templates/message_templates/event_* \
        xml/templates/message_templates/participant_*
      ;;

    Mailing)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ext/civi_mail \
        schema/Mailing \
        schema/SMS \
        ang/crmMailing*
      ;;

    Member)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        ext/civi_member \
        schema/Member \
        xml/templates/message_templates/membership_*
      ;;

    PCP)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        schema/PCP \
        xml/templates/message_templates/pcp_*
      ;;

    Pledge)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        schema/Pledge \
        xml/templates/message_templates/pledge_*
      ;;

    Queue)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        schema/Queue
      ;;

    Report)
      _civistrings -o "$filepath" \
        {CRM,templates/CRM}/$name \
        schema/Report
      ;;

    *)
      if echo " $COMPONENT_POTS " | grep -q " $name " > /dev/null ; then
        _civistrings -o "$filepath" {CRM,templates/CRM}/$name
      else
        echo "unrecognized pot: $name"
      fi
      ;;

  esac

  find "$filepath" ! -empty | while read f; do
    msguniq "$filepath" | sponge "$filepath"
  done
}

#####################################################################
## usage: make_stat <name>
## example: make_stat Mailing
function make_stat() {
  local name="$1"
  local filepath="$POTDIR/.raw-"$(echo $name | tr '[:upper:]' '[:lower:]').pot
  grep ^msgid "$filepath" | sort -u > "$filepath.msgid"
  grep '^#:' "$filepath" | sed 's/#://' | tr ' ' '\n' | sort -u > "$filepath.files"
}

#####################################################################
## Scan .raw-*.pot for common strings and put them in common-components.pot
## usage: build_common_components
function build_common_components() {
  echo "[[ Building common-components.pot ]]"
  local paths=""
  local has_multiple=0
  for comp in $COMPONENT_POTS ; do
    local rawfile=".raw-"$(echo $comp | tr '[:upper:]' '[:lower:]').pot
    if [ -f "$rawfile" ]; then
      paths="$paths $rawfile"
      has_multiple=1
    fi
  done
  if [ $has_multiple -eq 1 ]; then
    msgcomm $paths > .raw-common-components.pot
  else
    cat $HEADER > .raw-common-components.pot
  fi
}

#####################################################################
## example: build_final_pot Mailing
## example: build_final_pot install
function build_final_pot() {
  local name="$1"
  local rawpath="$POTDIR/.raw-"$(echo $name | tr '[:upper:]' '[:lower:]').pot
  local finalpath="$POTDIR/"$(echo $name | tr '[:upper:]' '[:lower:]').pot
  local tmpfile=`mktemp`

  echo "[[ Building final strings for ${name} ]]"

  cp -f "$rawpath" "$finalpath"

  if echo " $COMPONENT_POTS " | grep -q " $name " > /dev/null ; then
    msgcomm "$finalpath" .raw-common-components.pot > $tmpfile
    msgcomm --unique "$finalpath" $tmpfile | sponge "$finalpath"

    msgcomm "$finalpath" .raw-common-base.pot | sponge $tmpfile
    msgcomm --unique "$finalpath" $tmpfile | sponge "$finalpath"

  elif [ "$name" == "install" ]; then
    msgcomm "$finalpath" .raw-common-base.pot | sponge $tmpfile
    msgcomm --unique "$finalpath" $tmpfile | sponge "$finalpath"
  fi

  rm -f "$tmpfile"
}

#####################################################################
## Delete temp files
function do_cleanup() {
  echo "[[ Cleanup temp files ]]"
  rm .header .raw*pot -f
}

#####################################################################
## Main

[ "$1" == "--help" ] && usage
[ "$1" == "-h" ] && usage

check_deps

FOUND_ACTION=
while getopts "asfdc" opt; do
  case $opt in
    a)
      DO_SCAN=1
      DO_DIGEST=1
      DO_CLEANUP=1
      FOUND_ACTION=1
      ;;
    s)
      DO_SCAN=1
      FOUND_ACTION=1
      ;;
    d)
      DO_DIGEST=1
      FOUND_ACTION=1
      ;;
    c)
      DO_CLEANUP=1
      FOUND_ACTION=1
      ;;
    f)
      FORCE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ -z "$FOUND_ACTION" ]; then
  DO_SCAN=1
  DO_DIGEST=1
  DO_CLEANUP=1
fi

shift $((OPTIND-1))

[ "$1" == "" ] && echo 'source dir missing'     && usage
test ! -e "$1" && echo 'source does not exist'  && usage
test ! -d "$1" && echo 'source not a directory' && usage

[ "$2" == "" ] && echo 'target dir missing'     && usage
test ! -e "$2" && echo 'target does not exist'  && usage
test ! -d "$2" && echo 'target not a directory' && usage

# use absolute paths so that we can chdir/pushd
SRC=$(php -r 'echo realpath($argv[1]);' "$1")
POTDIR=$(php -r 'echo realpath($argv[1]);' "$2")
HEADER=$(build_header "$HEADER_TMPL")
## TODO: substitute "NOW" in HEADER
shift 2

if [ -z "$1" ]; then
  POTS="$COMPONENT_POTS $ADHOC_POTS $MAGIC_POTS"
else
  POTS="$@"
fi

if [ -n "$DO_SCAN" ]; then
  pushd "$SRC" >> /dev/null
    for POT in $POTS ; do
      build_raw_pot "$POT"
    done
  popd >> /dev/null
fi

if [ -n "$DO_DIGEST" ]; then
  pushd "$POTDIR" >> /dev/null
    build_common_components
    for POT in $POTS ; do
      build_final_pot "$POT"
    done
  popd >> /dev/null
fi

if [ -n "$DO_CLEANUP" ]; then
  pushd "$POTDIR" >> /dev/null
    do_cleanup
  popd >> /dev/null
fi
