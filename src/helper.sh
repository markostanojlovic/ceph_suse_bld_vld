# Helper functions 
# Common functions used by TC scripts, part of test framework

function source_cfg {
  if [[ -z $1 ]]
  then 
    echo "Error: Missing cfg file as first argument."
    exit 1
  else 
    source $1
  fi
}

function setup_log_path {
  # log path is second arg, if not existing creating one
  if [[ -z $2 ]]
  then
    LOG_PATH=log/testrun_$(date +%Y_%m_%d_%H_%M)
    mkdir -p $LOG_PATH
  else
    LOG_PATH=$2
  fi
  SCRIPT_NAME=${0##*/}
  SCRIPT_NAME_BASE=${SCRIPT_NAME%*\.sh}
  LOG=${LOG_PATH}/${SCRIPT_NAME_BASE}.log
  echo $LOG
}

