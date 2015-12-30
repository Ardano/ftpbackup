#!/bin/sh

#Config Preamble
workdir=$(dirname $(realpath -s $0))
cd $workdir

if [ -e "$workdir/$(basename $0 .sh).conf" ]
then
    source $workdir/$(basename $0 .sh).conf
elif [ -e "$workdir/$(basename $0 .sh).conf.sample" ]
then
    echo "Please edit the sample config for your needs and move it to $(basename $0 .sh).conf"
else
    echo "No config file found. Please create one in $(basename $0 .sh).conf"
fi
    
#Check for Software and Variables
command -v curl > /dev/null 2>&1 || { echo >&2 "curl is required, but it's not installed. Aborting"; exit 1; }
command -v tar > /dev/null 2>&1 || { echo >&2 "tar is required, but it's not installed. Aborting"; exit 1; }

if [[ $* == *"--gzip"* ]]
then
    command -v pigz > /dev/null 2>&1 || { echo >&2 "pigz is required, but it's not installed. Aborting"; exit 1; }
elif [[ $* == *"--bzip2"* ]]
then
    command -v pbzip2 > /dev/null 2>&1 || { echo >&2 "pbzip2 is required, but it's not installed. Aborting"; exit 1; }
fi

if [[ $* == *"--encrypt"* ]]
then
    command -v gpg2 > /dev/null 2>&1 || { echo >&2 "gpg2 is required, but it's not installed. Aborting" exit 1; }
    command -v find > /dev/null 2>&1 || { echo >&2 "find is required, but it's not installed. Aborting" exit 1; }
    if [ -z "$key" ]; then echo "No email or key id configured."; exit 1; fi
fi

if [ -z "$host" ]; then echo "The host is not configured."; exit 1; fi
if [ -z "$port" ]; then echo "The port is not configured."; exit 1; fi
if [ -z "$protocol" ]; then echo "The protocol is not configured."; exit 1; fi
if [ -z "$user" ]; then echo "The user is not configured."; exit 1; fi
if [ -z "$password" ]; then echo "The password is not configured."; exit 1; fi
if [ -z "$localdir" ]; then echo "The local directory is not configured."; exit 1; fi
if [ -z "$remotedir" ]; then echo "The remote directory is not configured."; exit 1; fi
if [ ${#source[@]} -eq 0 ]; then echo "The backup source(s) is/are not configured."; exit 1; fi

#Create target directory
date=$( date +%Y%m%d-%H%M%S )
mkdir -p $localdir/$date

#Copy Backup Files
for i in "${source[@]}"; do
    cp -R $i $localdir/$date
done

#Compression and Encryption
if [[ $* == *"--gzip"* ]]
then
    tar -cf - $localdir/$date | pigz -c > $localdir/$date.tar.gz
    rm -R $localdir/$date
elif [[ $* == *"--bzip2"* ]]
then
    tar -cf - $localdir/$date | pbzip2 -c > $localdir/$date.tar.bz2
    rm -R $localdir/$date
else
    tar -cf - $localdir/$date > $localdir/$date.tar
    rm -R $localdir/$date
fi

if [[ $* == *"--encrypt"* ]]
then
    gpg2 --encrypt --recipient $key $localdir/$date.*
    find $localdir -type f ! -name '*.gpg' -exec rm {} + 
fi

#Sync Backup
if [[ $* == *"--nosync"* ]]
then
    exit 0
else
   curl -T $localdir/$date.* -u $user:$password $protocol://$host:$port/$remotedir
fi
