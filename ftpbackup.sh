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
softwarecheck=( "lftp" "tar" )
configcheck=( "host" "port" "user" "password" "localdir" "remotedir" "sources" "amount" )

if [[ $* == *"--gzip"* ]]; then
    softwarecheck=( ${softwarecheck[@]} "pigz" )
elif [[ $* == *"--bzip2"* ]]; then
    softwarecheck=( ${softwarecheck[@]} "pbzip2" )
fi

if [[ $* == *"--encrypt"* ]]; then
    softwarecheck=( ${softwarecheck[@]} "gpg2" "find" )
    configcheck=( ${configcheck[@]} "key")
fi

for software in ${softwarecheck[@]}; do
    if [ -z $(command -v $software) ]; then
        echo 2>&1 "$software is required, but it's not installed. Exiting."
        exit 1;
    fi
done

for option in ${configcheck[@]}; do
    if [ -z "$option" ]; then
        echo >&2 "$option is not configured. Exiting.";
        exit 1;
    fi
done

# Check directories
if [ ! -d $localdir ]; then
    echo >&2 "The local backup directory is not existent, creating $localdir"
    mkdir -p $localdir
fi

for directory in ${excludes[@]} do
    if [ ! -d $directory ]; then
        echo >&2 "$directory is not existing, but configured as an excluded directory. Exiting."
        exit 1
    fi
done

for directory in ${sources[@]}; do
    if [ ! -d $directory ]; then
        echo >2& "$directory is not existing, but configured as a source directory. Exiting."
        exit 1
    fi
done

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
