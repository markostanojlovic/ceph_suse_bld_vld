# initializing the log directory
LOG_DIR_NAME=deployment_$(date +%Y_%m_%d_%H_%M)
mkdir log/$LOG_DIR_NAME
echo "Created new log directory:"
echo $LOG_DIR_NAME
