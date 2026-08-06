#!/bin/bash

set -euo pipefail

test_dir=$(cd "$(dirname "$0")"; pwd -P)
modifier="$test_dir/../modify_target.sh"
fixtures="$test_dir/fixtures"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/webview-cef-target-modifier.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_once() {
  local expected="$1"
  local file="$2"
  local count
  count=$(grep -F -c "$expected" "$file" || true)
  [ "$count" -eq 1 ] || fail "Expected exactly one '$expected' in $file, found $count"
}

run_case() {
  local name="$1"
  local relative_runner_dir="$2"
  local project="$scratch/$name project"
  local runner_dir="$project/linux"

  if [ -n "$relative_runner_dir" ]; then
    runner_dir="$runner_dir/$relative_runner_dir"
  fi

  mkdir -p "$runner_dir" "$project/build/linux/x64/debug"
  cp "$fixtures/main.cc" "$runner_dir/main.cc"
  cp "$fixtures/my_application.cc" "$runner_dir/my_application.cc"

  (
    cd "$project/build/linux/x64/debug"
    bash "$modifier"
    bash "$modifier"
  )

  assert_once '#include <webview_cef/webview_cef_plugin.h>' "$runner_dir/main.cc"
  assert_once 'int exit_code = initCEFProcesses(argc, argv);' "$runner_dir/main.cc"
  if grep -Fq '  initCEFProcesses(argc, argv);' "$runner_dir/main.cc"; then
    fail "Legacy initCEFProcesses call remains in $runner_dir/main.cc"
  fi
  assert_once '#include <webview_cef/webview_cef_plugin.h>' "$runner_dir/my_application.cc"
  assert_once 'g_signal_connect(view, "key_press_event", G_CALLBACK(processKeyEventForCEF), nullptr);' "$runner_dir/my_application.cc"
  assert_once 'g_signal_connect(view, "key_release_event", G_CALLBACK(processKeyEventForCEF), nullptr);' "$runner_dir/my_application.cc"
}

run_case legacy ""
run_case current runner

missing_project="$scratch/missing project"
mkdir -p "$missing_project/build/linux/x64/debug"
if (
  cd "$missing_project/build/linux/x64/debug"
  bash "$modifier"
) >"$scratch/missing-output.txt" 2>&1; then
  fail "Modifier succeeded without Flutter Linux runner sources"
fi
grep -Fq 'Could not locate Flutter Linux runner sources.' "$scratch/missing-output.txt" || \
  fail "Missing runner failure did not explain what was wrong"

unsupported_project="$scratch/unsupported project"
mkdir -p "$unsupported_project/linux/runner" "$unsupported_project/build/linux/x64/debug"
cp "$fixtures/main.cc" "$unsupported_project/linux/runner/main.cc"
printf '%s\n' '#include "my_application.h"' >"$unsupported_project/linux/runner/my_application.cc"
if (
  cd "$unsupported_project/build/linux/x64/debug"
  bash "$modifier"
) >"$scratch/unsupported-output.txt" 2>&1; then
  fail "Modifier succeeded for an unsupported Flutter runner source shape"
fi
grep -Fq 'Could not find' "$scratch/unsupported-output.txt" || \
  fail "Unsupported runner failure did not explain what was wrong"

echo "All Linux target modifier tests passed."
