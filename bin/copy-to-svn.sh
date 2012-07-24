#!/bin/sh

# copy-to-svn - copies the compiled .mo files to the SVN l10n repository.
#
# Usage:
#
#  - Change to the root directory of the git repository
#    $ cd l10n/
#
#  - Copy the files
#    $ ./bin/copy-to-svn.sh /path/to/svn/l10n
#
#  - Change to the l10n repository and commit.
#
# For more information:
# http://wiki.civicrm.org/confluence/display/CRMDOC/Localisation+stack

SVNDEST=$1

if [ -z "$SVNDEST" ]; then
  echo "Missing destination directory for the l10n repository."
  echo "usage: ./bin/copy-to-svn.sh /path/to/svn/l10n/"
  exit 1
fi

if [ ! -d "$SVNDEST/fr_FR" ]; then
  echo "$SVNDEST: does not seem to be the l10n directory."
  echo "usage: ./bin/copy-to-svn.sh /path/to/svn/l10n/"
  exit 1
fi

# Start by copying base languages (fr, es, de, ..)
for i in po/??/civicrm.mo; do
  LANG=`echo $i | sed 's|po/\(..\)/civicrm.mo|\1|'`
  REGION=`echo $LANG | tr [:lower:] [:upper:]`

  # Handle a lot of exceptions
  if [ "$LANG" = "he" ]; then
    # Hebrew / Israel
    REGION="IL"
  elif [ "$LANG" = "af" ]; then
    # Afrikaans / South Africa
    REGION="ZA"
  elif [ "$LANG" = "be" ]; then
    # Belarus
    REGION="BY"
  elif [ "$LANG" = "ca" ]; then
    # Catalan / Spain
    REGION="ES"
  elif [ "$LANG" = "cs" ]; then
    # Czech
    REGION="CZ"
  elif [ "$LANG" = "da" ]; then
    # Danish
    REGION="DK"
  elif [ "$LANG" = "ar" ]; then
    # Arabic / Egypt (not sure why.. because of soap operas?)
    REGION="EG"
  elif [ "$LANG" = "ja" ]; then
    # Japanese
    REGION="JP"
  elif [ "$LANG" = "el" ]; then
    # Greek
    REGION="GR"
  elif [ "$LANG" = "et" ]; then
    # Estonian
    REGION="EE"
  elif [ "$LANG" = "hi" ]; then
    # Hindi / India
    REGION="IN"
  elif [ "$LANG" = "sl" ]; then
    # Slovenian
    REGION="SI"
  elif [ "$LANG" = "sq" ]; then
    # Albanian
    REGION="AL"
  elif [ "$LANG" = "sv" ]; then
    # Swedish
    REGION="SE"
  elif [ "$LANG" = "vi" ]; then
    # Vietnam
    REGION="VN"
  fi

  COPYDEST="$SVNDEST/${LANG}_${REGION}/civicrm.mo"

  if [ -f $COPYDEST ]; then
    cp -v $i $COPYDEST
  else
    echo "WARNING: not copying $i, since ${LANG}_${REGION} does not exist in l10n SVN."
    echo "       The directory for new languages must be created manually as a way to"
    echo "       validate the fact that we are adding a new official language to CiviCRM."
  fi
done

# Copy regional languages (fr_CA, es_MX, ..)
for i in po/??_??/civicrm.mo; do
  LANG=`echo $i | sed 's|po/\(.._..\)/civicrm.mo|\1|'`
  REGION=`echo $LANG | tr [:lower:] [:upper:]`

  COPYDEST="$SVNDEST/${LANG}/civicrm.mo"

  if [ -f $COPYDEST ]; then
    cp -v $i $COPYDEST
  else
    echo "WARNING: not copying $i, since ${LANG}_${REGION} does not exist in l10n SVN."
    echo "       The directory for new languages must be created manually as a way to"
    echo "       validate the fact that we are adding a new official language to CiviCRM."
  fi
done

