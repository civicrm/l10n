Localisation files for CiviCRM: https://civicrm.org/

How to localise your CiviCRM installation
=========================================

aka "using CiviCRM in another language than US-English"

Documentation on how to localise your installation of CiviCRM:
* http://wiki.civicrm.org/confluence/pages/viewpage.action?pageId=88408149
* http://wiki.civicrm.org/confluence/display/CRMDOC/i18n+Administrator%27s+Guide

How to participate in a translation team
========================================

Translations are managed on Transifex.com. Please do not open a pull-request on the github l10n project.

Internationalisation and localisation documentation:  
https://wiki.civicrm.org/confluence/pages/viewpage.action?pageId=88408149

Refreshing the translation strings on Transifex:  
https://wiki.civicrm.org/confluence/display/CRMDOC/Pushing+new+strings+to+Transifex

Translators resources:  
https://wiki.civicrm.org/confluence/display/CRMDOC/Resources+for+Translators

Transifex how-to:  
https://wiki.civicrm.org/confluence/display/CRMDOC/Transifex+howto

Localisation community building how-to:  
https://wiki.civicrm.org/confluence/display/CRMDOC/Localisation+community+building+howto

Translation guide for Windows:  
https://forum.civicrm.org/index.php/topic,19068.0.html


Forums, help, community
=======================

For questions, please post in the `translation` channel at https://chat.civicrm.org or on StackExchange at https://civicrm.stackexchange.com.  

There are also a few language-specific channels at https://chat.civicrm.org, e.g. `francophone`, `nederlandstalig`, etc.

Older, read-only information may be found on the Internationalisation forum:  
https://forum.civicrm.org/index.php?board=10.0

Or on the language-specific forums:
* French: http://forum.civicrm.org/index.php?board=58.0
* German: http://forum.civicrm.org/index.php?board=62.0
* Spanish: http://forum.civicrm.org/index.php?board=69.0
* UK: http://forum.civicrm.org/index.php?board=34.0


Note about language/country ISO codes
=====================================

CiviCRM uses ISO 3166-1 to determine the language/country codes,
such as fr_FR, fr_CA, es_ES, etc.

Initially, Transifex used mainly ISO 639 (fr, es, ...) to codify
languages. It later became possible to use ISO 3166-1.

The recommended method, when possible in Transifex, is to use the
ISO 3166-1 language code, since this is what uses gettext, the
underlying translation tool.

We map ISO 639 to ISO 3166 codes in the .tx/config file.

For more information:
* http://en.wikipedia.org/wiki/ISO_639-1
* http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
* http://en.wikipedia.org/wiki/ISO_3166-1
