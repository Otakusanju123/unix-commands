#!/bin/bash

# Required packages
DEPENDENCIES=("unrar" "unzip" "p7zip-full" "tar" "zenity" "file" "pv" "notify-send")

# Themes and styling
export GTK_THEME="Mint-Y-Dark"
ZENITY_COMMON="--width=600 --height=200"
TITLE_PREFIX="📦 Super Extractor"
ICON_PATH="/usr/share/icons/Mint-Y/apps/48/utilities-file-archiver.png"

# Supported formats
SUPPORTED_FORMATS=(
    "*.rar" "*.r[0-9][0-9]"
    "*.zip" "*.7z" "*.tar.gz" "*.tgz"
    "*.tar.xz" "*.txz" "*.tar.bz2" "*.tbz2"
    "*.gz" "*.bz2" "*.xz" "*.Z"
)

# Theme colors
COLOR_PRIMARY="#4a90d9"
COLOR_SUCCESS="#73d216"
COLOR_ERROR="#cc0000"
COLOR_WARNING="#f57900"

show_styled_message() {
    local type="$1"
    local message="$2"
    local icon=""
    local color=""
    
    case "$type" in
        "error") icon="❌"; color="$COLOR_ERROR" ;;
        "success") icon="✅"; color="$COLOR_SUCCESS" ;;
        "warning") icon="⚠️"; color="$COLOR_WARNING" ;;
        "info") icon="ℹ️"; color="$COLOR_PRIMARY" ;;
    esac
    
    zenity --info \
        $ZENITY_COMMON \
        --title="$TITLE_PREFIX" \
        --text="<span size='x-large' weight='bold' color='$color'>$icon $message</span>" \
        --ok-label=" OK "
}

check_dependencies() {
    local missing=()
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        local install_cmd="sudo apt-get install -y ${missing[*]}"
        if zenity --question \
            $ZENITY_COMMON \
            --title="$TITLE_PREFIX - Dependencies" \
            --text="Missing required packages:\n\n${missing[*]}\n\nInstall them now?" \
            --ok-label=" Install " \
            --cancel-label=" Cancel "; then
            xterm -e "$install_cmd"
        else
            exit 1
        fi
    fi
}

detect_archive_type() {
    local file="$1"
    local mime_type=$(file --mime-type -b "$file")
    local ext="${file##*.}"
    
    case "$mime_type" in
        "application/x-rar"*) echo "rar" ;;
        "application/zip") echo "zip" ;;
        "application/x-7z-compressed") echo "7z" ;;
        "application/x-tar"*|"application/gzip") echo "tar" ;;
        *) echo "unknown" ;;
    esac
}

extract_archive() {
    local file="$1"
    local output_dir="$2"
    local type="$3"
    local total_size=$(stat -f %z "$file")
    
    case "$type" in
        "rar")
            unrar x -o+ "$file" "$output_dir" | \
                stdbuf -oL tr '\r' '\n' | \
                sed -u 's/\([0-9]\+\)%.*/\1/'
            ;;
        "zip")
            unzip -o "$file" -d "$output_dir" | \
                stdbuf -oL tr '\r' '\n' | \
                grep -o '[0-9]\+%' | tr -d '%'
            ;;
        "7z")
            7z x -o"$output_dir" "$file" | \
                grep -o '[0-9]\+%' | tr -d '%'
            ;;
        "tar")
            tar xf "$file" -C "$output_dir" --checkpoint=100 \
                --checkpoint-action=exec='echo $TAR_CHECKPOINT'
            ;;
        *)
            show_styled_message "error" "Unsupported archive type"
            return 1
            ;;
    esac
}

show_advanced_options() {
    local options=$(zenity --forms \
        $ZENITY_COMMON \
        --title="$TITLE_PREFIX - Advanced Options" \
        --text="Configure extraction options:" \
        --add-checkbox="Extract to separate folder" \
        --add-checkbox="Auto-detect password" \
        --add-checkbox="Remove archive after extraction" \
        --add-checkbox="Preserve file permissions" \
        --add-checkbox="Overwrite existing files" \
        --add-checkbox="Show detailed progress")
    echo "$options"
}

main() {
    check_dependencies
    
    # Welcome animation (requires notify-send)
    notify-send -i "$ICON_PATH" "$TITLE_PREFIX" "Welcome! Select your archive file to begin." 
    
    # File selection with preview
    local file=$(zenity --file-selection \
        --title="$TITLE_PREFIX - Select Archive" \
        --file-filter="Archives |${SUPPORTED_FORMATS[*]}" \
        $ZENITY_COMMON)
    
    [ -z "$file" ] && exit 1
    
    # Get archive info
    local archive_type=$(detect_archive_type "$file")
    local dir=$(dirname "$file")
    local options=$(show_advanced_options)
    
    # Create output directory
    local output_dir="$dir/extracted_$(basename "$file" | sed 's/\.[^.]*$//')"
    mkdir -p "$output_dir"
    
    # Extract with progress
    (
        echo "0"
        echo "# 🔍 Analyzing archive..."
        sleep 1
        
        extract_archive "$file" "$output_dir" "$archive_type" | while read -r progress; do
            echo "$progress"
            echo "# 📦 Extracting: $progress%"
        done
        
        echo "100"
        echo "# ✨ Extraction complete!"
    ) | zenity --progress \
        $ZENITY_COMMON \
        --title="$TITLE_PREFIX - Extracting" \
        --text="Starting extraction..." \
        --percentage=0 \
        --auto-close
    
    # Success notification
    if [ $? -eq 0 ]; then
        notify-send -i "$ICON_PATH" "$TITLE_PREFIX" "Extraction completed successfully! 🎉"
        if zenity --question \
            $ZENITY_COMMON \
            --title="$TITLE_PREFIX - Complete" \
            --text="<span size='large' weight='bold'>✅ Files extracted to:</span>\n$output_dir\n\nOpen the folder?" \
            --ok-label=" Open Folder " \
            --cancel-label=" Close "; then
            xdg-open "$output_dir"
        fi
    fi
}

main
