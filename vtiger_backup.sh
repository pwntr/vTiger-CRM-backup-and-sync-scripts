#!/bin/bash
#
# CRM backup script
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
db_backup_file="/home/user/vtiger_backups/vTiger_"$today".sql"
local_db_backup_file="/home/user/vtiger_backups/vTiger_"$today".sql"

complete_backup_file="/home/vtiger/vtiger_backups/vtiger_full_backup_including_database_"$today".zip"
local_complete_backup_file="/home/user/vtiger_backups/vtiger_full_backup_including_database_"$today".zip"

prod_server_ip=192.168.1.1
prod_server_user=vtiger
prod_server_password="password"

# where to ftp the files
nas_ip=192.168.1.2
nas_user="backup"

nas_password="password"
nas_directory="/Company/vtiger_backups/"


################################################################################################
# Script logic
################################################################################################

backupRemoteServerToLocalMachine(){

	# temp booleans
	backup_successful=1

	file_backup_successful=false
	db_backup_successful=false
	file_bundling_successful=false
	file_copying_successful=false
	ftp_to_nas_successful=false
	delete_temp_files_successful=false

	# create the backup indicator file that shows that a backup is in progress
	touch $backup_indicator

	# create a full backup of everything
	if sshpass -p $prod_server_password ssh $prod_server_user@$prod_server_ip "tar -zcpf $backup_file --directory=$directory_to_backup .; chown $user:$group $backup_file"
	then
		
		file_backup_successful=true
		
		# dump the database
		if sshpass -p $prod_server_password ssh $prod_server_user@$prod_server_ip "mysqldump --opt -u $db_user -p$db_password --add-drop-database --databases $database > $db_backup_file; chown $user:$group $db_backup_file"
		then
			db_backup_successful=true
			
			# bundle the file backup and the database file into a new zip archive
			if sshpass -p $prod_server_password ssh $prod_server_user@$prod_server_ip "zip -q $complete_backup_file $backup_file $db_backup_file; chown $user:$group $complete_backup_file"
			then
				file_bundling_successful=true
				
				# copy the complete backup file from the remote machine to this local machine
				if sshpass -p $prod_server_password scp $prod_server_user@$prod_server_ip:$complete_backup_file $local_complete_backup_file
				then
					file_copying_successful=true
					
					# FTP the complete backup file over to the NAS, from the local machine
					if ncftpput -m -t 15 -V -u $nas_user -p $nas_password $nas_ip "$nas_directory" $local_complete_backup_file
					then
						ftp_to_nas_successful=true
						
						# delete the single non-bundled files from the production server
						if sshpass -p $prod_server_password ssh $prod_server_user@$prod_server_ip "rm $backup_file; rm $db_backup_file"
						then
							delete_temp_files_successful=true
						else
							delete_temp_files_successful=false
						fi
						
					else
						ftp_to_nas_successful=false
					fi
					
				else
					file_copying_successful=false
				fi
				
			else
				file_bundling_successful=false
			fi
			
		else
			db_backup_successful=false
		fi
				
	else
		file_backup_successful=false
	fi
	
	
	if $file_backup_successful && $db_backup_successful && $file_bundling_successful && $file_copying_successful && $ftp_to_nas_successful && $delete_temp_files_successful
	then
		backup_successful=0
	else
		backup_successful=1
	fi

	return $backup_successful

}


if backupRemoteServerToLocalMachine
then
	# remove the backup indicator file
	rm $backup_indicator
	
	# mail the admin group about the success
	# echo "Carry on!" | mail -s "CRM prodcution system successfully backed up locally on and on NAS as of $timestamp" -a "From: CRM Backup System <$mail_from>" $mail_to
else
	# mail the admin group about the failure
	echo "Failed to back up! Please investigate!" | mail -s "FAILED to backup the vTiger CRM system locally or on NAS as of $timestamp" -a "From: CRM Backup System <$mail_from>" $mail_to
fi
