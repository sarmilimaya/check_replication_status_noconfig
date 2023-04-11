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
# Step 1 : Mail Ids Definitions
#_________________________________________________

readonly MAIL_LIST='abc.ibm.com,xyz@in.ibm.com'

#_________________________________________________
# Step 2 : Connecting to the Database PROJDBDB
#_________________________________________________

db2 connect to $DB user $USERID using $PASSWORD;
if [[ $? != 0 ]]; then
    print "\nUnable to connect to the database PROJDBDB. check_replication_status.ksh failed !!!"
    exit -1
fi
    
#___________________________________________________________
# Step 3 : Fetching records from ASN.IBMSNAP_SUBS_SET table
# and placing in a temp file
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
                echo "Replication Failed on the database PROJDBDB. Please find the details below. \n"  >> mail_content.txt
                echo "Hostname      :   inmbz1076.in.dst.ibm.com\n" >> mail_content.txt
                echo "APPLY_QUAL    :   $APPLY_QUAL\n" >> mail_content.txt
                echo "SET_NAME      :   $SET_NAME\n" >> mail_content.txt
                echo "SOURCE_SERVER :   $SOURCE_SERVER\n" >> mail_content.txt
                echo "SOURCE_ALIAS  :   $SOURCE_ALIAS\n" >> mail_content.txt
                echo "TARGET_SERVER :   $TARGET_SERVER\n" >> mail_content.txt
                echo "TARGET_ALIAS  :   $TARGET_ALIAS\n" >> mail_content.txt
                cat mail_content.txt | mail -s "Replication failed on PROJDBDB Database" $MAIL_LIST
                rm mail_content.txt
                
        fi
            
done < temp_data.txt

#_________________________________________________________________
# Step 4 : Removing the temporary files
#_________________________________________________________________

rm temp_data.txt
rm mail_content.txt


#_________________________________________________________________
# Step 5 : Terminating the DB connection
#_________________________________________________________________

db2 terminate;
