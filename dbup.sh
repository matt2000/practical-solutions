#!/bin/bash

# Drupal: Dev environment Post DB Update script
# =============================================
# Drupal Drush
#
# These are all the things I do locally when updating my database from
# production.
#
# dbup.sh
# -------
#
# Make sure local code is up-to-date.

git checkout master && git pull

# Make sure there's no cruft left around.

drush sql-drop all tables

# I get a nightly DB dump sync'd from production by other tools. This also
# happens to be faster than using drush sql-sync.

bunzip2 -c /var/backup/db/prod_backup_post_sanitize_latest.sql.bz2 | drush sqlc

# Disable production things that I don't want locally.

drush dis -y paranoia tfa

# Enable things that help me develop.

drush en -y coder_review admin_menu devel maillog


# This has some faily static testing data, which is not included in the nightly
# dump.

zcat /var/www/test-data.sql.gz | drush sqlc

# This is a version of `updb` that does not clear all caches. We'll do that in
# a moment.

drush lightupdb -y

# Compile compass CSS.

compass compile sites/all/themes/*/

# Now we can clear all caches, and generate aggregated CSS.

drush cc all

# User 1 is blocked on production. Sometimes I use it locally, because I have
# bad habits.

drush uublk 1

# Give the admin user a <sarcasm>highly secure</sarcasm> password. Seriously, 
# you've got a firewall blocking access to your local dev environment, right?

drush upwd --password="password" admin

# Log in the admin, because I've got bad habits.
drush uli --uri="http://dev.localhost"

# Run a custom drush command that set-ups other useful data. Maybe you just
# want to run `drush devel-generate` here.

drush test-setup

# Happy coding!
