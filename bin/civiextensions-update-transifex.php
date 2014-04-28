#!/usr/bin/php
<?php

/**
 * For all civicrm native extensions (cms-agnostic) published in
 * the civicrm.org/extensions directory,
 * - clone the repo and extract the strings from the latest version,
 * - the extracted .pot files are stored in the civicrm-l10n-extensions
 *   directory,
 * - TODO: commit the changes to the repo,
 * - TODO: push the source strings to Transifex (project/civicrm_extensions),
 * - TODO: pull translated strings from Transifex and commit them
 *   (using commit-to-git.sh).
 *
 * Depends on packages: php5-cli, moreutils, gettext.
 * Depends on repositories: l10n (until those scripts are moved to civix).
 *
 * For more information, view the README.md and:
 * https://issues.civicrm.org/jira/browse/INFRA-104
 */

function main() {
  // civicrm.org URL that lists us the git repos for extensions
  // FIXME: use the production URL when ready.
  $url_repolist = 'https://www.bidon.ca/files/ext-repo-list.json';

  if (empty($_SERVER['HOME'])) {
    echo "ERROR: \$_SERVER['HOME'] was not set. I'm lost.\n";
    exit(1);
  }

  // temporary directory on this server where we clone git repos
  // no need for a trailing slash
  $download_dir = $_SERVER['HOME'] . "/repositories/cache";

  // repository with the .pot files generated
  // that we will commit to git to have a history similar to l10n/pot/
  $po_dir = $_SERVER['HOME'] . "/repositories/extensions_po";

  if (! file_exists($download_dir)) {
    mkdir($download_dir, 0755, TRUE);
  }

  if (! file_exists($po_dir)) {
    echo "$po_dir: directory does not exist. You need to clone the extensions_po repo first.\n";
    exit(1);
  }

  // Fetch the list of repos and clone locally
  $gitrepos_raw = file_get_contents($url_repolist);

  if (! $gitrepos_raw) {
    echo "ERROR: could not read the list of repositories for extensions.";
    exit(1);
  }

  $gitrepos = json_decode($gitrepos_raw);

  foreach ($gitrepos as $repo) {
    // Risky security
    if (! preg_match('/^[-_0-9-a-zA-Z\.:\/]+$/', $repo)) {
      echo "Skipping suspicious repo URL: $repo\n";
      continue;
    }

    $shortname = basename($repo);
    $shortname = preg_replace('/\.git$/', '', $shortname);
    # $shortname = $shortname . '-' . md5($repo);

    $extdir = escapeshellarg("$download_dir/$shortname");

    echo "Repo: $extdir\n";

    if (file_exists("$download_dir/$shortname")) {
      system("cd $extdir; git fetch --all");
    }
    else {
      // Runs: git clone git://example.org/foo.git ~/repositories/foo-hash
      $output = system('git clone ' . escapeshellarg($repo) . ' ' . $extdir);
    }

    // NB: we check for tags having the format: v1.0 1.0 1.0.0
    // meaning that we ignore anything such as 1.0-beta1
    // since the alphabetical sort would not make sense, and we
    // cannot predict what funky tags people may use.
    $tag = system("cd $extdir; git tag | grep -E '^v?[-\.0-9]+$' | sort -n | tail -1");
    print "Latest tag: " . $tag . "\n\n";

    system("cd $extdir; git checkout tags/" . $tag);

    // Extract the ts() strings
    if (! file_exists("$po_dir/$shortname/pot")) {
      mkdir("$po_dir/$shortname/pot", 0755, TRUE);
    }

    echo "~/bin/l10n/bin/create-pot-files-extensions.sh $shortname $extdir $po_dir/$shortname/pot/\n";
    system("cd $extdir; env POTDIR=$po_dir/$shortname/pot/ ~/bin/l10n/bin/create-pot-files-extensions.sh");
  }
}

main();
