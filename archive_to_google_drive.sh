#!/bin/bash

### IMPORTANT: You will need to create a a conf file named ".archive_to_google_drive.conf" 
### in the same directory as this script.  The contents should resemble:
###   LIST_FILES_COMMAND="find /PATH/TO/FILES -type f -mtime +7 -print"        # Prints all files older than 7 days
###   DELETE_COMMAND="find /PATH/TO/FILES -type f -mtime +7 -exec rm -rf {} \; # Removes all files older than 7 days 
###   GOOGLE_USERNAME="YOUR_EMAIL@gmail.com"
###   GOOGLE_PASSWORD="YOUR_PASSWORD"
###   GOOGLE_ACCOUNT_TYPE="GOOGLE" # Google Apps = HOSTED, gMail = GOOGLE
. `dirname $0`/.archive_to_google_drive.conf

# Zip filename
ZIP_FILE=`dirname $0`/upload-`date +"%m-%d-%Y_%H-%M-%S"`.zip

# Zip them up
$LIST_FILES_COMMAND | xargs zip -q $ZIP_FILE

if [ ! -f $ZIP_FILE ]; then
  echo "[ERROR] There are not any files matching your search or we were unable to create the archive file"
  exit 1
fi

# Remove them (?)
$DELETE_COMMAND

USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:13.0) Gecko/20100101 Firefox/13.0.1"
ZIP_FILE_MIME_TYPE=`file -b --mime-type $ZIP_FILE`

# Google Drive stuff
GOOGLE_LOGIN_TOKEN=`curl -s --data-urlencode Email=$GOOGLE_USERNAME --data-urlencode Passwd=$GOOGLE_PASSWORD -d accountType=$GOOGLE_ACCOUNT_TYPE -d service=writely -d source=cURL "https://www.google.com/accounts/ClientLogin" |  grep Auth | cut -d \= -f 2`
GOOGLE_UPLOAD_URI=`curl -S -s -k --request POST -H "Content-Length: 0" -H "Authorization: GoogleLogin auth=${GOOGLE_LOGIN_TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $ZIP_FILE_MIME_TYPE" -H "Slug: $ZIP_FILE" "https://docs.google.com/feeds/upload/create-session/default/private/full?convert=false" -D /dev/stdout | grep "Location:" | sed s/"Location: "//`
curl -o /dev/null -S -s -k --request POST --data-binary "@$ZIP_FILE" -H "Authorization: GoogleLogin auth=${GOOGLE_LOGIN_TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $ZIP_FILE_MIME_TYPE" -H "Slug: $ZIP_FILE" "$GOOGLE_UPLOAD_URI"

rm -f $ZIP_FILE

if [ $? -ne 0 ]; then
   echo "[ERROR] There was an error in uploading the file."
   exit 1
fi

