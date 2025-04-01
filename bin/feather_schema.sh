#!/bin/bash

# Check if any feather files exist
if ! ls *.feather 1> /dev/null 2>&1; then
    echo "No feather files found in current directory"
    exit 1
fi

# Print schema for each feather file
for feather_file in *.feather; do
    echo "=== Schema for $feather_file ==="
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
done 