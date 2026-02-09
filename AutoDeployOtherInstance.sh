#!/bin/bash
set -x

# Path to the JAR files of instance 2 and instance 4
ENVIRONMENT="apptest"
CORE_SERVICE2="hani_core_apptest2"
CORE_SERVICE3="hani_core_apptest3"
CORE_SERVICE4="hani_core_apptest4"
JAR_DEFINITION="main-with-all-dependencies"
DEPLOYMENT_USER="developer"
LIB_BASE_DIR="/var/hani/libs"
LOG_BASE_DIR="/var/hani/logs"

# Log file
LOG_FILE="/var/hani/libs/result_Core4_deploy_sync.log"

# Compute SHA1 hashes for both files
HASH2=$(/usr/bin/sha1sum "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}2.jar" | awk '{print $1}')
HASH4=$(/usr/bin/sha1sum "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}4.jar" | awk '{print $1}')

echo "$(date '+%Y-%m-%d %H:%M:%S') - Hash2: $HASH2 , Hash4: $HASH4" >> "$LOG_FILE"

# If hashes are different

if [ "$HASH2" != "$HASH4" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Hash mismatch detected. Updating instance 4..." >> "$LOG_FILE"

    BACKUP_TIMESTAMP=$(date -d "now" +'%Y%m%d_%H%M')

    # Backup the current instance version
    cp "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}3.jar" \
           "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}3.jar-${BACKUP_TIMESTAMP}"

    # Copy the new version from instance 2 to instance 4
    cp "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}2.jar" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}3.jar"
    cp "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}2.jar" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}4.jar"


    # Restart instance 3 service
    sudo /etc/init.d/"${CORE_SERVICE3}" restart

#        TIME_LIMIT=2100      # 35 minutes
#        SLEEP_INTERVAL=5    # check every 5 seconds


#   START_TIME=$(date +%s)
TIME_LIMIT=2100
SLEEP_INTERVAL=5

START_TIME=$(date +%s)

while true; do
    if grep -q -i ready "${LOG_BASE_DIR}"/*"${ENVIRONMENT}"3*.stdout.log; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Core-3 is ready" >> "$LOG_FILE"
        break
    fi

    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

    if [ "${ELAPSED_TIME}" -ge "${TIME_LIMIT}" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Ready not detected after 35 minutes" >> "$LOG_FILE"
        exit 1
    fi

    sleep "${SLEEP_INTERVAL}"
done

sudo /etc/init.d/"${CORE_SERVICE4}" restart
echo "$(date '+%Y-%m-%d %H:%M:%S') - Core-4 restarted successfully" >> "$LOG_FILE"



else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Hashes are identical. No action needed." >> "$LOG_FILE"
fi

