#!/bin/bash

# Display the schema of all feather files in the current directory and fixtures subdirectory.
# If a specific file is provided as an argument, only show its schema.
# Suppress all messages from R, including warnings and errors.

# Function to print schema for a single file
print_schema_for_file() {
    local feather_file=$1
    
    if [ ! -f "$feather_file" ]; then
        echo "File not found: $feather_file"
        return 1
    fi
    
    if [[ ! "$feather_file" =~ \.feather$ ]]; then
        echo "Not a feather file: $feather_file"
        return 1
    fi
    
    echo "=== Schema for $(basename "$feather_file") ==="
    Rscript -e "
    suppressMessages({
        library(tidyverse)
        library(feather)
    })
    data <- read_feather('$feather_file')
    cat('Columns:\n')
    for(col in names(data)) {
        cat(sprintf('  %s: %s\n', col, class(data[[col]])[1]))
    }
    cat('\n')
    " 2>/dev/null
    echo "----------------------------------------"
}

# Function to print schema for a directory
print_schema_for_dir() {
    local dir=$1
    local dir_name=$2
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Directory $dir_name does not exist"
        return
    fi
    
    # Check if any feather files exist in the directory
    if ! ls "$dir"/*.feather 1> /dev/null 2>&1; then
        echo "No feather files found in $dir_name directory"
        return
    fi
    
    echo "=== Feather files in $dir_name directory ==="
    
    # Print schema for each feather file
    for feather_file in "$dir"/*.feather; do
        print_schema_for_file "$feather_file"
    done
}

# If a specific file is provided, only show its schema
if [ $# -eq 1 ]; then
    print_schema_for_file "$1"
    exit $?
fi

# Otherwise, print schema for current directory and fixtures
# Print schema for current directory
echo "=== Feather files in current directory ==="
# Check if any feather files exist
if ! ls ./*.feather 1> /dev/null 2>&1; then
    echo "No feather files found in current directory"
else
    # Print schema for each feather file
    for feather_file in ./*.feather; do
        print_schema_for_file "$feather_file"
    done
fi

# Print schema for fixtures directory
print_schema_for_dir "fixtures" "fixtures" 