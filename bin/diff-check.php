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

  if (substr($line, 1) == "msgid \"\"\n") {
    continue;
  }

  if (substr($line, 2, 17) == 'POT-Creation-Date') {
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

  // We were in an add/remove state, and the state changed, so flush the buffer
  if ($op == '+' && $state == STATE_REMOVING) {
    strings_remove($buffer, $strings);
    $state = STATE_ADDING;
    $buffer = '';
  }
  elseif ($op == '-' && $state == STATE_ADDING) {
    strings_add($buffer, $strings);
    $state = STATE_REMOVING;
    $buffer = '';
  }
  elseif ($op == ' ' && $state != STATE_NEUTRAL) {
    /**
     * If we were in an add/remove, and we have lines that are neither (just context lines),
     * then we should flush our buffer.
     *
     * For example:
     * +msgid "Uninstall"
     * msgstr ""
     * 
     * #: CRM/Admin/Form/Extensions.php CRM/Admin/Page/Extensions.php
     */
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

  /**
   * Example:
   * -msgid "Global Settings"
   * -msgstr ""
   * -
   * -#: CRM/Admin/Form/CMSUser.php
   */
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
    // Ex: +msgid "Must be an integer"
    $line = substr($line, 1);

    // remove trailing newline
    $line = str_replace("\n", '', $line);

    // remove msgid prefix
    $line = str_replace('msgid ', '', $line);

    // remove msgctxt prefix
    $line = str_replace('msgctxt "menu"', '', $line);
    $line = str_replace('msgctxt "province"', '', $line);

    // remove the opening or closing quotes
    $line = preg_replace('/^"/', '', $line);
    $line = preg_replace('/"$/', '', $line);

    $buffer .= $line;
  }
}

$added = 0;
$removed = 0;
$unchanged = 0;

// Show removed strings
foreach ($strings as $key => $val) {
  if ($val < 0) {
    $removed++;
    echo "REMOVED: " . $key . "\n";
  }
  elseif ($val == 0) {
    // Count unchanged
    $unchanged++;
  }
}

// Show added strings
foreach ($strings as $key => $val) {
  if ($val > 0) {
    $added++;
    echo "ADDED: " . $key . "\n";
  }
}

echo "Added: $added\n";
echo "Removed: $removed\n";
echo "Unchanged: $unchanged\n";

