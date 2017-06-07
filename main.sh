#!/bin/bash
############################################################
# main.sh
# written by Daniel Corrigan <dancorrigan1@gmail.com>
# This script peforms a few tasks.
#
# update apt mirrors from remote
# create new snapshots
# switch existing pubished repos to new snapshots
# clean up old snapshots
#
# 20170606 - Initial creation
# 20170607 - Added initialmirrors function
#
##########################################################

# usage
usage() {
   echo "usage: $0 initialmirrors, updatemirrors, updatedev, updateprod, removesnapshots YYYYMMDD"
   exit 0
}

# require first argument
if [ -z $1 ]; then usage; fi

# date and passphrase
date=`date +"%Y%m%d"`
passphrase="ABCITSEASYAS123"

# new graph
newgraph() {
   aptly graph -layout="vertical" -format="png" -output="/vol1/aptly/public/current.png"
}

# Keep all mirrors up to date
update_from_remote_mirrors() {
   for mirror in `aptly mirror list -raw`; do
      aptly mirror update ${mirror}
   done
}

create_initial_mirrors() {
   distros=(trusty xenial)
   for distro in ${distros[@]}; do
      aptly mirror create -architectures="amd64" ${distro}-main http://us.archive.ubuntu.com/ubuntu/ ${distro} main restricted universe multiverse
      aptly mirror create -architectures="amd64" ${distro}-updates http://us.archive.ubuntu.com/ubuntu/ ${distro}-updates main restricted universe multiverse
      aptly mirror create -architectures="amd64" ${distro}-security http://security.ubuntu.com/ubuntu/ ${distro}-security main restricted universe multiverse
      aptly mirror create -architectures="amd64" ${distro}-backports http://us.archive.ubuntu.com/ubuntu/ ${distro}-backports main restricted universe multiverse
   done
}

# remove snapshots
remove_snapshots() {
   snapshot_date=$1

   distros=(trusty xenial)
   for distro in ${distros[@]}; do

      # drop final and included snapshots
      aptly snapshot drop ${distro}-final-${snapshot_date}
      aptly snapshot drop ${distro}-main-${snapshot_date}
      aptly snapshot drop ${distro}-updates-${snapshot_date}
      aptly snapshot drop ${distro}-security-${snapshot_date}
      aptly snapshot drop ${distro}-backports-${snapshot_date}
      aptly snapshot drop ${distro}-zabbix-${snapshot_date}

   done
}

# Create current date main distro snapshots
update_dev() {
   new_or_existing=$1
   distros=(trusty xenial)
   for distro in ${distros[@]}; do

      # create todays snapshots
      aptly snapshot create ${distro}-main-${date} from mirror ${distro}-main
      aptly snapshot create ${distro}-updates-${date} from mirror ${distro}-updates
      aptly snapshot create ${distro}-security-${date} from mirror ${distro}-security
      aptly snapshot create ${distro}-backports-${date} from mirror ${distro}-backports
      aptly snapshot create ${distro}-zabbix-${date} from mirror ${distro}-zabbix

      # merge todays snapshots into common "final" repo
      aptly snapshot merge -latest ${distro}-final-${date} ${distro}-main-${date} ${distro}-updates-${date} ${distro}-security-${date} ${distro}-backports-${date} ${distro}-zabbix-${date}

      if [[ $new_or_existing == "existing" ]]; then
         # switch published repos to new snapshot
         aptly publish switch -passphrase="${passphrase}" ${distro} dev ${distro}-final-${date}
      elif [[ $new_or_existing == "new" ]]; then
         # create new published repo
         aptly publish snapshot -passphrase="${passphrase}" -distribution="${distro}" ${distro}-final-${date} dev
      else
         exit 1
      fi
   done
}

# switch published prod to current dev snapshot
update_prod() {
   dev_current_publish_date=`aptly publish list|grep dev|egrep -o "xenial-final-[0-9]{8}"|awk -F"-" '{print $3}'`
   distros=(trusty xenial)
   for distro in ${distros[@]}; do
      aptly publish switch -passphrase="${passphrase}" ${distro} prod ${distro}-final-${dev_current_publish_date}
   done
}

# script begins
command=$1
case $command in
   initialmirrors)
      create_initial_mirrors
      update_from_remote_mirrors
      update_dev new
      update_prod
      newgraph
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
      if [ -z $2 ]; then echo "usage: $0 removesnaphots YYYYMMDD"; exit 0; fi
      remove_snapshots $2
      newgraph
   ;;
   *)
      usage
   ;;
esac
