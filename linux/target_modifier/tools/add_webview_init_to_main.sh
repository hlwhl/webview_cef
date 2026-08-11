#!/bin/bash

set -euo pipefail

# Adds
# initCEFProcesses(argc, argv);
# to main function of main.cc

# Check if the correct number of arguments is passed
if [ $# -ne 1 ]; then
  echo "Usage: $0 <file-path>"
  exit 1
fi

# Assign file path argument
file="$1"

# Check if the file exists
if [ ! -f "$file" ]; then
  echo "File not found: $file"
  exit 1
fi

# Check if the line initCEFProcesses(argc, argv); already exists in the file
if grep -q '^[[:space:]]*int exit_code = initCEFProcesses(argc, argv);' "$file"; then
  echo "The line 'int exit_code = initCEFProcesses(argc, argv);' already exists in the file."
else
  # Replace the old fire-and-forget call, then insert the exit-code-aware call
  # before the first line starting with g_autoptr(.
  awk '
    /^[[:space:]]*initCEFProcesses\(argc, argv\);/ {
      next;
    }
    !inserted && /^[[:space:]]*g_autoptr/ {
      print "  int exit_code = initCEFProcesses(argc, argv);";
      print "  if (exit_code >= 0) {";
      print "    return exit_code;";
      print "  }";
      inserted = 1;
    }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

  if ! grep -q '^[[:space:]]*int exit_code = initCEFProcesses(argc, argv);' "$file"; then
    echo "Could not find the first 'g_autoptr(' line in $file" >&2
    exit 1
  fi

  echo "Added 'int exit_code = initCEFProcesses(argc, argv);' before the first line starting with 'g_autoptr('."
fi
