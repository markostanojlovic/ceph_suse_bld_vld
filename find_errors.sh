# Script for greping logs for errors 
# it's using config/error_search_strings as a list of key words 
# as script argument is used log directory which to search, if non provided, it's used entire log dir
# run it from BASEDIR directory: ~/ceph_suse_bld_vld
# USAGE EXAMPLE: ./find_errors.sh log/deployment_2018_06_14_12_01

SEARCH_DIR=log
if [[ -n $1 ]];then SEARCH_DIR=$1;fi
while read SEARCH_KEYWORD;do grep -ir --color=auto $SEARCH_KEYWORD ${SEARCH_DIR}/*;done < config/error_search_strings

# list log files that need to be checked
LOGS_LIST=$(while read SEARCH_KEYWORD;do grep -ir $SEARCH_KEYWORD log/*;done < config/error_search_strings |awk -F ':' '{print $1}'|sort|uniq)

echo
echo "Check following log files:"
for FILE in $LOGS_LIST;do echo $FILE;done


