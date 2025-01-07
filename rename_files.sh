#!/bin/bash

# Install yad if not present
if ! command -v yad &> /dev/null; then
    sudo apt-get install yad
fi

# Initialize empty arrays for patterns
patterns=()
replacements=()

# Function to create form
create_form() {
    local form_items=(
        --field="Folder:DIR" ""
    )
    
    # Add pattern/replacement pairs
    for ((i=0; i<${#patterns[@]}; i++)); do
        form_items+=(
            --field="Text to replace $((i+1)):TEXT" "${patterns[i]}"
            --field="Replace with $((i+1)):TEXT" "${replacements[i]}"
        )
    done
    
    # Get form data
    result=$(yad --title="File Renamer" \
        --form \
        --button="Add Pattern:2" \
        --button="Remove Pattern:3" \
        --button="Rename:0" \
        --button="Cancel:1" \
        "${form_items[@]}")
    
    return_code=$?
    
    case $return_code in
        0) # Rename
            IFS='|' read -ra values <<< "$result"
            folder="${values[0]}"
            
            # Clear arrays
            patterns=()
            replacements=()
            
            # Parse form data
            for ((i=1; i<${#values[@]}; i+=2)); do
                if [ -n "${values[i]}" ]; then
                    patterns+=("${values[i]}")
                    replacements+=("${values[i+1]}")
                fi
            done
            
            # Perform renaming
            find "$folder" -maxdepth 3 -type f | while read -r file; do
                dir=$(dirname "$file")
                filename=$(basename "$file")
                new_filename="$filename"
                
                for i in "${!patterns[@]}"; do
                    new_filename="${new_filename/${patterns[i]}/${replacements[i]}}"
                done
                
                if [ "$filename" != "$new_filename" ]; then
                    mv "$file" "$dir/$new_filename"
                fi
            done
            
            yad --info --text="Renaming complete!"
            create_form
            ;;
        2) # Add pattern
            patterns+=("")
            replacements+=("")
            create_form
            ;;
        3) # Remove pattern
            if [ ${#patterns[@]} -gt 0 ]; then
                unset 'patterns[${#patterns[@]}-1]'
                unset 'replacements[${#patterns[@]}-1]'
                patterns=("${patterns[@]}")
                replacements=("${replacements[@]}")
            fi
            create_form
            ;;
        *) # Cancel
            exit 0
            ;;
    esac
}

# Start with one pattern
patterns=("")
replacements=("")
create_form


# Make it executable
chmod +x rename_files.sh

# Check if script is recognized as a shell script
file rename_files.sh

# Run with bash explicitly
bash rename_files.sh
