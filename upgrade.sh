#!/usr/bin/env bash

PROJECT_NAME=$1

function check_command_exists() {
    command -v $1 >/dev/null 2>&1 || {
        echo >&2 "$1 is not available.  Aborting."
        exit 1
    }
}

# Check if required commands are available
check_command_exists lcp
check_command_exists jq
check_command_exists docker-compose

# Try to Login user
echo 'Please Log In to DXP Cloud Console'
lcp login

# Check if LCP config file exists
LCP_CONFIG_FILE=$HOME/.lcp
if test -f "$LCP_CONFIG_FILE"; then
    echo "$LCP_CONFIG_FILE exists"
else
    echo "$LCP_CONFIG_FILE doesn't exist! Exciting..."
    exit 1;
fi

TOKEN=$(awk -F "=" '/token/ {print $2}' $LCP_CONFIG_FILE)

# Create backups directory with correct permissions
mkdir -m a=rwx -p backups 

# Download latest database and volume backup
echo 'Getting latest backup ID...'
LAST_BACKUP_ID=$(curl -s "https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/list?limit=1" -H "dxpcloud-authorization: Bearer $TOKEN" | jq --raw-output '.backups[0].backupId')
echo 'Last backup ID: ' $LAST_BACKUP_ID
echo 'Downloading database backup...'
curl "https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/download/database/$LAST_BACKUP_ID" \
  -X 'POST' \
  -H "authorization: Bearer $TOKEN" \
  -o backups/database_original.tgz
echo 'Download completed!'

echo 'Downloading volume backup in the background...'
nohup curl "https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/download/volume/$LAST_BACKUP_ID" \
  -X 'POST' \
  -H "authorization: Bearer $TOKEN" \
  -o backups/volume.tgz

# Extract database dump, delete if successful
echo 'Extracting database backup...'
if test -f backups/database_original.tgz; then
    tar zxvf backups/database_original.tgz -C backups
    if [ $? -eq 0 ]; then
        echo 'Extracting successful!'
        rm -f backups/database_original.tgz
    else
        echo 'Extracting database failed'
        exit 1
    fi
else
    echo 'Database file does not exist!'
    exit 1
fi

if [ ! -f liferay_scripts/upgrade_done ]; then
    echo 'Starting services with docker-compose...'
    mkdir upgrade_output
    docker-compose up -d --force-recreate --remove-orphans

    echo 'Performing upgrade...'
    while [ ! -f liferay_scripts/upgrade_done ]
    do
        sleep 2
    done
    echo 'Upgrade completed!'
else
    echo 'Skipping upgrade...'
fi

echo 'Killing liferay service...'
docker-compose kill liferay

echo 'Creating database dump...'
docker-compose exec database mysqldump -udxpcloud -pdxpcloud --databases --add-drop-database lportal --result-file=/upgrade_output/lportal.sql

UPGRADED_DUMP=upgrade_output/lportal.sql
if test -f "$UPGRADED_DUMP"; then
    echo "$UPGRADED_DUMP exist"
    echo "Kill and remove services..."
    docker-compose kill
    docker-compose rm -f
    echo "Compress lportal.sql..."
    cd upgrade_output
    tar -czvf database.tgz ./lportal.sql
    mv database.tgz ../backups/database.tgz
    cd ..
    echo "Cleaning up..."
    rm -f backups/lportal.sql
    rm -f backups/database_original.tgz
    rm -f upgrade_output/lportal.sql
    rm -f liferay_scripts/upgrade_done
    rm -rf upgrade_output
else
    echo "Upgrade dump doesn't exists..."
    exit 1;
fi

echo "Uploading database..."
curl -X POST \
  https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/upload \
  -H 'Content-Type: multipart/form-data' \
  -H 'dxpcloud-authorization: Bearer '$TOKEN \
  -F 'database=@backups/database.tgz' \
  -F 'volume=@backups/volume.tgz'
