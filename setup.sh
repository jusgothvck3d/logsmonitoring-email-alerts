#!/bin/bash
#needed ^ at the start off all bash scripts so that the interpreter can use the appropriate shell

echo "Starting setup for AutoLogMon Script..."
#will print a friendly message at the beginning of execution to allow the user to understand that the script has started

echo "Updating system packages..."
sudo apt update -y
#updates all system packages and makes sure you have the latest version


echo "Installing required package(s): ssmtp"
sudo apt install ssmtp -y
#installs the required ssmtp package that allows for sending emails using an SMTP server

# Verify installations
dependencies=("ssmtp" "grep" "wc")
for neededPACK in "${dependencies[@]}"; do
    if ! command -v $neededPACK &> /dev/null; then
        echo "Error: $neededPACK is not installed. Please check your system."
        exit 1
    fi
done
#an if statement that will check to see if the required dependencies are installed and if the packages aren’t you will be prompted to do so.

echo "All required dependencies are installed and ready to use!"
#if you made it pass installations checks without errors you’ll see this message

if [ ! -f "/etc/ssmtp/ssmtp.conf" ]; then #will check if the ssmtp.conf file exist
    echo "ssmtp.conf file not found! Creating a default example configuration..." #if it doesn’t it will notify the user that a sample configuration is being made
    sudo bash -c 'cat > /etc/ssmtp/ssmtp.conf <<EOF #creating the configuration file

#Start of the default sSMTP configuration file (must be updated in order for script to work)
# The person who gets all mail for userids < 1000
root=your-email@example.com

# The place where the mail goes. The actual machine name is required.
# Replace with your SMTP server (e.g., Gmail, Yahoo, Outlook).
mailhub=smtp.gmail.com:587

# Authentication details
AuthUser=your-email@example.com
AuthPass=your-app-password

# Use TLS/STARTTLS for secure connections
UseTLS=YES
UseSTARTTLS=YES

# Where will the mail seem to come from?
rewriteDomain=gmail.com

# The full hostname of your machine
hostname=$(hostname)

# Allow users to specify their own "From" address
FromLineOverride=YES
EOF'
#end of the default sSMTP configuration file

    echo "Example ssmtp.conf file created. Please edit /etc/ssmtp/ssmtp.conf to match your email settings!" #displays if you didn’t have a ssmtp.conf on your system indicating a new file must be created
else
    echo "ssmtp.conf file already exists. Skipping creation." #displays if you already have a ssmtp.conf indicating a new file doesn’t have to be created
fi

echo "Setting secure permissions for ssmtp.conf..."
sudo chmod 600 /etc/ssmtp/ssmtp.conf
# Secure the ssmtp configuration


echo -e "\n--- SSMTP Configuration Instructions ---"
echo "To send emails with sSMTP, ensure the following settings are correct in /etc/ssmtp/ssmtp.conf:"
echo "1. Replace 'your-email@example.com' with your email address."
echo "2. Replace 'your-app-password' with the app password for your email account."
echo "3. If you're using Gmail, leave 'mailhub=smtp.gmail.com:587' as is."
echo "4. For other providers, update 'mailhub' with the correct SMTP server and port."
echo "5. Make sure the file is secure with: sudo chmod 600 /etc/ssmtp/ssmtp.conf"
echo "-----------------------------------------"
#Sample instructions for setting up your ssmtp.conf file that needs in order to send email notifications 

echo "Setup complete! You can now run the autologmon.sh script."
#Indicating that the setup stage is finished and ready to start using the automated log monitoring (specifically to the /var/log/auth.log file) along with the features needed to send emails to the designated email address.
