#!/bin/bash

# Config preamble
workdir=$(dirname $(realpath -s $0))
cd $workdir

if [ -e "$workdir/$(basename $0 .sh).conf" ]; then
    source $workdir/$(basename $0 .sh).conf
elif [ -e "$workdir/$(basename $0 .sh).conf.sample" ]; then
    echo "Please edit the sample config for your needs and move it to $(basename $0 .sh).conf"
else
    echo "No config file found. Please create one in $(basename $0 .sh).conf"
fi
    
# Check for software and variables
command -v lftp > /dev/null 2>&1 || { echo >&2 "lftp is required, but it's not installed. Aborting"; exit 1; }
command -v tar > /dev/null 2>&1 || { echo >&2 "tar is required, but it's not installed. Aborting"; exit 1; }

if [[ $* == *"--gzip"* ]]; then
    command -v pigz > /dev/null 2>&1 || { echo >&2 "pigz is required, but it's not installed. Aborting"; exit 1; }
elif [[ $* == *"--bzip2"* ]]; then
    command -v pbzip2 > /dev/null 2>&1 || { echo >&2 "pbzip2 is required, but it's not installed. Aborting"; exit 1; }
fi

if [[ $* == *"--encrypt"* ]]; then
    command -v gpg2 > /dev/null 2>&1 || { echo >&2 "gpg2 is required, but it's not installed. Aborting" exit 1; }
    command -v find > /dev/null 2>&1 || { echo >&2 "find is required, but it's not installed. Aborting" exit 1; }
    if [ -z "$key" ]; then echo "No email or key id configured."; exit 1; fi
fi

if [ -z "$host" ]; then echo "The host is not configured."; exit 1; fi
if [ -z "$port" ]; then echo "The port is not configured."; exit 1; fi
if [ -z "$user" ]; then echo "The user is not configured."; exit 1; fi
if [ -z "$password" ]; then echo "The password is not configured."; exit 1; fi
if [ -z "$localdir" ]; then echo "The local directory is not configured."; exit 1; fi
if [ -z "$remotedir" ]; then echo "The remote directory is not configured."; exit 1; fi
if [ ${#sources[@]} -eq 0 ]; then echo "The backup source(s) is/are not configured."; exit 1; fi

# Create target directory
date=$( date +%Y%m%d-%H%M%S )
mkdir -p $localdir

# Write backup information text file
info_file="info.txt"
cd $localdir

cat > "$info_file" <<EOF
Timestamp: $(date "+%Y-%m-%d %H-%M-%S")
Parameters: $*
Sources: ${sources[@]}
Excludes: ${excludes[@]}
Local directory: $localdir
EOF

if ! [[ $* == *"--nosync"* ]]; then
cat >> $info_file <<EOF
Remote directory: $remotedir
Host: $host
Port: $port
User: $user
EOF
fi

# Build tar arguments
tar_args="$info_file"

# Append all source paths
for i in "${sources[@]}"; do
    tar_args="$tar_args $i"
done

# Append all exclude arguments
for i in "${excludes[@]}"; do
    tar_args="$tar_args --exclude=$i"
done

if [[ $* == *"--totals"* ]]; then
    tar_args="$tar_args --totals"
fi

# Compression and encryption
if [[ $* == *"--gzip"* ]]; then
    target_file=$localdir/$date.tar.gz
    echo "Creating gzip-compressed backup at $target_file"
    tar -cf - $tar_args | pigz -c > $target_file
elif [[ $* == *"--bzip2"* ]]; then
    target_file=$localdir/$date.tar.bz2
    echo "Creating bzip2-compressed backup at $target_file"
    tar -cf - $tar_args | pbzip2 -c > $target_file
else
    target_file=$target_dir/$date.tar
    echo "Creating backup at $target_file"
    tar -cf $target_file $tar_args
fi

rm $info_file
cd $workdir

if [[ $* == *"--encrypt"* ]]; then
    gpg2 --encrypt --recipient $key $localdir/$date.*
    find $localdir -type f ! -name $date'.*.gpg' -name $date'.*' -exec rm {} + 
fi

# Sync backup
if [[ $* == *"--nosync"* ]]; then
    exit 0
else
    lftp <<EOF
        $connoption
        open $host $port
        user $user $password
        mirror -Rp $localdir $remotedir
        bye
EOF
fi
