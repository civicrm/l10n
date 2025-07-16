# CiviCRM Translation files and Tools

[CiviCRM](https://civicrm.org/) is a constituent relationship management system designed to meet the needs of advocacy, non-profit and non-governmental groups. It is an open source project, licensed under GNU AGPL 3, and coordinated by CiviCRM LLC. The main project code repository is: https://github.com/civicrm/civicrm-core/

This project contains an archive of the text-versions of translations files, as well a scripts used mainly by various automations.

## Contributing

To translate CiviCRM in another language, please visit our project on Transifex: https://explore.transifex.com/civicrm/civicrm/

Please do not open a pull-request on this project for translations.

We also have various guides on the CiviCRM translation wiki: https://lab.civicrm.org/dev/translation/-/wikis/home

## Forums, help, community

For questions, please post in the `translation` channel at https://chat.civicrm.org or on StackExchange at https://civicrm.stackexchange.com.  

There are also a few language-specific channels at https://chat.civicrm.org, e.g. `francophone`, `nederlandstalig`, etc.

## Note about language/country ISO codes

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
