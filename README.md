# rotated-backups
bash scripts for rotated rsync backups

rotated_backup.sh:
	ARGS: 1 - (REQUIRED) includes file (tells rsync what to back up)

	ex: ./rotated_backup.sh /etc/rsync.include

rsync.include:
	listing of files to back up.
