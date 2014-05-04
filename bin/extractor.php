#!/usr/bin/php
<?php

error_reporting(E_ALL & ~E_NOTICE & ~E_DEPRECATED);

/*
 +--------------------------------------------------------------------+
 | CiviCRM version 4.3                                                |
 +--------------------------------------------------------------------+
 | Copyright CiviCRM LLC (c) 2004-2013                                |
 +--------------------------------------------------------------------+
 | This file is a part of CiviCRM.                                    |
 |                                                                    |
 | CiviCRM is free software; you can copy, modify, and distribute it  |
 | under the terms of the GNU Affero General Public License           |
 | Version 3, 19 November 2007.                                       |
 |                                                                    |
 | CiviCRM is distributed in the hope that it will be useful, but     |
 | WITHOUT ANY WARRANTY; without even the implied warranty of         |
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.               |
 | See the GNU Affero General Public License for more details.        |
 |                                                                    |
 | You should have received a copy of the GNU Affero General Public   |
 | License along with this program; if not, contact CiviCRM LLC       |
 | at info[AT]civicrm[DOT]org. If you have questions about the        |
 | GNU Affero General Public License or the licensing of CiviCRM,     |
 | see the CiviCRM license FAQ at http://civicrm.org/licensing        |
 +--------------------------------------------------------------------+
*/

/**
 *
 * @package CRM
 * @copyright CiviCRM LLC (c) 2004-2013
 * $Id$
 *
 */

/**
 * ts() and {ts} calls extractor
 *
 * Extracts translatable strings from CiviCRM PHP source (ts() calls) and
 * Smarty templates ({ts} calls). Outputs a POT file on STDOUT, errors on
 * STDERR.
 *
 * Called from bin/create-pot-files.sh
 */

$phpModifier    = "-iname '*.php' ";
$jsModifier    = "-iname '*.js' ";
$smartyModifier = "\( -iname '*.tpl' -or -iname '*.hlp' \) ";

if ($argv[1] == 'base') {
    // 'base' is a special case for the common-base.pot file
    // it fetches a list of directories from bin/basedirs
    $phpDir = array();
    $jsDir = array();
    $tplDir = array();
    foreach (explode("\n", file_get_contents('bin/basedirs')) as $dir) {
        $phpDir[] = "-iwholename '*/CRM/$dir/*'";
        $jsDir[] = "-iwholename '*/templates/CRM/$dir/*'";
        $tplDir[] = "-iwholename '*/templates/CRM/$dir/*'";
    }
    $phpModifier    .= "\( " . implode(' -or ', $phpDir) . " \)";
    $jsModifier    .= "\( " . implode(' -or ', $jsDir) . " \)";
    $smartyModifier .= "\( " . implode(' -or ', $tplDir) . " \)";
}
elseif ($argv[1] == 'extension' || $argv[1] == 'install') {
    // nothing to do
    // see special handling of $command below.
}
else {
    $phpModifier    .= "-iwholename '*/CRM/{$argv[1]}/*'";
    $jsModifier .= "-iwholename '*/templates/CRM/{$argv[1]}/*'";
    $smartyModifier .= "-iwholename '*/templates/CRM/{$argv[1]}/*'";
}

$phpExtractor    = dirname(__FILE__) . '/php-extractor.php';
$jsExtractor = dirname(__FILE__) . '/js-extractor.php';
$smartyExtractor = dirname(__FILE__) . '/smarty-extractor.php';

$dir = $argv[2];

# PHP extraction
$command = "find $dir/CRM $dir/packages/HTML/QuickForm $phpModifier -not -wholename '*/CRM/Core/I18n.php' -not -wholename '*/CRM/Core/Smarty/plugins/block.ts.php' | grep -v '/\.svn/' | sort | xargs $phpExtractor $dir";

if ($argv[1] == 'extension') {
    $command = "find ./ | grep -E '\.(php|inc)/' | sort | xargs $phpExtractor $dir";
}
elseif ($argv[1] == 'install') {
    $command = "find $dir/*.php $dir/*.html | sort | xargs $phpExtractor $dir";
}

fwrite(STDERR, "Running: $command\n");
$phpPot = `$command`;

# JS extraction
$command = "find $dir/js $dir/templates $dir/xml $jsModifier | grep -v '/\.svn/' | sort | xargs $jsExtractor $dir";

if ($argv[1] == 'extension') {
    $command = "find ./ | grep -vE '\.(git|svn)/' | sort | xargs $jsExtractor $dir";
}

fwrite(STDERR, "Running: $command\n");
$jsPot = `$command`;

# Smarty/tpl extraction
$command = "find $dir/templates $dir/xml $smartyModifier | grep -v '/\.svn/' | sort | xargs $smartyExtractor $dir";

if ($argv[1] == 'extension') {
    $command = "find $dir/templates $dir/xml $smartyModifier | grep -vE '\.(svn|git)/' | sort | xargs $smartyExtractor $dir";
}

fwrite(STDERR, "Running: $command\n");
$smartyPot = `$command`;

$originalArray = explode("\n", $phpPot . $jsPot . $smartyPot);

$block = array();
$blocks = array();
$msgidArray = array();
$resultArray = array();

// rewrite the header to resultArray, removing it from the original
while ($originalArray[0] != '') {
    $resultArray[] = array_shift($originalArray);
}
$resultArray[] = array_shift($originalArray);

// break the POT contents into separate comments/msgid blocks
foreach ($originalArray as $line) {

    // if it's the end of a block, put the $block in $blocks and start a new one
    if ($line == '' and $block != array()) {

        $blocks[] = $block;
        $block = array();

    // else add the line to the proper $block part
    } else {

        // the lines in the POT file are either comments, single- and multiline
        // msgids or empty msgstrs; we ignore the msgstrs
        if (substr($line, 0, 1) == '#') {
            $block['comments'][] = $line;
        } elseif (substr($line, 0, 6) != 'msgstr') {
            $block['msgid'][] = $line;
        }

    }

}

// combine the msgid parts into single strings and build a new array with msgid
// as key and arrays with comments as value; drop the empty msgids
foreach ($blocks as $block) {
    $msgid = implode("\n", $block['msgid']);
    if ($msgid != 'msgid ""') {
        foreach ($block['comments'] as $comment) {
            $msgidArray[$msgid][] = $comment;
        }
    }
}

// combine the comments indicating the source files into single comment lines
foreach ($msgidArray as $msgid => $commentsArray) {
    $newCommentsArray = array();
    $sourceComments = array();
    foreach ($commentsArray as $comment) {
        if (substr($comment, 0, 3) == '#: ') {
            $sourceComments[] = substr($comment, 3);
        } else {
            $newCommentsArray[] = $comment;
        }
    }
    if (count($sourceComments)) {
        $newCommentsArray[] = '#: ' . implode(' ', $sourceComments);
    }
    $msgidArray[$msgid] = $newCommentsArray;
}

// build the rest of the $resultArray from the $msgidArray
foreach ($msgidArray as $msgid => $commentsArray) {
    foreach ($commentsArray as $comment) {
        $resultArray[] = $comment;
    }
    $resultArray[] = $msgid;
    // if it's a plural, add plural msgstr, else add singular
    if (strpos($msgid, "\nmsgid_plural ")) {
        $resultArray[] = "msgstr[0] \"\"\nmsgstr[1] \"\"\n";
    } else {
        $resultArray[] = "msgstr \"\"\n";
    }
}

// output the $resultArray to STDOUT
fwrite(STDOUT, implode("\n", $resultArray));
