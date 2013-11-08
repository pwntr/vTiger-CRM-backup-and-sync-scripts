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

local_backup_directory="/home/user/vtiger_backups/"

prod_server_ip=192.168.1.1
prod_server_user=vtiger
prod_server_password="password"
prod_server_backup_directory="/home/vtiger/vtiger_backups/"
local_production_directory_mountpoint="/home/user/vtiger_backups_production/"

# where to ftp the files
nas_ip=192.168.1.2
nas_user="backup"

nas_password="password"
nas_directory="/Company/vtiger_backups/"
local_nas_directory_mountpoint="/home/user/vtiger_backups_NAS/"

################################################################################################
# Script logic
################################################################################################

# Mount NAS
curlftpfs -o allow_other $nas_user:$nas_password@$nas_ip:"$nas_directory" $local_nas_directory_mountpoint

# Mount production vtiger system
echo $prod_server_password | sshfs -o allow_other -o password_stdin $prod_server_user@$prod_server_ip:"$prod_server_backup_directory" $local_production_directory_mountpoint

# Keep every backup of the last 30 days on server
/home/kadmin/delete_old_backup_files.sh -s "vtiger_full_backup_including_database_" -m 30 -d $local_backup_directory -q

# Keep every backup of the last 30 days on the vtiger production system
/home/kadmin/delete_old_backup_files.sh -s "vtiger_full_backup_including_database_" -m 30 -d $local_production_directory_mountpoint -q

# Keep every backup of the last year on the NAS
/home/kadmin/delete_old_backup_files.sh -s "vtiger_full_backup_including_database_" -m 365 -d $local_nas_directory_mountpoint -q

# unmount all directories
fusermount -u $local_nas_directory_mountpoint
fusermount -u $local_production_directory_mountpoint