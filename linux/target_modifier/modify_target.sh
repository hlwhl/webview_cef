#!/bin/bash

set -euo pipefail

# Will be something like /home/test/flutter_projects/example
program_path="${PWD%%/build/linux/*}"

# Will be the path of this script
scriptdir=$(cd "$(dirname "$0")"; pwd -P)

linux_dir="$program_path/linux"
if [ -f "$linux_dir/runner/main.cc" ] && [ -f "$linux_dir/runner/my_application.cc" ]; then
  runner_dir="$linux_dir/runner"
elif [ -f "$linux_dir/main.cc" ] && [ -f "$linux_dir/my_application.cc" ]; then
  runner_dir="$linux_dir"
else
  echo "Could not locate Flutter Linux runner sources." >&2
  echo "Checked:" >&2
  echo "  $linux_dir/runner/main.cc" >&2
  echo "  $linux_dir/runner/my_application.cc" >&2
  echo "  $linux_dir/main.cc" >&2
  echo "  $linux_dir/my_application.cc" >&2
  exit 1
fi

main_file="$runner_dir/main.cc"
application_file="$runner_dir/my_application.cc"

echo "Modifying target cc files..."
echo "Using Flutter runner sources in $runner_dir"

bash "$scriptdir/tools/import_webview_cef_header_my_application.sh" "$application_file"
bash "$scriptdir/tools/add_key_release_event_to_my_application.sh" "$application_file"
bash "$scriptdir/tools/add_key_press_event_to_my_application.sh" "$application_file"

bash "$scriptdir/tools/import_webview_cef_header_main.sh" "$main_file"
bash "$scriptdir/tools/add_webview_init_to_main.sh" "$main_file"
