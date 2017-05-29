#!/bin/bash
#
# commit-to-git - commits changes to the GIT repository and keeps track of authorship.
#
# Features:
#  - commit per PO file
#  - the commit "Author:" field is set according to the Last-Translator
#
# Usage:
#
#  - Change to the root directory of the git repository
#    $ cd l10n/
#
#  - Pull new translations from Transifex
#    $ tx pull -a
#
#  - Commit changes and push
#    $ ./bin/commit-to-git.sh
#    $ git push
#
# The next step is to compile the po files (to .mo) and to commit them to SVN.
#
# For more information:
# http://wiki.civicrm.org/confluence/display/CRMDOC/Localisation+stack
#
# Copyright (C) 2007-2010 Karel Zak <kzak@redhat.com>
# Adapted by Mathieu Lutfy <mathieu@bidon.ca> for CiviCRM translation files
# Original version: http://people.redhat.com/kzak/git-scripts/git-tp-sync
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

PO_NEW=$(git ls-files -o | grep '\.po' | sort)
PO_MOD=$(git ls-files -m | grep '\.po' | sort)

function get_author {
	# Transifex has an option to hide the email from .po files
	# So if we don't see a @ char, use <>, otherwise git won't commit.
	echo $(awk 'BEGIN { FS=": " } /Last-Translator/ { sub("\\\\n\"", ""); if ($2 ~ /@/) print $2; else print $2, " <>" }' "$1")
}

function do_commit {
	local POFILE="$1"
	local MSG="$2"
	local AUTHOR=$(get_author "$POFILE")

	git commit --author "$AUTHOR" -m "$MSG" "$POFILE"
}

for f in $PO_MOD; do
	do_commit "$f" "po: update $f (pulled from Transifex.net by CiviCRM l10n maintainer)"
done

for f in $PO_NEW; do
	git add "$f"
	do_commit "$f" "po: add $f (pulled from Transifex.net by CiviCRM l10n maintainer)"
done
