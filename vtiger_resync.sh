#!/bin/bash
#
# vTiger CRM backup script
# @author: Peter Winter
#

# Declare variables
###############################################################################
today=$(date '+%m_%d_%Y')

# mail settings
mail_to=vemail@exaple.com
mail_from=sender@example.com

backup_file=~/vtiger_backups/fullbackup_"$today".tar.gz
directory_to_backup=/var/www/
user=vtiger
group=vtiger
database=vtiger
db_user=root
db_password="password"
db_backup_file=~/vtiger_backups/vTiger_"$today".sql
remote_user=ubuntu
remote_host=backup.company.com
remote_db_user=root
remote_db_password="password"
remote_db_file=/home/ubuntu/vtiger_backups/vTiger_"$today".sql

# Amazon EC2 stuff
ssh_cert=~/.ssh/CompanyKey.pem
ec2_instance_id=i-b1b1b1b1
ec2_instance_elastic_ip=111.111.111.111

# If this file does NOT exist, synchronize this production system entirely into the backup cloud system.
# Remove the file or set this variable to false or something else to ENABLE cloud synchronization
#control_file=~/prod_crm_offline.tmp

# What files to use as control files?
# When the file exists, it means that the backup system is online and reachable
backupCRM_inCharge=~/backup_CRM_as_production_in_charge.tmp
# When the file exists, it means that the backup process is currently running
backup_indicator=~/backup_indicator.tmp
# When the file exists, it means that the backup process is currently running
resync_indicator=~/resync_indicator.tmp


###############################################################################
# Script logic
###############################################################################

# create a full local backup of everything
tar -zcpf $backup_file --directory=$directory_to_backup .
chown $user:$group $backup_file

# dump the database
mysqldump --opt -u $db_user -p$db_password --add-drop-database --databases $database > $db_backup_file
chown $user:$group $db_backup_file

# Check if the production system shall be synchronized to the cloud backup system
if [ -f $backupCRM_inCharge ];
then

	echo "File $control_file does exist. Cloud synchronization with the backup system is being SKIPPED until production system is online again." | mail -s "vTiger CRM backup system now online. Production system offline. Sync SKIPPED!" -a "From: CRM Backup <$mail_from>" $mail_to
	

else

	# stop the instance after successful backup
	# ec2-stop-instances $ec2_instance_id

	# start the instance before any further backup steps
	# ec2-start-instances $ec2_instance_id
	# ec2-associate-address -i $ec2_instance_id $ec2_instance_elastic_ip


	echo "File $control_file exists. Cloud synchronization is OFF!"

	# copy the database to the remote machine
	scp -i $ssh_cert $db_backup_file $remote_user@$remote_host:$remote_db_file

	# ON REMOTE MACHINE: IMPORT THE DATABASE
	ssh $remote_user@$remote_host -i $ssh_cert "mysql -u $remote_db_user -p$remote_db_password -h localhost < $remote_db_file"

	# rsync the changed files of htdocs over to the remote host
	rsync -az -e "ssh -i $ssh_cert" --rsync-path="sudo rsync" --delete --exclude "config.inc.php" /var/www/ ubuntu@backup.company.com:/var/www

fi
