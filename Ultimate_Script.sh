#!/bin/bash

# Enhanced Unified Media Utility Tool
# Combines functionality for file extraction, photo management,
# file renaming, and video processing

# Global Configuration
CONFIG_DIR="$HOME/.config/media-utility"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"
LOG_FILE="$CONFIG_DIR/operations.log"

# Dependencies
DEPENDENCIES=(
    "zenity" "notify-send" "ffmpeg" "mediainfo"
    "unrar" "unzip" "p7zip-full" "tar"
    "perl" "sed" "awk"
)

# Supported Formats
SUPPORTED_ARCHIVES=("*.rar" "*.zip" "*.7z" "*.tar.gz" "*.tar.xz" "*.tar.bz2")
SUPPORTED_IMAGES=("*.jpg" "*.jpeg" "*.png" "*.gif" "*.bmp" "*.tiff" "*.webp")
SUPPORTED_VIDEOS=("*.mp4" "*.mkv" "*.avi" "*.mov")

# Initialization Function
init_config() {
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE"

    if [ ! -f "$SETTINGS_FILE" ]; then
        cat > "$SETTINGS_FILE" << EOF
DELETE_ARCHIVES=false
SHOW_PROGRESS=true
CREATE_SUBFOLDER=false
BACKUP_ENABLED=true
EOF
    fi
    source "$SETTINGS_FILE"
}

# Check Dependencies
check_dependencies() {
    local missing=()
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        zenity --question --title="Dependencies Missing" \
            --text="Missing dependencies:\n${missing[*]}\nInstall now?" --width=400
        if [ $? -eq 0 ]; then
            sudo apt-get install -y "${missing[@]}"
        else
            zenity --error --text="Cannot continue without required dependencies."
            exit 1
        fi
    else
        zenity --info --text="All dependencies are already installed."
    fi
}

# Log Operations
log_operation() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Unified File Handling Function
handle_files() {
    local operation="$1"
    local source_dir="$2"
    local dest_dir="$3"
    local filter="$4"

    if [ ! -d "$source_dir" ]; then
        zenity --error --text="Source directory does not exist."
        return 1
    fi

    mkdir -p "$dest_dir"

    local files=("$(find "$source_dir" -type f -name "$filter")")
    local total_files=${#files[@]}

    if [ $total_files -eq 0 ]; then
        zenity --info --text="No files found to process."
        return 1
    fi

    (
    echo "0"; echo "# Initializing..."
    for i in "${!files[@]}"; do
        local file="${files[$i]}"
        local progress=$(( (i + 1) * 100 / total_files ))

        case "$operation" in
            move)
                mv "$file" "$dest_dir/" ;;
            copy)
                cp "$file" "$dest_dir/" ;;
        esac

        echo "$progress"
        echo "# Processing file $((i + 1)) of $total_files..."
    done
    echo "100"; echo "# Completed."
    ) | zenity --progress --title="File Handling" --percentage=0 --auto-close

    log_operation "$operation completed for $total_files files from $source_dir to $dest_dir"
}

# Archiving Functionality
archive_files() {
    local source_dir=$(zenity --file-selection --directory --title="Select Directory to Archive")
    local archive_name=$(zenity --entry --title="Archive Name" --text="Enter the name for the archive (without extension):")
    local archive_format=$(zenity --list --radiolist --title="Select Archive Format" \
        --column="Select" --column="Format" TRUE "zip" FALSE "tar.gz" FALSE "tar.bz2" FALSE "7z" --width=400 --height=300)

    if [ -z "$source_dir" ] || [ -z "$archive_name" ] || [ -z "$archive_format" ]; then
        zenity --error --text="All inputs are required to create an archive."
        return 1
    fi

    local dest_file="$source_dir/../$archive_name.$archive_format"

    case "$archive_format" in
        zip)
            zip -r "$dest_file" "$source_dir" ;;
        tar.gz)
            tar -czvf "$dest_file" -C "$source_dir" . ;;
        tar.bz2)
            tar -cjvf "$dest_file" -C "$source_dir" . ;;
        7z)
            7z a "$dest_file" "$source_dir" ;;
    esac

    zenity --info --title="Archive Created" --text="Archive saved at: $dest_file"
    log_operation "Archived $source_dir to $dest_file"
}

# Renaming Functionality
rename_files() {
    local source_dir=$(zenity --file-selection --directory --title="Select Directory for Renaming")
    local prefix=$(zenity --entry --title="File Rename" --text="Enter the prefix for renamed files:")

    if [ -z "$source_dir" ] || [ -z "$prefix" ]; then
        zenity --error --text="Both source directory and prefix are required."
        return 1
    fi

    local counter=1
    for file in "$source_dir"/*; do
        if [ -f "$file" ]; then
            local ext="${file##*.}"
            mv "$file" "$source_dir/$prefix_$counter.$ext"
            log_operation "Renamed $file to $prefix_$counter.$ext"
            ((counter++))
        fi
    done

    zenity --info --title="Renaming Completed" --text="Renamed files with prefix '$prefix' in $source_dir."
}

# Video Processing Functionality
process_videos() {
    local source_dir=$(zenity --file-selection --directory --title="Select Directory for Video Processing")
    local dest_dir=$(zenity --file-selection --directory --title="Select Destination Directory")

    if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then
        zenity --error --text="Both source and destination directories are required."
        return 1
    fi

    mkdir -p "$dest_dir"

    local files=("$(find "$source_dir" -type f -name "*.mp4")")
    local total_files=${#files[@]}

    if [ $total_files -eq 0 ]; then
        zenity --info --text="No video files found to process."
        return 1
    fi

    (
    echo "0"; echo "# Initializing video processing..."
    for i in "${!files[@]}"; do
        local file="${files[$i]}"
        local progress=$(( (i + 1) * 100 / total_files ))
        ffmpeg -i "$file" -vf "scale=1280:720" "$dest_dir/$(basename "$file")" &>/dev/null
        echo "$progress"
        echo "# Processing video $((i + 1)) of $total_files..."
    done
    echo "100"; echo "# Video processing completed."
    ) | zenity --progress --title="Video Processing" --percentage=0 --auto-close

    log_operation "Processed $total_files videos from $source_dir to $dest_dir"
}

# Main Menu
main_menu() {
    while true; do
        local choice=$(zenity --list --title="Media Utility Tool" \
            --text="Select an operation:" \
            --column="Operation" --column="Description" \
            "Extract Archives" "Extract compressed files" \
            "Manage Photos" "Organize and move photos" \
            "Rename Files" "Batch rename files" \
            "Process Videos" "Compress or add subtitles" \
            "Create Archives" "Archive files and folders" \
            "Exit" "Exit application" \
            --width=600 --height=400)

        case "$choice" in
            "Extract Archives")
                local archive=$(zenity --file-selection --title="Select Archive")
                [ -n "$archive" ] && extract_archive "$archive" ;;
            "Manage Photos")
                local source=$(zenity --file-selection --directory --title="Select Source Directory")
                local dest=$(zenity --file-selection --directory --title="Select Destination Directory")
                [ -n "$source" ] && [ -n "$dest" ] && handle_files "move" "$source" "$dest" "*.jpg" ;;
            "Rename Files")
                rename_files ;;
            "Process Videos")
                process_videos ;;
            "Create Archives")
                archive_files ;;
            "Exit")
                exit 0 ;;
        esac
    done
}

# Main Execution
init_config
check_dependencies
main_menu

