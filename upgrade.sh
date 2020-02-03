#!/usr/bin/env bash

PROJECT_NAME=liferaygrow

# Check if required commands are available
command -v lcp >/dev/null 2>&1 || { echo >&2 "DXP Cloud Command Line Interface (lcp) is not available.  Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is not available.  Aborting."; exit 1; }

# Check if LCP config file exists
LCP_CONFIG_FILE=$HOME/.lcp
if test -f "$LCP_CONFIG_FILE"; then
    echo "$LCP_CONFIG_FILE exist"
else 
    exit 1;
fi
TOKEN=$(awk -F "=" '/token/ {print $2}' $LCP_CONFIG_FILE)
# Test if token is usable
curl https://api.liferay.cloud/user -H 'Content-Type: application/json' -H "dxpcloud-authorization: Bearer $TOKEN"



echo 'Getting last backup ID...'
LAST_BACKUP_ID=$(curl -s https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/list -H "dxpcloud-authorization: Bearer $TOKEN" | jq --raw-output '.backups[-1].backupId')

echo 'Last backup ID: ' $LAST_BACKUP_ID
echo 'Starting to download database backup...'
curl -o backups/db/database_original.tgz https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/download/database/$LAST_BACKUP_ID -H 'Content-Type: application/json' -H "dxpcloud-authorization: Bearer $TOKEN"
echo 'Starting to download volume backup...'
curl -o backups/data/volume.tgz https://backup-$PROJECT_NAME-prd.lfr.cloud/backup/download/volume/$LAST_BACKUP_ID -H 'Content-Type: application/json' -H "dxpcloud-authorization: Bearer $TOKEN"
echo 'Download completed!'

echo ''
docker-compose up --force-recreate --remove-

mysqldump -uroot -ppassword --databases --add-drop-database lportal | tar -czvf database.tgz

curl -X POST \
  http://<HOST-NAME>/backup/upload \
  -H 'Content-Type: multipart/form-data' \
  -H 'dxpcloud-authorization: Bearer '$TOKEN \
  -F 'database=@/my-folder/database.tgz' \
  -F 'volume=@/my-folder/volume.tgz'