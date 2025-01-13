#!/bin/bash

#--------------------------------------------------------------------------------------------------
#                                      AutoLogMon.sh                                              *
#--------------------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
# Configure the following variables to customize the script for your environment:                 *
# 1. LOG_FILE: Path to the log file to monitor (default: /var/log/auth.log).                      *
# 2. ALERT_LOG: Log file to store alerts (default: alert_log.txt).                                *
# 3. RECIPIENT_EMAIL: Email address to receive alerts. Replace with your email address.           *
# 4. SMS_GATEWAY: SMS gateway for alerts. Replace with your phone number and carrier's gateway.   *
# 5. WEBHOOK_URL: Webhook URL for alerts (Discord/Slack).                                         *
#    - Separate multiple URLs with commas.                                                        *
#    - Leave blank to prompt the user for a webhook URL at runtime.                               *
#--------------------------------------------------------------------------------------------------

LOG_FILE="/var/log/auth.log"
ALERT_LOG="alert_log.txt"
RECIPIENT_EMAIL="your-email@gmail.com"
SMS_GATEWAY="1234567890@vtext.com"
WEBHOOK_URL=""

#------------------------------------------------------------------------
#                           Risk Levels                                 *
# Low risk: 5-9 failed login attempts.                                  *
# Medium risk: 10-19 failed login attempts.                             *
# High risk: 20+ failed login attempts.                                 *
#  - Adjust thresholds as needed.                                       *
#------------------------------------------------------------------------

LOW_THRESHOLD=5
MEDIUM_THRESHOLD=10
HIGH_THRESHOLD=20

#--------------------------------------------------------------------------------------------------
# Environment Setup:                                                                              *
# 1. Ensures the required dependencies are installed.                                             *
# 2. Updates the system package list.                                                             *
# 3. Installs required packages (e.g., msmtp, curl, jq).                                          *
#--------------------------------------------------------------------------------------------------

function setup_dependencies() {
    echo "Checking and installing dependencies..."

    LAST_UPDATE_FILE="/var/lib/apt/periodic/update-success-stamp"
    if [ ! -f "$LAST_UPDATE_FILE" ] || [ "$(find "$LAST_UPDATE_FILE" -mtime +1 2>/dev/null)" ]; then
        echo "Updating package list..."
        sudo apt update
    fi

    REQUIRED_PACKAGES=("curl" "msmtp" "jq")
    MISSING_PACKAGES=()
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            MISSING_PACKAGES+=("$package")
        else
            echo "$package is already installed."
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        echo "Installing missing packages: ${MISSING_PACKAGES[*]}"
        sudo apt install -y "${MISSING_PACKAGES[@]}"
    fi

#--------------------------------------------------------------------------------------------------
# Email Configuration:                                                                            *
# 1. Checks if the msmtp configuration file exists.                                               *
# 2. Creates a default msmtp configuration for Gmail if none exists.                              *
# 3. Prompts the user to update ~/.msmtprc with their email credentials.                          *
# 4. Note: Provider-specific configurations may vary; check with your provider if needed.         *
#--------------------------------------------------------------------------------------------------

    if [ ! -f "$HOME/.msmtprc" ]; then
        echo "msmtp configuration not found. Creating a default configuration..."
        cat > "$HOME/.msmtprc" <<EOF
# msmtp default configuration
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

# Gmail account settings
account        default
host           smtp.gmail.com
port           587
from           your-email@gmail.com
user           your-email@gmail.com
password       your-app-password
EOF
        chmod 600 "$HOME/.msmtprc"
        echo "msmtp configuration created. Please update ~/.msmtprc with your email credentials."
    else
        echo "msmtp configuration already exists."
    fi

    echo "Dependencies are set up!"
}

#--------------------------------------------------------------------------------------------------
# Monitoring Logic:                                                                               *
# 1. Validates the existence of the specified log file.                                           *
# 2. Monitors the log file for failed login attempts.                                             *
# 3. Counts failed login attempts and identifies corresponding log entries.                       *
# 4. Categorizes alerts by risk level (LOW, MEDIUM, HIGH) based on thresholds.                    *
#--------------------------------------------------------------------------------------------------

function autologmon() {
    if [ -z "$WEBHOOK_URL" ]; then
        read -p "Enter your webhook URL for Discord/Slack notifications (leave blank if not using): " USER_WEBHOOK
        if [[ "$USER_WEBHOOK" =~ ^https:// ]]; then
            WEBHOOK_URL="$USER_WEBHOOK"
        else
            echo "Invalid webhook URL. Skipping webhook notifications."
        fi
    fi

    if [ ! -f "$LOG_FILE" ]; then
        echo "Error: Log file $LOG_FILE not found!"
        exit 1
    fi

    FAILED_LOGS=$(grep "Failed password" "$LOG_FILE" | tail -n 1000)
    MATCH_COUNT=$(echo "$FAILED_LOGS" | wc -l)
    DETAILED_MESSAGE=$(echo "$FAILED_LOGS" | awk '{print "Date: " $1 " " $2 " " $3 ", IP: " $11 ", User: " $9}')

    if [ "$MATCH_COUNT" -ge "$HIGH_THRESHOLD" ]; then
        RISK_LEVEL="HIGH"
    elif [ "$MATCH_COUNT" -ge "$MEDIUM_THRESHOLD" ]; then
        RISK_LEVEL="MEDIUM"
    elif [ "$MATCH_COUNT" -ge "$LOW_THRESHOLD" ]; then
        RISK_LEVEL="LOW"
    else
        RISK_LEVEL="NONE"
    fi

    ALERT_MESSAGE="Detected $MATCH_COUNT failed login attempts. Risk level: $RISK_LEVEL"

    if [ "$RISK_LEVEL" != "NONE" ]; then
        echo -e "Alert logged: $ALERT_MESSAGE"
        echo "$(date): $DETAILED_MESSAGE" >> "$ALERT_LOG"

        # Email
        echo -e "Subject: [$RISK_LEVEL RISK] Log Monitoring Alert\n\n$ALERT_MESSAGE\n\n$DETAILED_MESSAGE" | msmtp "$RECIPIENT_EMAIL"

        # SMS
        TOP_LOGS=$(echo "$FAILED_LOGS" | head -n 3)
        echo -e "ALERT: $MATCH_COUNT failed login attempts.\n$TOP_LOGS" | msmtp "$SMS_GATEWAY"

        # Webhook
        if [ -n "$WEBHOOK_URL" ]; then
            PAYLOAD=$(jq -n --arg content "$ALERT_MESSAGE\n\n$DETAILED_MESSAGE" '{"content":$content}')
            curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL"
        fi
    else
        echo "No alert: $MATCH_COUNT failed login attempts."
    fi
}

setup_dependencies
autologmon