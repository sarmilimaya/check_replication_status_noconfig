#!/usr/bin/ksh

#########################################################################################################
#
# check_replication_status.ksh (ksh script)
#
# Purpose:
# The script checks the replication status of the database PROJDBDB from the table ASN.IBMSNAP_SUBS_SET
# and sends out an email notification if the replication fails ( status is -1 )
#
# Execution:
# The Script has to be scheduled via crontab for running once in every 30 minutes as shown below.
#
#       0,30 * * * * check_replication_status.ksh >/dev/null 2>&1
#
# The script can also be run directly from putty as shown below.
#
#       nohup check_replication_status.ksh &
#
#########################################################################################################

. /home/db2inst1/sqllib/db2profile

#_________________________________________________
# Redirecting the output to log file
#_________________________________________________


rm -f ./check_replication_status.log
readonly LOGFILE="./check_replication_status.log"

 exec 1>> $LOGFILE
 exec 2>/dev/null

echo "Starting the script check_replication_status.ksh at " `date`

#_________________________________________________
echo `date` " : Step 1 - Checking the Existence of Config File"
#_________________________________________________

if [[ ! -f ./config.properties ]]; then
    print "\nScript failed with Error : Configuration file config.properties does not exist !!!"
    exit -1
fi

#_________________________________________________
echo `date` " : Step 2 - Parsing the Config File"
#_________________________________________________

    DB=`awk -F "="  '$1 ~ /DB/{print $2}' config.properties | tr -d ' '`
    USERID=`awk -F "="  '$1 ~ /USERID/{print $2}' config.properties | tr -d ' '`
    PASSWORD=`awk -F "="  '$1 ~ /PASSWORD/{print $2}' config.properties | tr -d ' '`
    MAIL_LIST=`awk -F "="  '$1 ~ /MAIL_LIST/{print $2}' config.properties | tr -d ' '`

     if [[ $DB == '' || $USERID == '' || $PASSWORD == '' || $MAIL_LIST == '' ]]; then
        print "\nERROR !!! Missing information in the configuration file config.properties !!!"
        print "\n######  Configuration file should have the following structure  ######"
        print "\n\t DB=<Database Name>"
        print "\t USERID=<User ID for DB>"
        print "\t PASSWORD=<Password for DB>"
        print "\t MAIL_LIST=<Mails IDS>"
        exit -1
    fi


#_________________________________________________
echo `date` " : Step 3 - Connecting to the Database PROJDBDB"
#_________________________________________________

db2 connect to $DB user $USERID using $PASSWORD;
if [[ $? != 0 ]]; then
    print "\nUnable to connect to the database PROJDBDB. check_replication_status.ksh failed !!!"
    exit -1
fi

#___________________________________________________________
echo `date` " : Step 4 - Fetching records from ASN.IBMSNAP_SUBS_SET table and placing failed replication details in a temp file"
#___________________________________________________________

db2 -x "select APPLY_QUAL,SET_NAME,SOURCE_SERVER,SOURCE_ALIAS,TARGET_SERVER,TARGET_ALIAS,STATUS from ASN.IBMSNAP_SUBS_SET" > temp_data.txt

while read line; do
   APPLY_QUAL=`echo $line | cut -d'  ' -f1`
   SET_NAME=`echo $line | cut -d'  ' -f2`
   SOURCE_SERVER=`echo $line | cut -d'  ' -f3`
   SOURCE_ALIAS=`echo $line | cut -d'  ' -f4`
   TARGET_SERVER=`echo $line | cut -d'  ' -f5`
   TARGET_ALIAS=`echo $line | cut -d'  ' -f6`
   STATUS=`echo $line | cut -d'  ' -f7`

   if [[ $STATUS == -1 ]]; then
       echo $APPLY_QUAL"  "$SET_NAME"  "$SOURCE_SERVER"  "$SOURCE_ALIAS"  "$TARGET_SERVER"  "$TARGET_ALIAS"  "$STATUS"\n" >> temp_repfailed_file.txt
   fi
done < temp_data.txt


#___________________________________________________________
echo `date` " : Step 5 - If replication has failed, then sleep for 10 minutes and recheck the status of the replication after 10 minutes"
echo "and send out an email if the replication status is still -1"
#___________________________________________________________

if [[ -s temp_repfailed_file.txt ]]; then
    sleep 600
    while read line; do
        APPLY_QUAL=`echo $line | cut -d'  ' -f1`
        SET_NAME=`echo $line | cut -d'  ' -f2`
        SOURCE_SERVER=`echo $line | cut -d'  ' -f3`
        SOURCE_ALIAS=`echo $line | cut -d'  ' -f4`
        TARGET_SERVER=`echo $line | cut -d'  ' -f5`
        TARGET_ALIAS=`echo $line | cut -d'  ' -f6`
        STATUS=`echo $line | cut -d'  ' -f7`
        STATUS1=`db2 -x "select STATUS from ASN.IBMSNAP_SUBS_SET where APPLY_QUAL='$APPLY_QUAL' and SET_NAME='$SET_NAME' and SOURCE_SERVER='$SOURCE_SERVER' and SOURCE_ALIAS='$SOURCE_ALIAS' and TARGET_SERVER='$TARGET_SERVER' and TARGET_ALIAS='$TARGET_ALIAS'"`

        if [[ $STATUS1 -eq '-1' ]]; then
            print "Replication Failed on the database PROJDBDB. Please find the details below. \n" | tee -a mail_content.txt
            print "Hostname      :   inmbz1076.in.dst.ibm.com\n" | tee -a mail_content.txt
            print "APPLY_QUAL    :   $APPLY_QUAL\n" | tee -a mail_content.txt
            print "SET_NAME      :   $SET_NAME\n" | tee -a mail_content.txt
            print "SOURCE_SERVER :   $SOURCE_SERVER\n" | tee -a mail_content.txt
            print "SOURCE_ALIAS  :   $SOURCE_ALIAS\n" | tee -a mail_content.txt
            print "TARGET_SERVER :   $TARGET_SERVER\n" | tee -a mail_content.txt
            print "TARGET_ALIAS  :   $TARGET_ALIAS\n" | tee -a mail_content.txt
            print "STATUS        :   -1"
            print "\n\n"
            cat mail_content.txt | mail -s "Replication failed on PROJDBDB Database" $MAIL_LIST
            rm -f mail_content.txt
       fi
    done < temp_repfailed_file.txt
fi

#_________________________________________________________________
echo `date` " : Step 6 - Removing the temporary files"
#_________________________________________________________________

rm -f temp_data.txt
rm -f mail_content.txt
rm -f temp_repfailed_file.txt

#_________________________________________________________________
echo `date` " : Step 7 - Terminating the DB connection"
#_________________________________________________________________

db2 terminate;

echo "Finishing the script at " `date`
