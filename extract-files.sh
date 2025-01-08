#!/bin/bash

# Set custom GTK theme settings for better appearance
export GTK_THEME="Mint-Y-Dark"
export WINDOWID=$(xwininfo -root | grep 'Window id' | awk '{print $4}')

# Custom styling
ZENITY_COMMON="--width=500 --height=150 --window-icon=/usr/share/icons/Mint-Y/apps/48/utilities-file-archiver.png"
ZENITY_TITLE_PREFIX="🎬 RAR Extractor"

# Function to show styled error message
show_error() {
    zenity --error \
        $ZENITY_COMMON \
        --title="$ZENITY_TITLE_PREFIX - Error" \
        --text="<span color='red' weight='bold'>Error</span>\n<span size='medium'>$1</span>"
}

# Function to show styled success message
show_success() {
    zenity --info \
        $ZENITY_COMMON \
        --title="$ZENITY_TITLE_PREFIX - Success" \
        --text="<span color='green' weight='bold'>Success!</span>\n<span size='medium'>$1</span>"
}

# Check for required programs
if ! command -v unrar &> /dev/null; then
    show_error "📦 unrar is not installed.\n\nPlease install it using:\nsudo apt-get install unrar"
    exit 1
fi

# Show welcome message with custom styling
zenity --info \
    $ZENITY_COMMON \
    --title="$ZENITY_TITLE_PREFIX" \
    --text="<span size='x-large' weight='bold'>Welcome to RAR Extractor!</span>\n\n<span size='large'>This tool will help you extract split RAR files with ease.\nJust select your .rar or .r00 file to begin.</span>\n\n<i>Created for Linux Mint</i>" \
    --ok-label=" Let's Start! "

# File selection dialog with custom styling
FILE=$(zenity --file-selection \
    --title="$ZENITY_TITLE_PREFIX - Select RAR File" \
    --file-filter="RAR archives | *.rar *.r00" \
    --file-filter="All files | *.*" \
    $ZENITY_COMMON)

if [ -z "$FILE" ]; then
    show_error "No file selected. The operation has been cancelled."
    exit 1
fi

# Get the directory
DIR=$(dirname "$FILE")

# Custom progress dialog
(
    echo "0"
    echo "# 🔍 Analyzing RAR archive..."
    sleep 1
    
    # Extract the RAR file with progress monitoring
    unrar x -o+ "$FILE" "$DIR" 2>&1 | while read -r line; do
        # Enhanced progress messages
        if [[ $line =~ ^Extracting ]]; then
            filename=$(echo "$line" | sed 's/Extracting  //' | sed 's/OK//')
            echo "# 📂 Extracting: $filename"
        elif [[ $line =~ ^All\ OK ]]; then
            echo "# ✅ Extraction completed successfully!"
        elif [[ $line =~ ([0-9]+)% ]]; then
            echo "${BASH_REMATCH[1]}"
            echo "# 📊 Progress: ${BASH_REMATCH[1]}%"
        fi
    done
    
    # Cleanup prompt with enhanced styling
    if zenity --question \
        $ZENITY_COMMON \
        --title="$ZENITY_TITLE_PREFIX - Cleanup" \
        --text="<span size='x-large' weight='bold'>Extraction Complete! 🎉</span>\n\n<span size='large'>Would you like to remove the RAR files to save space?</span>\n\n<i>This action cannot be undone.</i>" \
        --ok-label=" Yes, Clean Up " \
        --cancel-label=" No, Keep Files "; then
        
        rm "$DIR"/*.r[0-9][0-9] "$DIR"/*.rar 2>/dev/null
        echo "100"
        echo "# 🧹 Cleanup completed! Your files are ready."
    else
        echo "100"
        echo "# ✨ All done! RAR files have been preserved."
    fi
    
) | zenity --progress \
    $ZENITY_COMMON \
    --title="$ZENITY_TITLE_PREFIX - Extracting" \
    --text="Starting extraction..." \
    --percentage=0 \
    --auto-close \
    --auto-kill \
    --cancel-label=" Cancel Operation "

if [ $? -eq 0 ]; then
    # Success dialog with open folder option
    if zenity --question \
        $ZENITY_COMMON \
        --title="$ZENITY_TITLE_PREFIX - Complete" \
        --text="<span size='x-large' weight='bold'>✅ Extraction Successful!</span>\n\n<span size='large'>Your files have been extracted to:\n<span weight='bold'>$DIR</span>\n\nWould you like to open this folder now?</span>" \
        --ok-label=" Open Folder " \
        --cancel-label=" Close "; then
        xdg-open "$DIR" &
    fi
else
    show_error "❌ An error occurred during extraction.\nPlease check if you have enough disk space and permissions."
fi
