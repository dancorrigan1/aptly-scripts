# aptly-scripts

A collection of aptly scripts I am making public.

main.sh: Main aptly repository script used for new snapshots and publishing.

updatemirrors: Download any new or updated packages from remote repos. 
updatedev: Update all local mirrors from remote, make new snapshots and switch DEV over to the newly created snapshots
updateprod: Switch PROD repos to snapshot that is currently in use by DEV
removesnapshots YYYYMMDD: Must use dated format as the second argument to remove snapshots from that date. See: aptly snapshot list
initialmirrors: Must use the word FORCE as the second argument to automate a build of new full aptly repo hosting xenial, trusty, 14.04, 16.04	
