#!/usr/bin/php
<?php

/**
 * Reads from STDIN and finds similar-looking strings.
 *
 * Usage:
 *   cat *.pot | ../bin/find-similar-strings.php
 *
 * Context:
 * http://forum.civicrm.org/index.php/topic,34805.0.html
 */

// Default match threshold is 90% match.
$threshold = (! empty($argv[1]) ? $argv[1] : 90);

// Read all input from stdin.
$src = file_get_contents("php://stdin");

// http://stackoverflow.com/a/1070937/2387700
// Extract all "msgid" strings (they can be multi-line).
preg_match_all('/msgid\s+\"([^\"]*)\"/', $src, $matches);
$msgids = $matches[1];

// Sort the strings alphabetically, to make them easier to compare.
// sort($msgids);

foreach ($msgids as $key1 => $msgid1) {
  foreach ($msgids as $key2 => $msgid2) {
    $percent = 0;

    if ($msgid1 && $msgid2 && $msgid1 != $msgid2) {
      if (similar_text($msgid1, $msgid2, $percent)) {
        if ($percent > $threshold) {
          $percent = (int) $percent;
          echo "$msgid1 [$percent %]\n";
          echo "$msgid2 \n\n";
        }
      }
    }
  }

  // To avoid going through the strings twice, we unset the string
  // si that the inner-loop goes faster.
  unset($msgids[$key1]);
}
