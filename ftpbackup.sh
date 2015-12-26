#!/bin/sh

#Config Preamble
workdir=$(dirname $(realpath -s $0))
cd $workdir

if [ -e "$workdir/$(basename $0 .sh).conf" ]
then
    source "$workdir/$(basename $0 .sh).conf"
elif [ -e "$workdir/$(basename $0 .sh).conf.sample" ]
then
    echo "Please edit the config for your needs and move it to $(basename $0 .sh).conf"
else
    echo "No config file found. Please create one in $(basename $0 .sh).conf"
fi
    
#Check for Software and Variables
command -v lftp > /dev/null 2>&1 || { echo >&2 "lftp is required, but it's not installed. Aborting"; exit 1; }

if [ $* == "--gzip" ]
then
    command -v pigz > /dev/null 2>&1 || { echo >&2 "pigz is required, but it's not installed. Aborting"; exit 1; }
elif [ $* == "--bzip2" ]
then
    command -v pbzip2 > /dev/null 2>&1 || { echo >&2 "pbzip2 is required, but it's not installed. Aborting"; exit 1; }
fi

${host:?The host is not configured.}
${protocol:?The protocol is not configured.}
${user:?The user is not configurted.}
${password:?The password is not configured.}
${localdir:?The local directory is not configured.}
${remotedir:?The remote directory is not configured.}
${source:?The backup source(s) is/are not configured.}

#Create target directory
date=$( date +%Y%m%d-%H%M%S )
mkdir -p $localdir/$date

#Copy Backup Files
for i in "${source[@]}"; do
    cp -R $i $localdir/$date
done

#Compression and Encryption
if [ $* == *"--gzip"* ]
then
    tar -cvf - $localdir/$date | pigz -c > $localdir/$date.tar.gz
elif [ $* == *"--bzip2"* ]
then
    tar -cvf - $localdir/$date | pbzip2 -c > $localdir/$date.tar.bz2
fi

#Sync Backup
lftp -c "mirror -R $localdir $remotedir" -u $user,$password $protocol://$host