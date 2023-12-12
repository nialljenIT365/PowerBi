# R script to process Azure VM pricing data

# SYNOPSIS
# This script processes the output of a PowerShell script which retrieves Azure VM pricing information. 
# It formats the PowerShell script's output into a structured, tabular format in R.

# DESCRIPTION
# The script performs the following steps:
# 1. Execute the PowerShell script and capture its output.
# 2. Parse and structure the PowerShell output into a clean, readable format.
# 3. Transform the data into a data frame for analysis and visualization in R.

# NOTES
# Version: 1.0
# Author: Niall Jennings
# Creation Date: 12/12/2023
# Dependencies: Requires the output from the specified PowerShell script.
# Usage: Modify the `powershell_script_path` variable to point to the PowerShell script location.

# Define the path to the PowerShell script
powershell_script_path <- "C:\\Workspace\\PowerBi\\Scripts\\Get-AzureVMPricingAPI.ps1"

# Execute the PowerShell script and capture the output
output <- system(paste("powershell -File", powershell_script_path), intern=TRUE)

# Combine all lines into one string, separated by a special token
combined_output <- paste(output, collapse = "|")

# Split the combined output at blank lines (indicated by ||)
entries <- unlist(strsplit(combined_output, "\\|\\|"))

# Function to process each entry
process_entry <- function(entry) {
    # Split the entry into lines
    lines <- unlist(strsplit(entry, "\\|"))

    # Initialize an empty data frame for this entry
    entry_df <- data.frame(Key = character(), Value = character(), stringsAsFactors = FALSE)

    # Extract key-value pairs using regular expression
    for (line in lines) {
        matches <- regmatches(line, regexec("([^:]+):\\s*(.*)", line))
        if (length(matches[[1]]) > 1) {
            entry_df <- rbind(entry_df, data.frame(Key = matches[[1]][2], Value = matches[[1]][3], stringsAsFactors = FALSE))
        }
    }

    return(entry_df)
}

# Process each entry and combine into a single data frame
processed_entries <- lapply(entries, process_entry)
combined_frame <- do.call(rbind, processed_entries)

# Reshape the data frame to wide format using base R
unique_keys <- unique(combined_frame$Key)
wide_frame <- setNames(data.frame(matrix(nrow = length(entries), ncol = length(unique_keys))), unique_keys)

row_index <- 1
for (entry in processed_entries) {
    for (key in unique_keys) {
        value <- ifelse(key %in% entry$Key, entry$Value[entry$Key == key], NA)
        wide_frame[row_index, key] <- value
    }
    row_index <- row_index + 1
}

wide_frame
