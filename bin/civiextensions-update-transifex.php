#!/usr/bin/env php
<?php

/**
 * For all civicrm native extensions (cms-agnostic) published in
 * the civicrm.org/extensions directory,
 *
 * - clone the repo and extract the strings from the latest version,
 * - the extracted .pot files are stored in the civicrm-l10n-extensions
 *   directory,
 * - check if the tag was already processed,
 * - push the source strings to Transifex (project/civicrm_extensions),
 * - pull translated strings from Transifex
 * - add the new extensions to git.
 * - TODO: commit new translated strings for all extensions (using commit-to-git.sh).
 *
 * Depends on packages: php5-cli, moreutils, gettext.
 * Depends on repositories: l10n (until those scripts are moved to civix).
 *
 * For more information, view the README.md and:
 * https://issues.civicrm.org/jira/browse/INFRA-104
 */

if (empty($_SERVER['HOME'])) {
  echo "ERROR: \$_SERVER['HOME'] was not set. I'm lost.\n";
  exit(1);
}

// civicrm.org URL that lists us the git repos for extensions
define('CIVIEXTENSIONS_REPO_LIST', 'https://civicrm.org/extdir/git-urls.json');

// cache directory on this server where we clone git repos
// no need for a trailing slash
define('CIVIEXTENSIONS_CACHE_DIR', $_SERVER['HOME'] . "/repositories/cache");

// data directory where we keep track of processed tags
// to avoid extracting strings on known versions over and over.
define('CIVIEXTENSIONS_METADATA_DIR', $_SERVER['HOME'] . '/repositories/.civiextensions-metadata');

// repository with the .pot files generated
// that we will commit to git to have a history similar to l10n/pot/
// i.e.: po/[shortname]/xx_XX/[shortname].po
define('CIVIEXTENSIONS_L10N_REPO_DIR', $_SERVER['HOME'] . '/repositories/civicrm-l10n-extensions/');

function main() {
  // cache directory on this server where we clone git repos
  // no need for a trailing slash
  $download_dir = CIVIEXTENSIONS_CACHE_DIR;

  if (! file_exists($download_dir)) {
    mkdir($download_dir, 0755, TRUE);
  }

  // data directory where we keep track of processed tags
  // to avoid extracting strings on known versions over and over.
  if (! file_exists(CIVIEXTENSIONS_METADATA_DIR)) {
    mkdir(CIVIEXTENSIONS_METADATA_DIR, 0755, TRUE);
  }

  // repository with the .pot files generated
  // that we will commit to git to have a history similar to l10n/pot/
  // i.e.: po/[shortname]/xx_XX/[shortname].po
  $l10n_repo_dir = CIVIEXTENSIONS_L10N_REPO_DIR;

  if (! file_exists($l10n_repo_dir)) {
    echo "$l10n_repo_dir: directory does not exist. You need to clone the civicrm-l10n-extensions repo first in $l10n_repo_dir.\n";
    exit(1);
  }

  // Fetch the list of repos and clone locally
  $gitrepos_raw = file_get_contents(CIVIEXTENSIONS_REPO_LIST);

  if (! $gitrepos_raw) {
    echo "ERROR: could not read the list of repositories for extensions.";
    exit(1);
  }

  $gitrepos = json_decode($gitrepos_raw);

  foreach ($gitrepos as $gitinfo) {
    // Only extract extensions that are ready for automatic distribution
    if ($gitinfo->ready != 'ready') {
      continue;
    }

    // Risky security
    if (! preg_match('/^[-_0-9-a-zA-Z\.:\/]+$/', $gitinfo->git_url)) {
      echo "Skipping suspicious repo URL: {$gitinfo->git_url}\n";
      continue;
    }

    $reponame = basename($gitinfo->git_url);
    $reponame = preg_replace('/\.git$/', '', $reponame);

    $extdir = escapeshellarg("$download_dir/$reponame");

    echo "Repo: $extdir\n";

    if (file_exists("$download_dir/$reponame")) {
      echo "* Updating with git fetch --all..\n";
      system("cd $extdir; git fetch -q --all");
    }
    else {
      // Runs: git clone git://example.org/foo.git ~/repositories/foo-hash
      echo "* New repo (or not in cache), cloning it...\n";
      system('git clone ' . escapeshellarg($gitinfo->git_url) . ' ' . $extdir);
    }

    // Get the short name from the info.xml
    // TODO: fix civihr use-case (packages).
    // NB: do not use $extdir, since it is a shell-escaped variable.
    $shortname = civiextensions_getname_from_xml("$download_dir/$reponame");

    if (! $shortname) {
      print "Info: could not get short name for $reponame, skipping.\n";
      continue;
    }

    // NB: we check for tags having the format: v1.0 1.0 1.0.0
    // meaning that we ignore anything such as 1.0-beta1
    // since the alphabetical sort would not make sense, and we
    // cannot predict what funky tags people may use.
    $tag = system("cd $extdir; git tag | grep -E '^v?[-\.0-9]+$' | sort -n | tail -1");

    // Do not process the extension unless it is a new tag
    $last_processed_tag = civiextensions_get_last_processed_tag($shortname);

    if ($tag <= $last_processed_tag) {
      echo "* Skipping: tag already processed: $tag\n";
      continue;
    }

    echo "* Processing tag: $tag ...\n";
    system("cd $extdir; git checkout tags/" . $tag);

    // If the directory does not exists, we assume that it means
    // that we also need to create the resource in Transifex.
    // If it's a new resource, it needs to be added after pot generation.
    $add_to_transifex = FALSE;

    if (! file_exists("$l10n_repo_dir/po/$shortname")) {
      $add_to_transifex = TRUE;
    }

    // Extract the ts() strings
    system("cd $extdir; env POTDIR=$l10n_repo_dir/po CIVI_KEEP_IT_QUIET=1 ~/bin/l10n/bin/create-pot-files-extensions.sh");

    // Send strings to Transifex, add new resource if necessary
    // NB: we do not pull the strings at this point, it will be done
    // by another script that pulls in translations every day.
    if ($add_to_transifex) {
      print "Adding Transifex resource: $shortname\n";
      system("cd $l10n_repo_dir; tx set --auto-local -r civicrm_extensions.$shortname 'po/$shortname/<lang>/$shortname.po' --source-lang en --source-file po/$shortname/pot/$shortname.pot --execute");
      system("cd $l10n_repo_dir; git add .tx/config; git commit -m 'Adding new extension: $shortname'");
    }

    system("cd $l10n_repo_dir; tx push -s -r civicrm_extensions.$shortname");

    // Commit to civicrm-l10n-extensions repo and push
    system("cd $l10n_repo_dir; git add $l10n_repo_dir/po/$shortname; git commit -m 'Automatic commit for version $tag of extension $shortname'");
    system("cd $l10n_repo_dir; git push origin master");

    civiextensions_set_last_processed_tag($shortname, $tag);
    echo "* Done, yay!\n\n";
  }
}

/**
 * Returns the "file" attribute from the info.xml of
 * an extension. Ex: for ca.bidon.i18nexample, it will
 * return "i18nexample".
 *
 * We cannot assume that it is the last bit of the name,
 * because many extensions have a repo name that does
 * not match their namespace (ex: civivolunteer).
 *
 * @param String $extdir Path to the extension.
 * @returns Mixed File attribute, false if none found.
 */
function civiextensions_getname_from_xml($extdir) {
  if (! file_exists($extdir . '/info.xml')) {
    print "Could not find info.xml\n";
    return FALSE;
  }

  $info = simplexml_load_file($extdir . '/info.xml');

  if (! $info) {
    print "Could not parse info.xml\n";
    return FALSE;
  }

  if (! preg_match('/^[A-Za-z0-9][-_A-Za-z0-9]*$/', $info->file)) {
    print "File attribute from info.xml is suspicious\n";
    return FALSE;
  }

  return $info->file;
}

/**
 * Fetches the last processed tag that is stored in the
 * ~/repositories/.civiextensions-tags/$shorname.tag
 */
function civiextensions_get_last_processed_tag($shortname) {
  $data_dir = CIVIEXTENSIONS_METADATA_DIR;
  $filename = "$data_dir/{$shortname}.tag";

  if (! file_exists($filename)) {
    return FALSE;
  }

  $tag = file_get_contents($filename);
  return $tag;
}

/**
 * Sets the last processed tag, so that we do not extract
 * the same strings all the time, unless the code has changed.
 */
function civiextensions_set_last_processed_tag($shortname, $tag) {
  $data_dir = CIVIEXTENSIONS_METADATA_DIR;
  $filename = "$data_dir/{$shortname}.tag";

  if (! $handle = fopen($filename, 'w')) {
    echo "Cannot open file ($filename)";
    return;
  }

  if (fwrite($handle, $tag) === FALSE) {
    echo "Cannot write to file ($filename)";
    return;
  }

  fclose($handle);
}

main();
