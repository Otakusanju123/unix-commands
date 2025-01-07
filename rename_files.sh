#!/bin/bash

# Check for zenity
if ! command -v zenity &> /dev/null; then
    echo "Installing zenity..."
    sudo apt-get install -y zenity
fi

# Function to show error
show_error() {
    zenity --error \
           --width=300 \
           --title="Error" \
           --text="$1"
}

# Function to show success
show_success() {
    zenity --info \
           --width=300 \
           --title="Success" \
           --text="$1"
}

# Main function
main() {
    # Select directory
    local dir=$(zenity --file-selection \
                      --directory \
                      --title="Select the directory containing files")
    
    # Exit if no directory selected
    [[ -z "$dir" ]] && exit 1

    # Get number of patterns
    local num_patterns=$(zenity --scale \
                               --title="Number of patterns" \
                               --text="How many text patterns do you want to replace?" \
                               --min-value=1 \
                               --max-value=5 \
                               --value=1 \
                               --step=1)
    
    [[ -z "$num_patterns" ]] && exit 1

    # Arrays for patterns and replacements
    local patterns=()
    local replacements=()

    # Get patterns and replacements
    for ((i=1; i<=num_patterns; i++)); do
        local pattern=$(zenity --entry \
                              --title="Pattern $i" \
                              --text="Enter text to replace #$i:")
        
        [[ -z "$pattern" ]] && exit 1
        patterns+=("$pattern")

        local replacement=$(zenity --entry \
                                 --title="Replacement $i" \
                                 --text="Enter replacement text #$i (leave empty to remove):")
        replacements+=("$replacement")
    done

    # Confirm operation
    local files_count=$(find "$dir" -maxdepth 3 -type f | wc -l)
    zenity --question \
           --title="Confirm" \
           --text="This will scan $files_count files in directory:\n$dir\n\nContinue?" \
           --width=300

    [[ $? -ne 0 ]] && exit 1

    # Progress dialog
    (
        echo "0"
        local count=0
        find "$dir" -maxdepth 3 -type f | while read -r file; do
            dir=$(dirname "$file")
            filename=$(basename "$file")
            new_filename="$filename"
            
            for i in "${!patterns[@]}"; do
                new_filename="${new_filename/${patterns[$i]}/${replacements[$i]}}"
            done
            
            if [ "$filename" != "$new_filename" ]; then
                mv "$file" "$dir/$new_filename"
                echo "# Renaming: $filename"
            fi
            
            count=$((count + 1))
            echo $((count * 100 / files_count))
        done
        echo "100"
    ) | zenity --progress \
               --title="Renaming Files" \
               --text="Starting..." \
               --percentage=0 \
               --auto-close \
               --width=300

    show_success "Files have been renamed successfully!"
}

# Run main function
main
