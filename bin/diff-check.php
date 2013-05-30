#!/usr/bin/php
<?php

/**
 * Reads from STDIN and checks how many strings were really added or removed.
 *
 * Usage:
 *   git diff --patience po/pot/admin.pot | ./bin/diff-check.php
 */

define('STATE_NEUTRAL',  'N');
define('STATE_ADDING',   '+');
define('STATE_REMOVING', '-');

$state = STATE_NEUTRAL;
$strings = array();
$buffer = "";
$counter = 0;

function strings_add($buffer, &$strings) {
  if (! isset($strings[$buffer])) {
    $strings[$buffer] = 0;
  }
  $strings[$buffer]++;
}

function strings_remove($buffer, &$strings) {
  if (! isset($strings[$buffer])) {
    $strings[$buffer] = 0;
  }
  $strings[$buffer]--;
}

while ($line = fgets(STDIN)) {
  $counter++;
  $op = substr($line, 0, 1);

  // Skip lines starting with a space. It means the string didn't change.
  if (substr($line, 0, 1) == ' ') {
    continue;
  }

  // Skip comments, then can change if a new file references the same string
  // and would show as a string added/removed from the file.
  if (substr($line, 1, 1) == '#') {
    continue;
  }

  // Skip: diff --git a/po/pot/admin.pot b/po/pot/admin.pot
  if (substr($line, 0, 4) == 'diff') {
    continue;
  }

  // Skip: index a5b4ddb..a043b23 100644
  if (substr($line, 0, 5) == 'index') {
    continue;
  }

  if (substr($line, 0, 3) == '+++' || substr($line, 0, 3) == '---') {
    continue;
  }

  if (substr($line, 0, 3) == '@@ ') {
    continue;
  }

  if (substr($line, 1) == "msgstr \"\"\n") {
    continue;
  }

  if ($state == STATE_NEUTRAL) {
    if ($op == '+') {
      $state = STATE_ADDING;
    }
    elseif ($op == '-') {
      $state = STATE_REMOVING;
    }
  }

  if ($op == '+' && $state == STATE_REMOVING) {
    strings_add($buffer, $strings);
    $state = STATE_NEUTRAL;
    $buffer = '';
  }
  elseif ($op == '-' && $state == STATE_ADDING) {
    strings_remove($buffer, $strings);
    $state = STATE_NEUTRAL;
    $buffer = '';
  }

  if (empty($line) || preg_match('/^\+$/', $line) || preg_match('/^-$/', $line)) {
    if ($state == STATE_REMOVING) {
      strings_remove($buffer, $strings);
      $state = STATE_NEUTRAL;
      $buffer = '';
    }
    elseif ($state == STATE_ADDING) {
      strings_add($buffer, $strings);
      $state = STATE_NEUTRAL;
      $buffer = '';
    }
  }

  if ($state == STATE_NEUTRAL) {
    continue;
  }

  if ($line) {
    // remove the first char, since it's a + or -
    $line = substr($line, 1);
    $buffer .= $line;
  }
}

$added = 0;
$removed = 0;
$unchanged = 0;

foreach ($strings as $key => $val) {
  if ($val < 0) {
    $removed++;
    echo "REMOVED: " . $key . "\n";
  }
  elseif ($val > 0) {
    $added++;
    echo "ADDED: " . $key . "\n";
  }
  else {
    $unchanged++;
  }
}

echo "Added: $added\n";
echo "Removed: $removed\n";
echo "Unchanged: $unchanged\n";

