#!/bin/bash
set -x

# =============================================================================
# CONFIGURATION SECTION - All variables consolidated at the top
# =============================================================================

# Environment and Service Configuration
ENVIRONMENT="apptest"
CORE_SERVICE="hani_core_apptest1"
CORE_SERVICE2="hani_core_apptest2"
BATCH_SERVICE="hani_batch_apptest"
JAR_DEFINITION="main-with-all-dependencies"
DEPLOYMENT_USER="developer"

# File and Path Configuration
LOCK_FILE="/tmp/apptest-core-auto-deploy.sh"
FTP_BASE_DIR="/var/hani/libs/ftp"
LIB_BASE_DIR="/var/hani/libs"
LOG_BASE_DIR="/var/hani/logs"
RESULT_FILE="/var/hani/libs/result.txt"

# Deployment Control Configuration
TIME_LIMIT=2100           # Maximum wait time for service readiness (seconds)
SLEEP_INTERVAL=5          # Interval between service status checks (seconds)
MIN_JAR_SIZE=250000       # Minimum acceptable JAR file size (kilobytes)

# Remote Server Configuration
REMOTE_SERVER="root@192.168.1.53"
REMOTE_CICD_BASE="/cicd/${ENVIRONMENT}-auto-deploy/core/inprogress/active"
REMOTE_LOG_BASE="/${ENVIRONMENT}/core/logs"

# =============================================================================
# PRE-DEPLOYMENT VALIDATION CHECKS
# =============================================================================

# Check if apptest2 environment is ready
if ! grep -q -i ready "${LOG_BASE_DIR}"/*"${ENVIRONMENT}2"*.stdout.log; then
    exit 0
fi

# Check if new JAR file exists in FTP directory
if [ ! -f "${FTP_BASE_DIR}"/main-with*.jar ]; then
    exit 0
fi

# Check if another instance of this script is already running
if [ -n "$(ls "${LOCK_FILE}" 2>/dev/null)" ]; then
    echo "Another instance of this script is already running"
    exit 0
fi

# =============================================================================
# DEPLOYMENT INITIALIZATION
# =============================================================================

set -x
sleep 20

# Create lock file to prevent multiple executions
touch "${LOCK_FILE}"

# Identify the latest deployment control file
DEPLOYMENT_CONTROL_FILE=$(ls "${FTP_BASE_DIR}"/inprogress/*.txt 2>/dev/null | sort -n | tail -n 1)

# Set proper ownership for hani directory
chown -R "${DEPLOYMENT_USER}":"${DEPLOYMENT_USER}" /var/hani/

# =============================================================================
# JAR FILE VALIDATION AND COMPARISON
# =============================================================================

# Calculate checksums for current and new JAR files
NEW_JAR_CHECKSUM=$(/usr/bin/sha1sum "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar" | awk '{print $1}')
CURRENT_JAR_CHECKSUM=$(/usr/bin/sha1sum "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar" | awk '{print $1}')

# Calculate file sizes for validation
CURRENT_JAR_SIZE=$(du -sc "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar" | awk '{print $1}' | sort -u)
NEW_JAR_SIZE=$(du -sc "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar" | awk '{print $1}' | sort -u)

echo "Deployment script instance: ${LOCK_FILE}"

# =============================================================================
# DEPLOYMENT DECISION LOGIC
# =============================================================================

# Proceed only if JAR files are different (new version detected)
if [ "${NEW_JAR_CHECKSUM}" != "${CURRENT_JAR_CHECKSUM}" ]; then

    # Validate new JAR meets minimum size requirement
    if [ "${NEW_JAR_SIZE}" -ge "${MIN_JAR_SIZE}" ]; then
       #echo "Deployment rejected Same Hash" >> "${DEPLOYMENT_CONTROL_FILE}" 
        # =====================================================================
        # DEPLOYMENT PREPARATION AND BACKUP
        # =====================================================================

        # Generate timestamp for backup files
        BACKUP_TIMESTAMP=$(date -d "now" +'%Y%m%d_%H%M')

        # Log deployment initiation
        echo "${BACKUP_TIMESTAMP}" >> "${RESULT_FILE}"
        echo "${DEPLOYMENT_CONTROL_FILE}" >> "${RESULT_FILE}"
        echo "New JAR checksum = ${NEW_JAR_CHECKSUM}" >> "${RESULT_FILE}"
        echo "Current JAR checksum = ${CURRENT_JAR_CHECKSUM}" >> "${RESULT_FILE}"

        # Backup current JAR files before replacement
        cp "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar" \
           "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar-${BACKUP_TIMESTAMP}"

        ROLLBACK_FILE="${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar-${BACKUP_TIMESTAMP}"
        echo "Backup created: ${ROLLBACK_FILE}" >> "${RESULT_FILE}"

        cp "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}1.jar" \
           "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}1.jar-${BACKUP_TIMESTAMP}"

        # =====================================================================
        # JAR DEPLOYMENT EXECUTION
        # =====================================================================

        # Deploy new JAR files
        cp "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}1.jar"
        cp "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar"

        # =====================================================================
        # SERVICE RESTART
        # =====================================================================

        # Restart core and batch services with new JAR
        sudo /etc/init.d/"${CORE_SERVICE}" restart
        sleep 5
        sudo /etc/init.d/"${BATCH_SERVICE}" restart

        # =====================================================================
        # DEPLOYMENT VERIFICATION LOOP
        # =====================================================================

        START_TIME=$(date +%s)

        while true; do
            # Check if core-1 service is ready
            if grep -q -i ready "${LOG_BASE_DIR}"/*"${ENVIRONMENT}"1*.stdout.log; then

                # Check if batch service is ready
                if grep -q -i "batch server" "${LOG_BASE_DIR}"/hani-batch-server-"${ENVIRONMENT}".stdout.log; then

                    # =========================================================
                    # SUCCESSFUL DEPLOYMENT HANDLING
                    # =========================================================

                    echo "Core-1 service is ready" >> "${RESULT_FILE}"
                    echo "Deployment successful" >> "${DEPLOYMENT_CONTROL_FILE}"

                    # Transfer control file to remote server
                    scp "${DEPLOYMENT_CONTROL_FILE}" "${REMOTE_SERVER}:${REMOTE_CICD_BASE}/"

                    # Identify log files for transfer
                    CORE_LOG_DETAIL=$(ls "${LOG_BASE_DIR}"/hani*"${ENVIRONMENT}"1*-server.log)
                    CORE_LOG_STDOUT=$(ls "${LOG_BASE_DIR}"/hani*"${ENVIRONMENT}"1*.stdout.log)
                    BATCH_LOG_STDOUT=$(ls "${LOG_BASE_DIR}"/hani-batch-server-"${ENVIRONMENT}".stdout.log)

                    # Transfer logs to remote server
                    scp "${CORE_LOG_STDOUT}" "${REMOTE_SERVER}:${REMOTE_LOG_BASE}/"
                    scp "${CORE_LOG_DETAIL}" "${REMOTE_SERVER}:${REMOTE_LOG_BASE}/"
                    scp "${BATCH_LOG_STDOUT}" "${REMOTE_SERVER}:${REMOTE_LOG_BASE}/"

                    # Deploy to additional instances
                    cp "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}2.jar"
                    cp "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}3.jar"

                    echo "Additional instances updated successfully"

                    # Restart all other core instances (except the main one)
                    sudo /etc/init.d/"${CORE_SERVICE2}" restart
#                    for SERVICE_FILE in /etc/init.d/hani_core_apptest*; do
#                        if [ "${SERVICE_FILE}" == "/etc/init.d/${CORE_SERVICE}" ]; then
#                            echo "Main service already restarted"
#                        else
#                            sudo "${SERVICE_FILE}" restart
#                            echo "Restarted: ${SERVICE_FILE}"
#                        fi
#                    done

                    # Move control file to result directory
                    mv "${DEPLOYMENT_CONTROL_FILE}" "${FTP_BASE_DIR}/result/"
                    break
                fi
            fi

            # =============================================================
            # TIMEOUT AND ROLLBACK HANDLING
            # =============================================================

            CURRENT_TIME=$(date +%s)
            ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

            if [ "${ELAPSED_TIME}" -ge "${TIME_LIMIT}" ]; then
                echo "ERROR: Service readiness timeout after ${TIME_LIMIT} seconds"
                echo "Initiating rollback procedure" >> "${RESULT_FILE}"
                echo "Deployment rejected" >> "${DEPLOYMENT_CONTROL_FILE}"

                # Transfer failure notification to remote server
                scp "${DEPLOYMENT_CONTROL_FILE}" "${REMOTE_SERVER}:${REMOTE_CICD_BASE}/"

                # Identify log files for transfer
                CORE_LOG_DETAIL=$(ls "${LOG_BASE_DIR}"/hani*"${ENVIRONMENT}"1*-server.log)
                CORE_LOG_STDOUT=$(ls "${LOG_BASE_DIR}"/hani*"${ENVIRONMENT}"1*.stdout.log)
                BATCH_LOG_STDOUT=$(ls "${LOG_BASE_DIR}"/hani-batch-server-"${ENVIRONMENT}".stdout.log)

                # Transfer logs to remote server
                scp "${CORE_LOG_STDOUT}" "${REMOTE_SERVER}:${REMOTE_LOG_BASE}/"
                scp "${CORE_LOG_DETAIL}" "${REMOTE_SERVER}:${REMOTE_LOG_BASE}/"
                scp "${BATCH_LOG_STDOUT}" "${REMOTE_SERVER}:${REMOTE_LOG_BASE}/"

                # =========================================================
                # ROLLBACK EXECUTION
                # =========================================================

                # Restore previous JAR version
                yes | cp "${ROLLBACK_FILE}" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}.jar"
                mv "${ROLLBACK_FILE}" "${LIB_BASE_DIR}/${JAR_DEFINITION}-${ENVIRONMENT}1.jar"

                # Clean up FTP directory
                rm -rf "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar"
                rm -rvf "${FTP_BASE_DIR}"/inprogress/*.txt

                # Restart services with rollback version
                sudo /etc/init.d/"${CORE_SERVICE}" restart
                sleep 5
                sudo /etc/init.d/"${BATCH_SERVICE}" restart

                # Move control file to result directory
                mv "${DEPLOYMENT_CONTROL_FILE}" "${FTP_BASE_DIR}/result/"
                break
            fi

            sleep "${SLEEP_INTERVAL}"
        done

        echo "Deployment cycle completed" >> "${RESULT_FILE}"

    else
        # New JAR size validation failed
        echo "New JAR size (${NEW_JAR_SIZE}KB) is below minimum requirement (${MIN_JAR_SIZE}KB)" >> "${RESULT_FILE}"
    fi

else
    # Checksums are identical - no deployment needed
    #echo "JAR checksums identical - no deployment required" >> "${DEPLOYMENT_CONTROL_FILE}"
    echo "Deployment rejected Same Hash" >> "${DEPLOYMENT_CONTROL_FILE}"
    scp "${DEPLOYMENT_CONTROL_FILE}" "${REMOTE_SERVER}:${REMOTE_CICD_BASE}/"
    mv "${DEPLOYMENT_CONTROL_FILE}" "${FTP_BASE_DIR}/result/"
fi

# =============================================================================
# POST-DEPLOYMENT CLEANUP
# =============================================================================

# Remove lock file and temporary JAR
rm -rvf "${LOCK_FILE}"
rm -rvf "${FTP_BASE_DIR}/${JAR_DEFINITION}.jar"

echo "Deployment process completed"
echo "============================================"


