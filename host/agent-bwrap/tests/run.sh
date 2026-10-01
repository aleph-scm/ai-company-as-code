#!/usr/bin/env bash
# Test suite for bin/agent-bwrap. Each test corresponds to a specific claim
# made in README.md; see the comment above each test function.
#
# Requires: bwrap installed and able to create user namespaces as the running
# user (true on most non-Ubuntu-desktop-derived hosts and on GitHub Actions'
# ubuntu-latest runner without any extra setup — see README.md's Host
# prerequisites section for hosts that need an AppArmor profile instead).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$HERE/../bin/agent-bwrap"

pass_count=0
fail_count=0

pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

fresh_workspace() {
  mktemp -d "${TMPDIR:-/tmp}/agent-bwrap-test-workspace.XXXXXX"
}

# --- (a) a write outside the configured mounts returns 0 and leaves nothing
#         behind. /tmp inside the sandbox is a fresh, unbound tmpfs (it exists
#         as a mount point but is not the host's /tmp), so this also proves
#         the sandbox root really is isolated rather than merely read-only.
test_write_outside_is_discarded() {
  local workspace marker
  workspace="$(fresh_workspace)"
  marker="/tmp/agent-bwrap-test-marker-$$-$RANDOM"

  AGENT_BWRAP_CMD=/bin/bash \
  AGENT_BWRAP_WORKSPACE="$workspace" \
    "$WRAPPER" -c "echo outside-write > '$marker'"
  local status=$?

  rm -rf "$workspace"

  if [ "$status" -ne 0 ]; then
    fail "write outside mounts: expected exit 0, got $status"
    return
  fi
  if [ -e "$marker" ]; then
    rm -f "$marker"
    fail "write outside mounts: file leaked onto the host at $marker"
    return
  fi
  pass "write outside mounts returns 0 and leaves nothing behind"
}

# --- (b) a path outside the sandbox boundary reads as "No such file or
#         directory", even though it exists and is readable on the host.
test_read_outside_boundary_fails() {
  local workspace outside_dir outside_file output status
  workspace="$(fresh_workspace)"
  outside_dir="$(mktemp -d "${TMPDIR:-/tmp}/agent-bwrap-test-outside.XXXXXX")"
  outside_file="$outside_dir/secret.txt"
  echo "should not be visible in the sandbox" >"$outside_file"

  output="$(AGENT_BWRAP_CMD=/bin/bash \
    AGENT_BWRAP_WORKSPACE="$workspace" \
    "$WRAPPER" -c "cat '$outside_file'" 2>&1)"
  status=$?

  rm -rf "$workspace" "$outside_dir"

  if [ "$status" -eq 0 ]; then
    fail "read outside boundary: expected non-zero exit, got 0 (output: $output)"
    return
  fi
  if ! grep -qi "no such file or directory" <<<"$output"; then
    fail "read outside boundary: expected 'No such file or directory', got: $output"
    return
  fi
  pass "path outside the boundary reads as 'No such file or directory'"
}

# --- (c) a path listed in AGENT_BWRAP_RO is readable inside the sandbox but
#         not writable — the read-only bind actually enforces read-only.
test_ro_bind_is_read_only() {
  local workspace cred_dir cred_file read_output status_read status_write
  workspace="$(fresh_workspace)"
  cred_dir="$(mktemp -d "${TMPDIR:-/tmp}/agent-bwrap-test-creds.XXXXXX")"
  cred_file="$cred_dir/gitconfig"
  echo "[user]
	name = test" >"$cred_file"

  read_output="$(AGENT_BWRAP_CMD=/bin/bash \
    AGENT_BWRAP_WORKSPACE="$workspace" \
    AGENT_BWRAP_RO="$cred_file" \
    "$WRAPPER" -c "cat '$cred_file'" 2>&1)"
  status_read=$?

  AGENT_BWRAP_CMD=/bin/bash \
  AGENT_BWRAP_WORKSPACE="$workspace" \
  AGENT_BWRAP_RO="$cred_file" \
    "$WRAPPER" -c "echo tampered >> '$cred_file'" >/dev/null 2>&1
  status_write=$?

  local host_content
  host_content="$(cat "$cred_file")"
  rm -rf "$workspace" "$cred_dir"

  if [ "$status_read" -ne 0 ] || ! grep -q "name = test" <<<"$read_output"; then
    fail "RO bind: expected to read bound credential file, got exit $status_read: $read_output"
    return
  fi
  if [ "$status_write" -eq 0 ]; then
    fail "RO bind: write to bound credential file unexpectedly succeeded"
    return
  fi
  if grep -q "tampered" <<<"$host_content"; then
    fail "RO bind: host file was modified despite read-only bind"
    return
  fi
  pass "AGENT_BWRAP_RO path is readable but not writable inside the sandbox"
}

# --- (d) network access from inside the sandbox works (this tool does not
#         confine it).
test_network_is_unconfined() {
  local workspace status
  workspace="$(fresh_workspace)"

  AGENT_BWRAP_CMD=/bin/bash \
  AGENT_BWRAP_WORKSPACE="$workspace" \
    "$WRAPPER" -c 'exec 3<>/dev/tcp/github.com/443' >/dev/null 2>&1
  status=$?

  rm -rf "$workspace"

  if [ "$status" -ne 0 ]; then
    fail "network: expected TCP connect to github.com:443 to succeed inside sandbox, exit $status"
    return
  fi
  pass "network access from inside the sandbox works"
}

# --- (e) the wrapper refuses to start without its required configuration,
#         for both required variables, and does not fall back to running
#         unconfined.
test_refuses_without_required_config() {
  local workspace status output

  workspace="$(fresh_workspace)"
  output="$(AGENT_BWRAP_WORKSPACE="$workspace" "$WRAPPER" -c 'true' 2>&1)"
  status=$?
  rm -rf "$workspace"
  if [ "$status" -eq 0 ]; then
    fail "missing AGENT_BWRAP_CMD: expected non-zero exit, got 0"
    return
  fi
  if ! grep -q "AGENT_BWRAP_CMD" <<<"$output"; then
    fail "missing AGENT_BWRAP_CMD: expected error to name the missing variable, got: $output"
    return
  fi

  output="$(AGENT_BWRAP_CMD=/bin/bash "$WRAPPER" -c 'true' 2>&1)"
  status=$?
  if [ "$status" -eq 0 ]; then
    fail "missing AGENT_BWRAP_WORKSPACE: expected non-zero exit, got 0"
    return
  fi
  if ! grep -q "AGENT_BWRAP_WORKSPACE" <<<"$output"; then
    fail "missing AGENT_BWRAP_WORKSPACE: expected error to name the missing variable, got: $output"
    return
  fi

  pass "wrapper refuses to start without required configuration"
}

test_write_outside_is_discarded
test_read_outside_boundary_fails
test_ro_bind_is_read_only
test_network_is_unconfined
test_refuses_without_required_config

echo
echo "$pass_count passed, $fail_count failed"
[ "$fail_count" -eq 0 ]
