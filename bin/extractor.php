#!/usr/bin/php
<?php

error_reporting(E_ALL & ~E_NOTICE & ~E_DEPRECATED);

/*
 +--------------------------------------------------------------------+
 | CiviCRM version 2.2                                                |
 +--------------------------------------------------------------------+
 | Copyright CiviCRM LLC (c) 2004-2010                                |
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
 * @copyright CiviCRM LLC (c) 2004-2010
 * $Id$
 *
 */

/**
 * ts() and {ts} calls extractor
 *
 * Extracts translatable strings from CiviCRM PHP source (ts() calls) and
 * Smarty templates ({ts} calls). Outputs a POT file on STDOUT, errors on
 * STDERR.
 */

$modules  = array('Case', 'Contribute', 'Event', 'Grant', 'Mailing', 'Member', 'Pledge');
$excluded = array('Bridge', 'Project', 'Touchstone');

$phpModifier    = "-iname '*.php' ";
$smartyModifier = "-iname '*.tpl' ";

$dir = $argv[2];

switch ($argv[1]) {
case '':
case 'full':
    break;
case 'core':
    foreach ($modules as $module) {
        $phpModifier    .= " -not -wholename           '*/CRM/$module/*'";
        $smartyModifier .= " -not -wholename '*/templates/CRM/$module/*'";
    }
    foreach ($excluded as $module) {
        $phpModifier    .= " -not -wholename           '*/CRM/$module/*'";
        $smartyModifier .= " -not -wholename '*/templates/CRM/$module/*'";
    }
    break;
case 'modules':
    $firstModule     = array_shift($modules);
    $phpModifier    .= "\( -wholename           '*/CRM/$firstModule/*'";
    $smartyModifier .= "\( -wholename '*/templates/CRM/$firstModule/*'";
    foreach ($modules as $module) {
        $phpModifier    .= " -or -wholename           '*/CRM/$module/*'";
        $smartyModifier .= " -or -wholename '*/templates/CRM/$module/*'";
    }
    foreach ($excluded as $module) {
        $phpModifier    .= " -not -wholename           '*/CRM/$module/*'";
        $smartyModifier .= " -not -wholename '*/templates/CRM/$module/*'";
    }
    $phpModifier    .= ' \)';
    $smartyModifier .= ' \)';
    break;
case 'helpfiles':
    $phpModifier    = '';
    $smartyModifier = "-iname '*.hlp' ";
    break;
default:
    exit("Wrong parameter specified. Choose one of full, core, modules or helpfiles.\n");
    break;
}

$phpExtractor    = dirname(__FILE__) . '/php-extractor.php';
$smartyExtractor = dirname(__FILE__) . '/smarty-extractor.php';

if ($phpModifier) {
    $command = "find $dir/CRM $dir/standalone $dir/packages/HTML/QuickForm $phpModifier -not -wholename '*/CRM/Core/I18n.php' -not -wholename '*/CRM/Core/Smarty/plugins/block.ts.php' | grep -v '/\.svn/' | sort | xargs $phpExtractor $dir";
    $phpPot = `$command`;
}

$command = "find $dir/templates $dir/xml $smartyModifier | grep -v '/\.svn/' | sort | xargs $smartyExtractor $dir";
$smartyPot = `$command`;

$originalArray = explode("\n", $phpPot . $smartyPot);

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


