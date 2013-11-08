#!/bin/bash
#
# vTiger CRM monitoring script.
# This file shall be executed by cron every 5 minutes. If the production system is
# not responding within 2 tries, the cloud backup CRM will be booted up.
# 
# @author: Peter Winter
#
###############################################################################
# Declare variables
###############################################################################
timestamp=$(date '+%m/%d/%Y %T')
tmp_prod_crm_monitor_log=/tmp/prod_crm_monitor.log
tmp_backup_crm_monitor_log=/tmp/backup_crm_monitor.log

# What files to use as control files?
# When the file exists, it means that the backup system is online and reachable
backupCRM_inCharge=~/backup_CRM_as_production_in_charge.tmp
# When the file exists, it means that the backup process is currently running
backup_indicator=~/backup_indicator.tmp
# When the file exists, it means that the sync process (prod -> backup) is currently running
sync_indicator=~/sync_indicator.tmp
# When the file exists, it means that the re-sync process (backup -> prod) is currently running
resync_indicator=~/resync_indicator.tmp

# Mail settings
mail_to=vemail@exaple.com
mail_from=sender@example.com

# What server is the production system
prod_server=192.168.1.1

# The backup server
backup_server=backup.company.com

# Amazon EC2 stuff
ssh_cert=~/.ssh/CompanyKey.pem
ec2_instance_id=i-b1b1b1b1
ec2_instance_elastic_ip=111.111.111.111

# Local indicators if servers are online. Will be set every time the script runs.
prodOnline=false
backupOnline=false

###############################################################################
# Declare functions
###############################################################################

checkServerStatus(){

	# Erase any previous logs
	if [ -f $tmp_prod_crm_monitor_log ]
	then
		rm $tmp_prod_crm_monitor_log
	fi

	if [ -f $tmp_backup_crm_monitor_log ]
	then
		rm $tmp_backup_crm_monitor_log
	fi

	# Dump the http header into a temporary file.
	curl --head --silent --show-error --connect-timeout 20 $prod_server &> $tmp_prod_crm_monitor_log
	curl --head --silent --show-error --connect-timeout 20 $backup_server &> $tmp_backup_crm_monitor_log

	# Check if the logs contain HTTP code "200 OK", signaling that the server is healthy
	if grep --quiet "200 OK" $tmp_prod_crm_monitor_log
	then
		prodOnline=true
	fi

	if grep --quiet "200 OK" $tmp_backup_crm_monitor_log
	then
		backupOnline=true
	fi

	return

}

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


###############################################################################
# Script logic starts here
###############################################################################

checkServerStatus

echo $prodOnline
echo $backupOnline

if $prodOnline
then
	echo "Your production CRM webserver is up and running :)! $timestamp"

	if $backupOnline
	then
		echo "Production CRM and backup CRM are BOTH online!"
		

		if [ -f $sync_indicator ]
		then
			echo "Both servers are online and the sync process is running. Everything is OK!"
		else
		
			if [ -f $backupCRM_inCharge ]
			then
				echo "Both servers are online and the backup CRM is currently in charge."
				
				if [ -f $resync_indicator ]
				then
					echo "Both servers are online and the production CRM is currently being synchronized with the data of the backup system."
				else
					# Start the re-sync process script to move all new data from the backup system to the production system! BE VERY CAREFUL HERE!!!!!!!
					echo "Both servers are online and the production CRM will be synchronized with the data of the backup system. Backup CRM will be shutdown afterwards."
					vtiger_resync.sh
					# Tell this script that the production system is commander in chief again by removing the corresponding control file.
					rm $backupCRM_inCharge
				fi
				
			else
				echo "Both servers are online but the backup process or re-sync process are NOT running. Will shutdown the backup server NOW!"
				ec2-stop-instances $ec2_instance_id
			fi

		fi

	fi
	
else

	if [ -f $backupCRM_inCharge ]
	then

		if $backupOnline
		then
			echo "Control file $backupCRM_inCharge found. Will skip starting of cloud backup CRM as it is already started. $timestamp"
		else
			echo "Control file $backupCRM_inCharge found, but backup system is OFFLINE. Will try to start cloud backup CRM. $timestamp"
			# start the cloud server instance and associate the corresponding IP address
			startBackupServer
		fi

	else
		mail -s "CRM prodcution system DOWN as of $timestamp" -a "From: CRM Watchdog <$mail_from>" $mail_to < $tmp_prod_crm_monitor_log
		echo "Your CRM webserver is down! The log has been mailed. $timestamp"

		# start the cloud server instance and associate the corresponding IP address
		if startBackupServer
		then
			# Create the (empty) control file so that this script knows that the backup server is in charge from this point on
			touch $backupCRM_inCharge
		else
			echo "Could not start the backup CRM server. Refer to the emailed logs at $mail_to."
		fi
		
	fi

fi