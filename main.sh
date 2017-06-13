#!/bin/bash
############################################################
# main.sh
# written by Daniel Corrigan <dancorrigan1@gmail.com>
# This script peforms a few tasks.
#
# create new xenial, trusty, 14.04, 16.04 aptly mirrors from scratch
# update apt mirrors from remote
# create new snapshots
# switch existing pubished repos to new snapshots
# clean up old snapshots
#
##########################################################

# usage
usage() {
   echo "usage: $0 updatemirrors, updatedev, updateprod, removesnapshots YYYYMMDD, initialmirrors"
   exit 0
}

# require first argument
if [ -z $1 ]; then usage; fi

# date and passphrase
date=`date +"%Y%m%d"`
passphrase="ABC123"
log_file=/home/aptly/aptly.log


# get time
function get_time () {
   date=`date +"%Y-%m-%d %H:%M"`
   echo $date
}

# log and echo
function log_and_echo () {
   current_time=$(get_time)
   echo -e "$current_time - $1"
   echo -e "$current_time - $1" >> ${log_file}
}

# new graph
newgraph() {
   log_and_echo "Generating New Graph"
   aptly graph -layout="vertical" -format="png" -output="/vol1/aptly/public/current.png" > /dev/null
}

# Keep all mirrors up to date
update_from_remote_mirrors() {
   log_and_echo "Updating from remote mirrors" 
   for mirror in `aptly mirror list -raw`; do
      aptly mirror update ${mirror} > /dev/null
   done
   log_and_echo "Updating from remote mirrors Complete"
}

# Create initial mirrors
create_initial_mirrors() {
   log_and_echo "Creating Initial Mirrors"
   distros=(trusty xenial)
   for distro in ${distros[@]}; do
      aptly mirror create -architectures="amd64" ${distro}-main http://us.archive.ubuntu.com/ubuntu/ ${distro} main restricted universe multiverse > /dev/null
      aptly mirror create -architectures="amd64" ${distro}-updates http://us.archive.ubuntu.com/ubuntu/ ${distro}-updates main restricted universe multiverse > /dev/null
      aptly mirror create -architectures="amd64" ${distro}-security http://security.ubuntu.com/ubuntu/ ${distro}-security main restricted universe multiverse > /dev/null
      aptly mirror create -architectures="amd64" ${distro}-backports http://us.archive.ubuntu.com/ubuntu/ ${distro}-backports main restricted universe multiverse > /dev/null
   done
   log_and_echo "Initial Mirrors Complete"
}

# remove snapshots
remove_snapshots() {
   snapshot_date=$1
   log_and_echo "Removing snapshots dated $1"
   distros=(trusty xenial)
   for distro in ${distros[@]}; do

      # drop final and included snapshots
      aptly snapshot drop ${distro}-final-${snapshot_date} > /dev/null
      aptly snapshot drop ${distro}-main-${snapshot_date} > /dev/null
      aptly snapshot drop ${distro}-updates-${snapshot_date} > /dev/null
      aptly snapshot drop ${distro}-security-${snapshot_date} > /dev/null
      aptly snapshot drop ${distro}-backports-${snapshot_date} > /dev/null
   done

   log_and_echo "Removal of snapshots Complete"
}

# Create current date main distro snapshots
update_dev() {
   new_or_existing=$1
   log_and_echo "Updating DEV - $new_or_existing"
   distros=(trusty xenial)
   for distro in ${distros[@]}; do

      # create todays snapshots
      log_and_echo "Creating ${date} snapshots for ${distro}"
      aptly snapshot create ${distro}-main-${date} from mirror ${distro}-main > /dev/null
      aptly snapshot create ${distro}-updates-${date} from mirror ${distro}-updates > /dev/null
      aptly snapshot create ${distro}-security-${date} from mirror ${distro}-security > /dev/null
      aptly snapshot create ${distro}-backports-${date} from mirror ${distro}-backports > /dev/null

      # merge todays snapshots into common "final" repo
      log_and_echo "Merging Snapshots for ${distro}"
      aptly snapshot merge -latest ${distro}-final-${date} ${distro}-main-${date} ${distro}-updates-${date} ${distro}-security-${date} ${distro}-backports-${date} > /dev/null

      if [[ $new_or_existing == "existing" ]]; then
         # switch published repos to new snapshot
         log_and_echo "Publish Switching DEV ${distro} to new snapshot ${distro}-final-${date}"
         aptly publish switch -passphrase="${passphrase}" ${distro} dev ${distro}-final-${date} > /dev/null
         log_and_echo "Publish Switching DEV ${distro} to new snapshot ${distro}-final-${date} Complete"
      elif [[ $new_or_existing == "new" ]]; then
         # create new published repo
         log_and_echo "Publishing DEV ${distro} to new snapshot ${distro}-final-${date}"
         aptly publish snapshot -passphrase="${passphrase}" -distribution="${distro}" ${distro}-final-${date} dev > /dev/null
         log_and_echo "Publishing $DEV {distro} to new snapshot ${distro}-final-${date} Complete"
      else
         exit 1
      fi
   done

   log_and_echo "Updating DEV - $new_or_existing Complete"
}

# switch published prod to current dev snapshot
update_prod() {
   dev_current_publish_date=`aptly publish list|grep dev|egrep -o "xenial-final-[0-9]{8}"|awk -F"-" '{print $3}'`
   log_and_echo "Publish Switching PROD ${distro} to DEV snapshot ${distro}-final-${dev_current_publish_date}"
   distros=(trusty xenial)
   for distro in ${distros[@]}; do
      aptly publish switch -passphrase="${passphrase}" ${distro} prod ${distro}-final-${dev_current_publish_date} > /dev/null
   done
   log_and_echo "Publish Switching PROD ${distro} to DEV snapshot ${distro}-final-${dev_current_publish_date} Complete"
}

# script begins
command=$1
argument=$2
case $command in
   initialmirrors)
   doit() {
      create_initial_mirrors
      update_from_remote_mirrors
      update_dev new
      update_prod
      newgraph
   }
   if [[ $argument == "FORCE" ]]; then
      doit
   else
      echo -e "WARNING: This will build a completely from blank disk repo for xenial and trusty and 14.04 and 16.04.\nThis process will take over a day.\nYou can skip the this prompt by running: $0 initialmirrors FORCE" 
      echo -n "You must type FORCE to run this command now: "
      read argument
      if [[ "$argument" == "FORCE" ]]; then
         doit
      else
         echo "You must type FORCE"
         exit 1
      fi
   fi
   ;;
   updatedev)
      update_from_remote_mirrors
      update_dev existing
      newgraph
   ;;
   updateprod)
      update_prod
      newgraph
   ;;
   updatemirrors)
      update_from_remote_mirrors
   ;;
   removesnapshots)
      if [ -z $arugement ]; then echo "usage: $0 removesnaphots YYYYMMDD"; exit 0; fi
      remove_snapshots $argument
      newgraph
   ;;
   *)
      usage
   ;;
esac

