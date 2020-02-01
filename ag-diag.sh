#!/bin/bash

# RedHat/Ubuntu Version 1.1

# For Browser Monitors on Private.
#
# This script is made for diagnostics of support cases that match all of these criteria:
# - Active Gate with Synthetic module has been installed.
# - Active Gate and VUC are running.
# - No tests are being executed.
# - The diagnostic test in VUC is failing.
# - Diagnostic fails because of Chromium terminating abnormally or of unknown reason.

# Custom paths might be used by customers to install AG. 
# Please, replace default paths here accordingly (do not add '/' at the end):
installDir=/opt/dynatrace
logDir=/var/log/dynatrace
configDir=/var/lib/dynatrace
tempDir=/var/tmp/dynatrace

# Check root access
uid="$(id -u)"
if [ "${uid}" != "0" ] ; then
	echo "Error! Insufficient rights. You must run this script with superuser privileges."
	exit 1
fi

# ROOT # Get inotify-related metrics
echo "### Check inotify settings and current usage..."
echo "### Settings:"
sysctl fs.inotify
echo "### Count inotify:"
lsof | grep inotify | wc -l
echo "### Usage:"
df -i
echo "### Done."

# ROOT # Get storage-related metrics
echo "### Check disk size and available disk space..."
du -h -d1 $logDir/synthetic
du -h -d1 $tempDir/synthetic/
du -h -d1 $installDir/synthetic/
df -h
echo "### Done."

# ROOT # Obtain working Chrom* processes
echo "### Obtain working Chrom* processes..."
ps -ef | grep chrom | grep -v grep
echo "### Done."

# ROOT # Enable crash dumps for Chromium:
echo "### Enable crash dumps..."
sed -i 's/com.ruxit.vuc.browser.enableCrashDumps=false/com.ruxit.vuc.browser.enableCrashDumps=true/g' $configDir/synthetic/config/config.properties
echo "### Done."

# ROOT # Replace log4j.xml to turn on debug logging:
echo "### Increase logging level to 'debug'..."
sed -i 's/Logger name="org.apache.http" level="fatal"/Logger name="org.apache.http" level="debug"/g' $configDir/synthetic/config/log4j2.xml
sed -i 's/Root level="info"/Root level="debug"/g' $configDir/synthetic/config/log4j2.xml
sed -i 's/Logger name="com.ruxit.vuc.beacon.BeaconSenderService" level="info"/Logger name="com.ruxit.vuc.beacon.BeaconSenderService" level="debug"/g' $configDir/synthetic/config/log4j2.xml
sed -i 's/Logger name="com.ruxit.vuc.rest.LogEntryService" level="info"/Logger name="com.ruxit.vuc.rest.LogEntryService" level="debug"/g' $configDir/synthetic/config/log4j2.xml
sed -i 's/Logger name="abstractBrowserLogger" level="info"/Logger name="abstractBrowserLogger" level="debug"/g' $configDir/synthetic/config/log4j2.xml
echo "### Done."

# Restart VUC to apply new logging level
echo "### Restarting Synthetic..."
systemctl restart vuc
echo "### Done."

# Try browser --version (symlink ok? binary in place? binary ok?):
echo "### Check browser's version..."
$installDir/synthetic/browser -version
echo "### Done."

# Check system version and virtualization
echo "### Get OS version and virtualization type..."
hostnamectl
echo "### Done."

# Check extended ACLs of files used by Synthetic
echo "### Check extended ACLs of files..."
getfacl $tempDir $tempDir/synthetic $tempDir/synthetic/cache/ $tempDir/synthetic/logs $tempDir/synthetic/browser-home $tempDir/synthetic/browser-home/chromium
getfacl $configDir $configDir/synthetic $configDir/synthetic/config/config.properties
getfacl $installDir $installDir/synthetic $installDir/synthetic/browser $installDir/synthetic/vucontroller $installDir/synthetic/vucontroller/playback $installDir/synthetic/vucontroller/playback/playbackengine $installDir/synthetic/vucontroller/playback/websocketextension
getfacl /usr/bin /usr/bin/chromium-browser
getfacl /usr/lib64 /usr/lib64/chromium-browser /usr/lib64/chromium-browser/chromium-browser.sh
getfacl /var/log $logDir $logDir/synthetic $logDir/synthetic/vuc.log
echo "### Done."

# Get content of dynatracefunctions file
echo "### Get content of dynatracefunctions file..."
cat /etc/init.d/dynatracefunctions
echo "### Done."

# Get content of vuc.service
echo "### Get content of vuc.service file..."
cat /etc/systemd/system/vuc.service
echo "### Done."

# Check current mode of SELinux
echo "### Check SELinux state..."
getenforce
echo "### Done."

# Check security context of Chromium binary and symlinks
echo "### Check security context of Chromium binary and symlinks..."
ls -Z $installDir/synthetic/browser
ls -Z /usr/bin/chromium-browser
ls -Z /usr/lib64/chromium-browser/chromium-browser.sh
echo "### Done."

# SUDO # Try to run browser as VUC does
echo "### Try to start browser in the same way as VUC does..."
export DISPLAY=:99;sudo -u dtuserag $installDir/synthetic/browser --user-data-dir=$tempDir/synthetic/cache/vuc_work_1234 --disk-cache-dir=$tempDir/synthetic/cache/vuc_work_1234 --disk-cache-size=104857600 --disable-popup-blocking --ssl-version-min=tls1 --test-type --ignore-certificate-errors --user-agent="Mozilla/5.0 (X11; Ubuntu; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.131 Safari/537.36 RuxitSynthetic/1.0 v5277689 t8603464788954044517" --no-default-browser-check --no-first-run --disable-translate --disable-web-security --disable-background-networking --disable-plugins-discovery --dns-prefetch-disable --noerrdialogs --disable-default-apps --disable-desktop-notifications --disable-crl-sets --allow-outdated-plugins --always-authorize-plugins --disable-web-resources --silent-debugger-extension-api --disable-internal-flash --disable-bundled-ppapi-flash --disable-appcontainer --load-extension=$installDir/synthetic/vucontroller/playback/playbackengine,$installDir/synthetic/vucontroller/playback/websocketextension --disable-extensions-except=$installDir/synthetic/vucontroller/playback/playbackengine,$installDir/synthetic/vucontroller/playback/websocketextension --window-size=1024,768 --window-position=100,100 --enable-logging file:///dev/null/params=websocketPort=7878?apiToken=1?chromeId=1?ChromePlayerLogging=ruxit?ChromePlayerLoggingLevel=DEBUG?enableDTInjection=true?private=true?locationId=1 &

# wait for 10s
sleep 10

# kill chromium, we have enough
ps -ef | grep vuc_work_1234 | grep -v grep | awk '{ print $2; }' | xargs kill -9

echo "### Done."

# ROOT # Get audit logs (SELinux?)
echo "### Get audit logs..."
grep type=AVC /var/log/audit/audit.log
echo "### Done."

# Get journalctl entries (error details, anti-virus, etc.)
echo "### Get journalctl entries..."
journalctl --utc -a -n 1000 > journalctl.out
cat journalctl.out
rm -f journalctl.out
echo "### Done."


