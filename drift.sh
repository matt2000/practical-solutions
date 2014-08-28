#!/bin/bash

# One of my first BASH scripts for Sync'ing Drupal databases
# ==========================================================
# Drupal Drush Deprecated
#
# Back in the dark ages, before there was `drush sql-sync`, I created this
# script to update local dev environments with drupal databases on remote
# servers. I'm sharing it now because it still has some useful techniques
# for reference, even if there are better tools for the job these days.
#
# This script is (c)2008-2014 Ninjitsu Technologies, Inc, and is available for
# use and redistribution under your choice of a GPLv2 or BSD 3-clause license.
# 
# The original home for this script is in [a collection of miscellaneous tools for myself as a Drupal Developer](https://github.com/matt2000/ninjatools).
#
# drift.sh
# ------
#
# Notice my primitive configuration system and laugh at my childish 
# ignorance.

# Options could be passed as command-line arguments, but usually weren't.

if [[ $1 == "" ]]
then

  # Alternate default values could be provide in magic .dot files. This worked 
  # well enough for me, because I was already in the habit of running my drush
  # commands from the web root. Obviously it would have been better to put
  # all the configuration in one file, but originally I only needed the 'path'
  # option, and when It came time to add other parameters, I couldn't be
  # bothered to implement a parser, so I did it the easy way.

  REMOTE="`cat .drifthost`"
  WEBROOT="`cat .driftpath`"
  if [ -e ".driftport" ]
  then
    PORT="`cat .driftport`"
  else
    PORT="22"
  fi

# Even then, I knew it was important to include usage instructions inside 
# the script itself.

elif [[ $1 == "-h" || $1 == "--help" ]]
then
  echo "Replaces database for current site with remote database. Requires Drush."
  echo "Usage: drift [user@host] /path/to/site"
  echo "You'll be prompted for confirmation. Answering (b)ackup will cause a back-up of the current database to be saved before it is replaced with the remote database. Answering (d)ownload will cause the remote database to be downloaded only, leaving the current database unchanged."
  exit 0
elif [ $2 ]
then
  WEBROOT="$2"
  REMOTE="$1"
  PORT="22"
else
  WEBROOT="$1"
  PORT="22"
fi

DATE=`date +%F-%H%M`
FILENAME="drift-$DATE.sql.gz"
TMPLOCAL="/tmp/drift-local/"
TMPREMOTE="/tmp/drift-remote/"

echo "'drift -h' for usage info."

# It's always good to remind the user of what they're doing when they might be 
# doing something monumentally stupid. Especially if the user is me.

echo "The following database will be overwritten:"
drush sql-conf

read -p "Are you sure you want to continue? <No/yes/backup/download> " prompt

if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
  echo "OK. Continuing."

# Here's a feature I wish drush-sql-sync had. I almost always want to make a
# back-up first.

elif [[ $prompt == 'b' || $prompt == 'backup' ]]
then
  mkdir $TMPLOCAL
  echo "Backing up to $TMPLOCAL$FILENAME"
  drush sql-dump | gzip -c > $TMPLOCAL$FILENAME

# I almost never actually used this 'dry-run' feature, but apparently I thought
# it would be useful at some point. Over-engineering, as usual.

elif [[ $prompt == 'd' || $promt == 'dryrun' ]]
then
  DRYRUN=1
  echo "Downloading database to $TMPREMOTE only. Database will not be overwritten."
else
  echo "Aborting."
  exit 0
fi

# This usally throws warnings about trying to create a directory that already
# exists. Those are easy to ignore. Fixing it is left as an exercise for the 
# reader.

# Also, I probably should have used $TMPLOCAL in COMMAND, because the file being
# stored here is local to the remote server. This did get confusing at least
# once when this script was used on a dev server which pulled from a production
# server, which in turn was used as a remote source for dev enviroments.

COMMAND="mkdir $TMPREMOTE; cd $WEBROOT && drush sql-dump | gzip -c > $TMPREMOTE$FILENAME"

if [ $REMOTE ]
then
  ssh -p $PORT $REMOTE $COMMAND
  mkdir $TMPREMOTE
  scp -P $PORT $REMOTE:$TMPREMOTE$FILENAME $TMPREMOTE
  ssh -p $PORT $REMOTE "rm $TMPREMOTE$FILENAME"
else

  # This allowed for transferring databases on the same host. I almost never
  # did that, so I'm not even sure it still works.

  ORIGIN=`pwd`
  eval $COMMAND
  echo $COMMAND
  cd $ORIGIN
fi


if [ $DRYRUN ]
then
  echo "Database dump saved to $TMPREMOTE$FILENAME"
else
  echo 'Overwriting database.'

  # Load up the fresh database. Yes, we can gzip all the things!

  zcat $TMPREMOTE$FILENAME | `drush sql-connect`
  drush cc all
fi

# Many times, one wants to do thinks after loading the database, like revert
# features or create test accounts or get a reminder to call the wife. This
# provides a convenient place for such things.

if [ -e ".driftafter" ]
then
  .driftafter
fi

# Go forth and BASH things.
