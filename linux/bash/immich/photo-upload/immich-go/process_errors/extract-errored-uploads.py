"""Process an immich-go log file to find failed uploads.

Description:
    Immich-go outputs a log file that contains a record of all of the files uploaded to Immich.
    The file includes all of the files that failed to upload.
    
    This script iterates over lines in the log file and extracts the filename of files that failed to upload,
    then outputs them to a text file.
    
    You can move those files to another directory and re-run immich-go to attempt to upload them again.
    
Usage:
    ./extract-errored-uploads.py <log_file>
"""

import re
import sys
from pathlib import Path

## Check for input argument
if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <log_file>")
    sys.exit(1)

input_path = Path(sys.argv[1])

if not input_path.is_file():
    print(f"Error: File '{input_path}' does not exist.")
    sys.exit(1)

output_path = Path("upload-error-filenames.txt")

## Regex pattern:
#  - Line must contain 'ERR' after timestamp
#  - Followed by any text
#  - Then 'file=Google Photos:Photos from ' and capture the filename
pattern = re.compile(r"ERR.*file=Google Photos:Photos from (\S+)")

with input_path.open("r") as f_in, output_path.open("w") as f_out:
    count = 0
    for line in f_in:
        match = pattern.search(line)
        if match:
            f_out.write(match.group(1) + "\n")
            count += 1

print(f"Done! Extracted {count} filenames to '{output_path}'.")
