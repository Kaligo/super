#!/bin/bash
# This script generates filtered progress logs on a system that is being pushed the MDM macOS update/upgrade workflows.
# The logs are saved to the current user's Desktop and automatically opened in the Console.app.

# Name for the filtered MDM managed client command progress log:
mdmCommandLOG="mdmCommand.log"

# Name for the filtered MDM update/upgrade progress log:
mdmUpdateLOG="mdmUpdate.log"

checkRoot() {
if [[ "$(id -u)" -ne 0 ]]; then
	echo "Exit: $(basename "$0") must run with root privileges."
	exit 1
fi
}

checkCurrentUser() {
currentUserNAME=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')
if [[ -z $currentUserNAME ]]; then
	echo "Exit: No GUI user currently logged in."
	exit 1
elif [[ "$currentUserNAME" = "root" ]] || [[ "$currentUserNAME" = "_mbsetupuser" ]] || [[ "$currentUserNAME" = "loginwindow" ]]; then
	echo "Exit: Current GUI user is system account $currentUserNAME."
	exit 1
else
	echo "Status: Current GUI user name is $currentUserNAME."
fi
}

startLogs() {
mdmCommandLOG="/Users/$currentUserNAME/Desktop/$mdmCommandLOG"
echo "Status: Starting MDM managed client command progress log at: $mdmCommandLOG"
rm -f "$mdmCommandLOG"
log stream --style compact --predicate 'subsystem == "com.apple.ManagedClient" AND category == "HTTPUtil"' >> "$mdmCommandLOG" &
mdmCommandStreamPID=$!
chmod a+rw "$mdmCommandLOG"

mdmUpdateLOG="/Users/$currentUserNAME/Desktop/$mdmUpdateLOG"
echo "Status: Starting MDM update/upgrade progress log at: $mdmUpdateLOG"
rm -f "$mdmUpdateLOG"
log stream --style compact --predicate 'process == "softwareupdated" AND composedMessage CONTAINS "Reported progress"' >> "$mdmUpdateLOG" &
mdmWorkflowStreamPID=$!
chmod a+rw "$mdmUpdateLOG"
}

openLogs() {
if [[ ! -f "$mdmCommandLOG" ]]; then
	echo "Exit: Can't find log file at: $mdmCommandLOG."
	kill -9 "$mdmCommandStreamPID" > /dev/null 2>&1
	kill -9 "$mdmWorkflowStreamPID" > /dev/null 2>&1
	exit 1
fi
if [[ ! -f "$mdmUpdateLOG" ]]; then
	echo "Exit: Can't find log file at: $mdmUpdateLOG."
	kill -9 "$mdmCommandStreamPID" > /dev/null 2>&1
	kill -9 "$mdmWorkflowStreamPID" > /dev/null 2>&1
	exit 1
fi
echo "Status: Opening logs for user $currentUserNAME."
sudo -u "$currentUserNAME" open "$mdmUpdateLOG"
sudo -u "$currentUserNAME" open "$mdmCommandLOG"
}

main() {
checkRoot
checkCurrentUser
startLogs
openLogs
echo "Status: MDM logging is active and open in the Console.app, start a macOS update/upgrade workflow on your MDM now to observe the workflow progress."
read -r -p "Status: Press enter when you are ready to stop the active logs and exit this script..."
kill -9 "$mdmCommandStreamPID" > /dev/null 2>&1
kill -9 "$mdmWorkflowStreamPID" > /dev/null 2>&1
}

main
exit 0
