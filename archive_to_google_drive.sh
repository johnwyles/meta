#!/bin/bash

### IMPORTANT: You will need to create a a conf file named ".archive_to_google_drive.conf" 
### in the same directory as this script.  The contents should resemble:
###   FILES_PATH="/PATH/TO/FILES"            # Prints all files older than 7 days
###   DAYS_EXPIRE=7                          # Number of days to keep locally
###   GOOGLE_USERNAME="YOUR_EMAIL@gmail.com"
###   GOOGLE_PASSWORD="YOUR_PASSWORD"
###   GOOGLE_ACCOUNT_TYPE="GOOGLE"           # Google Apps = HOSTED, gMail = GOOGLE
. `dirname $0`/.archive_to_google_drive.conf

LIST_FILES_COMMAND="find $FILES_PATH -type f -print"
DELETE_COMMAND="find $FILES_PATH -type f -mtime +$DAYS_EXPIRE -exec rm -rf {} +"

echo "[$(date)] [INFO] Sourced `dirname $0`/.archive_to_google_drive.conf:"
echo "    FILES_PATH:          $FILES_PATH"
echo "    DAYS_EXPIRE:         $DAYS_EXPIRE"
echo "    LIST_FILES_COMMAND:  $LIST_FILES_COMMAND"
echo "    DELETE_COMMAND:      $DELETE_COMMAND"
echo "    GOOGLE_USERNAME:     $GOOGLE_USERNAME"
echo "    GOOGLE_ACCOUNT_TYPE: $GOOGLE_ACCOUNT_TYPE"

# Zip filename
ZIP_FILE=`dirname $0`/upload-`date +"%m-%d-%Y_%H-%M-%S"`.zip
echo "[$(date)] [INFO] ZIP File: $ZIP_FILE"

# Zip them up
$LIST_FILES_COMMAND | xargs zip -q $ZIP_FILE

if [ ! -f $ZIP_FILE ]; then
  echo "[$(date)] [ERROR] There are not any files matching your search or we were unable to create the archive file"
  exit 1
fi

# Remove them (?)
$DELETE_COMMAND

USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:13.0) Gecko/20100101 Firefox/13.0.1"
ZIP_FILE_MIME_TYPE=`file -b --mime-type $ZIP_FILE`

# Google Drive stuff
GOOGLE_LOGIN_TOKEN=`curl -s --data-urlencode Email=$GOOGLE_USERNAME --data-urlencode Passwd=$GOOGLE_PASSWORD -d accountType=$GOOGLE_ACCOUNT_TYPE -d service=writely -d source=cURL "https://www.google.com/accounts/ClientLogin" |  grep Auth | cut -d \= -f 2`
GOOGLE_UPLOAD_URI=`curl -S -s -k --request POST -H "Content-Length: 0" -H "Authorization: GoogleLogin auth=${GOOGLE_LOGIN_TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $ZIP_FILE_MIME_TYPE" -H "Slug: $ZIP_FILE" "https://docs.google.com/feeds/upload/create-session/default/private/full?convert=false" -D /dev/stdout | grep "Location:" | sed s/"Location: "//`
curl -o /dev/null -S -s -k --request POST -T "$ZIP_FILE" -H "Authorization: GoogleLogin auth=${GOOGLE_LOGIN_TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $ZIP_FILE_MIME_TYPE" -H "Slug: $ZIP_FILE" "$GOOGLE_UPLOAD_URI"
#curl -o /dev/null -S -s -k --request POST --data-binary "@$ZIP_FILE" -H "Authorization: GoogleLogin auth=${GOOGLE_LOGIN_TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $ZIP_FILE_MIME_TYPE" -H "Slug: $ZIP_FILE" "$GOOGLE_UPLOAD_URI"

rm -f $ZIP_FILE

if [ $? -ne 0 ]; then
   echo "[$(date)] [ERROR] There was an error in uploading the file."
   exit 1
fi

