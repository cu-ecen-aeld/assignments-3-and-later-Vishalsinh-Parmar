#!/bin/bash

#check if both arguments are provided
if [ $# -ne 2 ]; then
	echo "Error: Two arguments are required."
	echo "Usage: $0 <directory> <search dtring>"
	exit 1;
fi

filesdir=$1
searchstr=$2

#check if input directory is valid
if [ ! -d "$filesdir" ]
then
	echo "$filedir is not valid directory"
	exit 1;
fi

#check if files directory is a directory and count them
files_count=$(find "$filesdir" -type f | wc -l)

#find all matching lines in files and count them
matching_lines_count=$(grep -r "$searchstr" "$filesdir" 2>/dev/null | wc -l)

#print the result
echo "The number of files are $files_count and the number of matching lines are $matching_lines_count"
