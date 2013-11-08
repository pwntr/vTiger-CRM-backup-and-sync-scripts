#!/bin/bash
#
# vTiger CRM backup script and Cloud Sync
#
# EC2 Tools must be installed!
#
# @author: Peter Winter
#

# Declare variables
###############################################################################
today=$(date '+%m_%d_%Y')
timestamp=$(date '+%m/%d/%Y %T')

backup_indicator=~/backup_indicator.tmp

# mail settings
mail_to=vemail@exaple.com
mail_from=sender@example.com

backup_file="/home/vtiger/vtiger_backups/fullbackup_"$today".tar.gz"
local_backup_file="/home/user/vtiger_backups/fullbackup_"$today".tar.gz"
directory_to_backup=/var/www/
user=vtiger
group=vtiger
database=vtiger
db_user=root
db_password="password"
db_backup_file="/home/vtiger/vtiger_backups/vTiger_"$today".sql"
local_db_backup_file="/home/kadmin/vtiger_backups/vTiger_"$today".sql"

prod_server_ip=192.168.1.1
prod_server_user=vtiger
prod_server_password="password"

cloud_user=ubuntu
cloud_host=backup.company.com
cloud_db_user=root
cloud_db_password="password"
cloud_db_file=/home/ubuntu/vtiger_backups/vTiger_"$today".sql

# Amazon EC2 stuff
ssh_cert=~/.ssh/CompanyKey.pem
ec2_instance_id=i-b1b1b1b1
ec2_instance_elastic_ip=111.111.111.111

# If this file does NOT exist, synchronize this production system entirely into the backup cloud system.
# Remove the file or set this variable to false or something else to ENABLE cloud synchronization
control_file=~/prod_crm_offline.tmp


################################################################################################
# Functions
################################################################################################

startBackupServer(){

	# start the cloud server instance and associate the corresponding IP address
	if ec2-start-instances $ec2_instance_id
	then
		echo "Successfully started instance $ec2_instance_id. $timestamp"
		# Wait 30 seconds
		sleep 30
		if ec2-associate-address -i $ec2_instance_id $ec2_instance_elastic_ip
		then
			echo "Successfully associated IP $ec2_instance_elastic_ip with instance $ec2_instance_id. $timestamp"
			# notify of complete successful start and association
			echo "Instance $ec2_instance_id was successfully started and associated with IP $ec2_instance_elastic_ip. The backup CRM system can now be reached through backup.company.com" | mail -s "CRM BACKUP system STARTED as of $timestamp" -a "From: CRM Watchdog <$mail_from>" $mail_to
			
			backupOnline=true
		else
			echo "Could not associate IP $ec2_instance_elastic_ip with instance $ec2_instance_id. $timestamp"
			echo "Instance $ec2_instance_id was successfully started BUT NOT associated with IP $ec2_instance_elastic_ip. The backup CRM system can NOT be reached from outside!" | mail -s "CRM BACKUP system could not be associated to IP as of $timestamp" -a "From: CRM Watchdog <$mail_from>" $mail_to
			backupOnline=false
		fi
	
	else
		echo "Could not start instance $ec2_instance_id. $timestamp"
		echo "Instance $ec2_instance_id could NOT be started. The backup CRM system can NOT be reached from outside!" | mail -s "CRM BACKUP system could not be started as of $timestamp" -a "From: CRM Watchdog <$mail_from>" $mail_to
		backupOnline=false
	fi

	return $backupOnline

}

################################################################################################


################################################################################################
# Script logic
################################################################################################

# create a full backup of everything
# tar -zcpf $backup_file --directory=$directory_to_backup .
# chown $user:$group $backup_file
sshpass -p $prod_server_password ssh $prod_server_user@$prod_server_ip "tar -zcpf $backup_file --directory=$directory_to_backup .; chown $user:$group $backup_file"
# copy the backup files from the remote machine to this local machine
sshpass -p $prod_server_password scp $prod_server_user@$prod_server_ip:$backup_file $local_backup_file


# dump the database
sshpass -p $prod_server_password ssh $prod_server_user@$prod_server_ip "mysqldump --opt -u $db_user -p$db_password --add-drop-database --databases $database > $db_backup_file; chown $user:$group $db_backup_file"
# copy the database file from the production system to the local system executing this script
sshpass -p $prod_server_password scp $prod_server_user@$prod_server_ip:$db_backup_file $local_db_backup_file

# Check if the production system shall be synchronized to the cloud backup system
#if [ -f $control_file ];
#then

#	echo "File $control_file does exist. Cloud synchronization with the backup system is being SKIPPED until production system is online again." | mail -s "vTiger CRM backup system now online. Production system offline. Sync SKIPPED!" -a "From: CRM Backup <$mail_from>" $mail_to
	

#else

	# start the instance before any further backup steps
	#startBackupServer

	# wait a bit for the dns lookup to succeed
	#sleep 30

	# copy the database to the remote machine
	#scp -i $ssh_cert $db_backup_file $cloud_user@$cloud_host:$cloud_db_file

	# ON REMOTE MACHINE: IMPORT THE DATABASE
	#ssh $cloud_user@$cloud_host -i $ssh_cert "mysql -u $cloud_db_user -p$cloud_db_password -h localhost < $cloud_db_file"

	# rsync the changed files of htdocs over to the remote host
	#rsync -az -e "ssh -i $ssh_cert" --rsync-path="sudo rsync" --delete --exclude "config.inc.php" /var/www/ ubuntu@backup.company.com:/var/www

#fi
