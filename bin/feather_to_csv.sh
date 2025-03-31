#!/bin/bash

# Check if a feather file argument was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <feather_file>"
    echo "Example: $0 unrivaled_play_by_play.feather"
    exit 1
fi

# Get the input feather file path
feather_file="$1"

# Check if the file exists
if [ ! -f "$feather_file" ]; then
    echo "Error: File '$feather_file' not found"
    exit 1
fi

# Create output CSV filename by replacing .feather with .csv
csv_file="${feather_file%.feather}.csv"

# Convert feather to CSV using R
Rscript -e "
library(tidyverse)
library(feather)
read_feather('$feather_file') |>
  write_csv('$csv_file')
"

# Check if the conversion was successful
if [ $? -eq 0 ]; then
    echo "Successfully converted $feather_file to $csv_file"
else
    echo "Error converting file"
    exit 1
fi 