#!/usr/bin/php
<?php

/**
 * Tags strings on Transifex.
 *
 * TODO: fetch existing tags, since PUT will remove any other existing tag.
 *
 * Usage:
 *   ./bin/tag-strings-on-transifex.php event v46
 */

global $argv;

$component = $argv[1];
$tag = $argv[2];

if (empty($component)) {
  die('Please specificy a component. Ex: event');
}

if (empty($tag)) {
  die('Please specificy a tag. Ex: v46');
}

if (! file_exists("./po/pot/{$component}.pot")) {
  die("Could not find ./po/pot/{$component}.pot, are you in the root of the l10n repo?");
}

if (! file_exists($_SERVER['HOME'] . "/.transifexrc")) {
  die("Could not find {$_SERVER['HOME']}/.transifexrc config file (for API credentials).");
}

$credentials = parse_ini_file($_SERVER['HOME'] . "/.transifexrc");

if (empty($credentials['username']) || empty($credentials['password'])) {
  die("transifexrc file is missing either the username or password.");
}

// Read all input from stdin.
$src = file_get_contents("./po/pot/{$component}.pot");

// http://stackoverflow.com/a/1070937/2387700
// Extract all "msgid" strings (they can be multi-line).
$regex = '/^msgid "(.*?)"\n(msgstr|msgid_plural)/sm';
preg_match_all($regex, $src, $matches);
$msgids = $matches[1];

$cpt = 0;

foreach ($msgids as $key => $msgid) {
  if (empty($msgid)) {
    continue;
  }

  // Only start doing the replacements if this looks like a multiline string.
  // We assume that multiline strings start with a "
  // There are some broken strings that start with a space, and we don't want
  // to remove the trailing space for now (otherwise the hash won't match).
  // Those strings need to be fixed in CiviCRM code upstream.
  if (preg_match('/^"/m', $msgid)) {
    $msgid = preg_replace('/^"/m', '', $msgid);
    $msgid = preg_replace('/"$/m', '', $msgid);
    $msgid = preg_replace('/\n/m', '', $msgid);
    $msgid = preg_replace('/^ /', '', $msgid);
  }

  $hash = md5($msgid . ':');

  echo "$cpt: $msgid ($hash)\n";

  $data = array();
  $data[] = array(
    'tags' => array('v46'),
    'source_entity_hash' => $hash,
  );

  $cpt++;

  $url = "https://www.transifex.com/api/2/project/civicrm/resource/$component/source/";
  $data = json_encode($data);

  $ch = curl_init();

  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_USERPWD, $credentials['username'] . ":" . $credentials['password']);
  curl_setopt($ch, CURLOPT_POST, TRUE);
  curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
  curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
  curl_setopt($ch, CURLOPT_HTTPHEADER, array(
    'Content-Type: application/json',
    'Content-Length: ' . strlen($data)));

  $content = curl_exec($ch);
  $result = json_decode($content, TRUE);

  // Should respond "OK".
  // TODO: do better error checking.
  echo print_r($content, 1);
}
