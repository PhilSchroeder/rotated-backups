#!/bin/bash
#
#	rotated_backup.sh	v1.1	
#
#	basic backup utility, copies data to large backup disk.
#	place excludes in /etc/rotated_backup.exclude
#
#	backups kept in forced rotation in directories inside
#	of $BACKUP_DIR.  Most recent backup is in 'current'.
#	Previous backups are in 'previous1','previous2', etc.
#
#	To deploy, all that is needed is a backup drive
#	that is specified in /etc/fstab (/mnt/backup typically)
#	Set the user-defined variables below, and run 
#	as root via cron.
#

# USER-DEFINED
PREV_DAYS=4				#num of previous backups kept
BACKUP_DRIVE=/nfs-shares/mapr		#mounted backup drive
BACKUP_DIR=$BACKUP_DRIVE/config_backups/srv/`hostname`	#directory to back up to
MOUNTED_CHECK=$BACKUP_DRIVE/sandnetstore/done/NAS_is_mounted

# CONSTANTS
FOOTPRINT=backup.timestamp
INCLUDE=$1
DIR_MOD=755		# must be bitmask, not a+r style
BACKUP_TEMP=$BACKUP_DIR/tmp_backup
CURRENT=$BACKUP_DIR/current
PREFIX=$BACKUP_DIR/previous

#==========================
# check_dir()
#
#	see if this directory exists, and if not, make it.
#

check_dir()
{
	if [ ! -d $1 ]; then
		log "Creating directory $1"
		log mkdir -p -m $DIR_MOD $1
		 mkdir -p -m $DIR_MOD $1
	fi
}

#==========================
# log()
#

log()
{
	echo BACKUP: `date` : $@
}

#==========================
# rotate() - basic rotation of backup directories
#
# 	most recent backup is in 'current' 
# 	next is in previous1, then previous2, etc.
#
#	we use a "tmp" directory to mv back to "current"
#	if we have a full backup in "current" when we
#	start our new backup, rsync works much faster
#
#	example rotation scheme 
#	* mv prev3 to tmp_backup
#	* mv prev2 to prev3
#	* mv prev1 to prev2
#	* mv current to prev1
#	* mv tmp_backup to current
#

rotate()
{
	check_dir $CURRENT

	# get the oldest backup and move to temp dir
	# done in a loop in case we've just changed
	# the $PREV_DAYS value 
	for ((i=$PREV_DAYS;i>=1;i-=1)); do
		if [ -d ${PREFIX}$i ]; then
			log "Moving oldest backup (previous $i) to temp dir."
			mv ${PREFIX}$i $BACKUP_TEMP
			break
		fi
	done

	for ((i=$PREV_DAYS;i>1;i-=1)); do
		let j=$i-1
		check_dir ${PREFIX}$j
		log "Moving previous$j to previous$i"
		mv ${PREFIX}$j ${PREFIX}$i
	done

	log "Moving 'current' to 'previous1'"
	mv $CURRENT ${PREFIX}1
	log "Moving temp dir to 'current'"
	mv $BACKUP_TEMP $CURRENT

	log "Deleting temp backup data"
	rm -f $BACKUP_TEMP
}	

#====================================
# Main Program

if [ ! -e $MOUNTED_CHECK ]; then
	WAS_MOUNTED="no"
	log "Backup FS not mounted, mounting"
	mount $BACKUP_DRIVE
else 
	WAS_MOUNTED="yes"
fi

check_dir $BACKUP_DIR

rotate

start=`date +%s`
start_full=`date`
log "Starting backup in $BACKUP_DIR at $start_full" 
log "rsync -rav -delete --filter='merge $INCLUDE' / $CURRENT"
rsync -rav -delete --filter="merge $INCLUDE" / $CURRENT
stop=`date +%s`
stop_full=`date`

#timestamp 
echo Start: $start_full > $CURRENT/$FOOTPRINT
echo Stop: $stop_full >> $CURRENT/$FOOTPRINT


let total=$stop-$start
let totalMIN=$total/60

log "Finished syncing $dir at $stop_full"
log "Total Time: $totalMIN minutes"

if [ "$WAS_MOUNTED" = "no" ]; then
	log "Unmounting Backup FS"
	umount $BACKUP_DRIVE
fi
