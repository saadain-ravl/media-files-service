#!/bin/bash

CONFIG_FILE="$HOME/vagrant_data/locations.cfg"
ENTANGLEMENT_LOG="$HOME/vagrant_data/entanglement.log"

# Check if the configuration file exists
if [ ! -f "${CONFIG_FILE/#\~/$HOME}" ]; then
    echo "Configuration file ${CONFIG_FILE} not found!"
    exit 1
fi

#Initialize entanglement log
> "${ENTANGLEMENT_LOG/#\~/#HOME}"

echo "Debug: entanglement_log is set to '$ENTANGLEMENT_LOG'"
# Function to display configured locations
display_locations() {
    echo "Configured Locations:"
    nl -w2 -s'. ' "${CONFIG_FILE/#\~/$HOME}"
}

# Function to hash files for entanglement detection
generate_file_hash() {
    local file=$1
    sha256sum "$file" 2>/dev/null | awk '{print $1}'
}

# Function to detect entangled files
detect_entanglement() {
    local src=$1
    local dest=$2
    echo "Checking for entangled files between $src and $dest..."
    
    local temp_src_hashes=$(mktemp)
    local temp_dest_hashes=$(mktemp)
    
    # Generate hashes for source and destination files
    find "$src" -type f -exec sha256sum {} \; > "$temp_src_hashes"
    find "$dest" -type f -exec sha256sum {} \; > "$temp_dest_hashes"
    
   echo "Debug: Source Hashes File ($temp_src_hashes):"
   cat "$temp_src_hashes"

   echo "Debug: Destination Hashes File ($temp_dest_hashes):"
   cat "$temp_dest_hashes"

    # Compare hashes to detect entanglement
    echo "Debug: Running comm to detect entangled files"
    entangled_hashes=$(comm -12 <(awk '{print $1}' "$temp_src_hashes" | sort) <(awk '{print $1}' "$temp_dest_hashes" | sort))
   
    echo "Debug: Entangled files detected and logged"
    if [ -n "$entangled_hashes" ]; then
        echo "Entanglement detected!"
        echo "$entangled_hashes" | while read -r hash; do
	    #find the files corresponding to this hash
	    src_file=$(grep "^$hash " "$temp_src_hashes" | awk '{$1=""; print $0}' | sed 's/^ //')
	    dest_file=$(grep "^$hash " "$temp_dest_hashes" | awk '{$1=""; print $0}' | sed 's/^ //')
            echo "$(date): File '$src_file' entangled with '$dest_file'" >> "${ENTANGLEMENT_LOG/#\~/$HOME}"
        done
    else
        echo "No entanglement detected."
    fi
    
    rm -f "$temp_src_hashes" "$temp_dest_hashes"
}

# Function to perform a backup
backup() {
    if [ -z "$LINE" ]; then
        echo "Starting backup for all locations..."
        while IFS= read -r line; do
            process_backup "$line"
        done < "${CONFIG_FILE/#\~/$HOME}"
    else
        echo "Starting backup for location line $LINE..."
        LOCATION=$(sed -n "${LINE}p" "${CONFIG_FILE/#\~/$HOME}")
        process_backup "$LOCATION"
    fi
}

# Function to process a single backup
process_backup() {
    IFS=' ' read -r src dest <<< "$1"
    echo "Backing up from $src to $dest..."
    rsync -avz --progress "$src" "$dest"
    if [ $? -ne 0 ]; then
        echo "Backup failed for $src to $dest."
    else
        echo "Backup completed successfully for $src to $dest."
	# call the entanglement detection
	detect_entanglement "$src" "$dest"
    fi
}

# Function to restore a backup (placeholder for implementation)
restore() {
    echo "Restore functionality is not implemented yet."
}

# Parse command-line arguments
LINE=""
while getopts ":BL:R:" opt; do
    case $opt in
        B) MODE="backup" ;;
        L) LINE="$OPTARG" ;;
        R) MODE="restore"; LINE="$OPTARG" ;;
        *) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Execute the selected mode
if [ "$MODE" = "backup" ]; then
    backup
elif [ "$MODE" = "restore" ]; then
    restore
else
    display_locations
fi
