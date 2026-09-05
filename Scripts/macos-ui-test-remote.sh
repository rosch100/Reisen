#!/usr/bin/env bash
# Remote macOS XCUI-Smokes: Working-Tree-rsync + macos-ui-test.sh auf dem iMac.
# Spec: docs/superpowers/specs/2026-09-02-macos-ui-test-remote-design.md
# Selection lokal (Diff/--full/Skip); Remote nur Passthrough — siehe
# docs/superpowers/specs/2026-09-04-macos-ui-diff-select-design.md
# bash 3.2 + set -u: keine Associative Arrays; leere "${arr[@]}" vermeiden.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REMOTE_MODE=diff
REMOTE_TEST_ARGS=()

REISEN_UI_REMOTE_PRIMARY_HOST="imac.altanis.de"
REISEN_UI_REMOTE_USER_DEFAULT="roschmac"
REISEN_UI_REMOTE_DIR_DEFAULT="~/Entwicklung/Reisen-ui-runs"
REISEN_UI_REMOTE_LOCK_DIR="/tmp/reisen-macos-ui-run.lock"
REISEN_UI_REMOTE_LOCK_STALE_SEC=2700
REISEN_UI_REMOTE_LOCK_WAIT_MAX=360

reisen_ui_remote_user() {
  printf '%s\n' "${REISEN_UI_REMOTE_USER:-$REISEN_UI_REMOTE_USER_DEFAULT}"
}

reisen_ui_remote_strict_host_key() {
  # Default yes (known_hosts Pflicht). Erstkontakt: REISEN_UI_REMOTE_STRICT_HOST_KEY=accept-new
  printf '%s\n' "${REISEN_UI_REMOTE_STRICT_HOST_KEY:-yes}"
}

reisen_ui_remote_ssh_base_opts() {
  printf '%s\n' \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=120 \
    -o "StrictHostKeyChecking=$(reisen_ui_remote_strict_host_key)"
}

reisen_ui_remote_target() {
  local host="$1"
  printf '%s@%s\n' "$(reisen_ui_remote_user)" "$host"
}

reisen_ui_remote_ssh() {
  # Führt ein Remote-Bash-Skript aus (String). Kein argv mit -c an ssh —
  # lokales OpenSSH würde -c sonst als Cipher-Option lesen.
  local host="$1"
  local script="$2"
  local -a opts
  while IFS= read -r line; do
    opts+=("$line")
  done < <(reisen_ui_remote_ssh_base_opts)
  ssh "${opts[@]}" -- "$(reisen_ui_remote_target "$host")" \
    "exec /bin/bash --noprofile --norc -c $(printf '%q' "$script")"
}

reisen_ui_remote_ssh_stdin() {
  # Remote bash -s mit lokalem Heredoc auf stdin.
  local host="$1"
  local -a opts
  while IFS= read -r line; do
    opts+=("$line")
  done < <(reisen_ui_remote_ssh_base_opts)
  ssh "${opts[@]}" -- "$(reisen_ui_remote_target "$host")" \
    "exec /bin/bash --noprofile --norc -s"
}

reisen_ui_remote_ssh_ok() {
  local host="$1"
  reisen_ui_remote_ssh "$host" 'true' >/dev/null 2>&1
}

reisen_ui_remote_identity() {
  local host="$1"
  reisen_ui_remote_ssh "$host" 'hostname' | tr '[:upper:]' '[:lower:]' | tr -d '\r'
}

# RTT in ms (integer); bei Fehler 999999.
reisen_ui_remote_rtt_ms() {
  local host="$1"
  local out ms
  out="$(ping -c 1 -W 1000 "$host" 2>/dev/null || true)"
  ms="$(printf '%s\n' "$out" | sed -n 's/.*time=\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1)"
  if [[ -z "$ms" ]]; then
    ms="$(printf '%s\n' "$out" | sed -n 's/.*time=\([0-9][0-9]*\).*/\1/p' | head -1)"
  fi
  if [[ -z "$ms" ]]; then
    printf '999999\n'
    return 0
  fi
  # bash 3.2: nur Ganzzahl; Nachkomma abschneiden
  printf '%s\n' "${ms%%.*}"
}

reisen_ui_remote_name_rank() {
  # niedriger = besser Tie-Break (imac.local vor imac-N.local)
  local host="$1"
  local base
  base="$(printf '%s\n' "$host" | tr '[:upper:]' '[:lower:]')"
  case "$base" in
    imac.local) printf '0\n' ;;
    imac-*.local) printf '1\n' ;;
    *) printf '2\n' ;;
  esac
}

reisen_ui_remote_is_imac_bonjour_name() {
  local name="$1"
  local lower
  lower="$(printf '%s\n' "$name" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" =~ ^imac(-[a-z0-9]+)?$ ]]
}

reisen_ui_remote_bonjour_candidates() {
  local tmp pid line name lower
  tmp="$(mktemp -t reisen-ui-remote-dns.XXXXXX)"
  (
    dns-sd -B _ssh._tcp local. >"$tmp" 2>&1 &
    pid=$!
    sleep 2
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  )
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      *Add*)
        name="$(printf '%s\n' "$line" | awk '{print $NF}')"
        name="${name%$'\r'}"
        if reisen_ui_remote_is_imac_bonjour_name "$name"; then
          printf '%s.local\n' "$name"
        fi
        ;;
    esac
  done <"$tmp"
  rm -f "$tmp"
  printf '%s\n' 'imac.local'
  local i
  for i in 1 2 3 4 5 6 7 8 9; do
    printf 'imac-%s.local\n' "$i"
  done
}

reisen_ui_remote_unique_lines() {
  sort -u
}

reisen_ui_remote_resolve_host() {
  local override="${REISEN_UI_REMOTE_HOST:-}"
  if [[ -n "$override" ]]; then
    if ! reisen_ui_remote_ssh_ok "$override"; then
      echo "Fehler: REISEN_UI_REMOTE_HOST=${override} per SSH nicht erreichbar." >&2
      return 1
    fi
    printf '%s\n' "$override"
    return 0
  fi

  if reisen_ui_remote_ssh_ok "$REISEN_UI_REMOTE_PRIMARY_HOST"; then
    printf '%s\n' "$REISEN_UI_REMOTE_PRIMARY_HOST"
    return 0
  fi
  echo "Hinweis: Primärhost ${REISEN_UI_REMOTE_PRIMARY_HOST} nicht per SSH erreichbar — Bonjour-Fallback." >&2

  local -a rows=()
  local host rtt identity rank seen lower
  while IFS= read -r host; do
    [[ -z "$host" ]] && continue
    lower="$(printf '%s\n' "$host" | tr '[:upper:]' '[:lower:]')"
    seen=0
    for row in "${rows[@]+"${rows[@]}"}"; do
      case "$row" in
        *"|$lower|"*) seen=1; break ;;
      esac
    done
    [[ "$seen" -eq 1 ]] && continue
    if ! reisen_ui_remote_ssh_ok "$host"; then
      continue
    fi
    rtt="$(reisen_ui_remote_rtt_ms "$host")"
    identity="$(reisen_ui_remote_identity "$host")"
    rank="$(reisen_ui_remote_name_rank "$host")"
    rows+=("${rtt}|${rank}|${lower}|${identity}")
  done < <(reisen_ui_remote_bonjour_candidates | reisen_ui_remote_unique_lines)

  if [[ "${#rows[@]}" -eq 0 ]]; then
    echo "Fehler: Primär und Bonjour ohne SSH-Treffer für imac*." >&2
    return 1
  fi

  local -a identities=()
  local id found
  for row in "${rows[@]}"; do
    id="${row##*|}"
    found=0
    for existing in "${identities[@]+"${identities[@]}"}"; do
      if [[ "$existing" == "$id" ]]; then
        found=1
        break
      fi
    done
    if [[ "$found" -eq 0 ]]; then
      identities+=("$id")
    fi
  done

  if [[ "${#identities[@]}" -gt 1 ]]; then
    echo "Fehler: mehrere unterschiedliche Bonjour-Identities — setze REISEN_UI_REMOTE_HOST:" >&2
    for row in "${rows[@]}"; do
      echo "  ${row}" >&2
    done
    return 1
  fi

  local best
  best="$(printf '%s\n' "${rows[@]}" | sort -t'|' -k1,1n -k2,2n -k3,3 | head -1)"
  host="$(printf '%s\n' "$best" | cut -d'|' -f3)"
  rtt="$(printf '%s\n' "$best" | cut -d'|' -f1)"
  echo "Remote-Host (Bonjour): ${host} (RTT≈${rtt} ms, identity=${identities[0]})" >&2
  printf '%s\n' "$host"
}

reisen_ui_remote_rsync_excludes() {
  printf '%s\n' \
    --exclude='.build/' \
    --exclude='DerivedData/' \
    --exclude='*.xcodeproj/' \
    --exclude='*.xcworkspace/' \
    --exclude='.sweetpad/' \
    --exclude='buildServer.json' \
    --exclude='*.xcresult' \
    --exclude='*.profraw' \
    --exclude='.worktrees/' \
    --exclude='.superpowers/' \
    --exclude='Secrets/' \
    --exclude='.signing/' \
    --exclude='HAR/' \
    --exclude='*.har' \
    --exclude='.netrc' \
    --exclude='Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift'
}

reisen_ui_remote_expand_dir() {
  local host="$1"
  local raw="${REISEN_UI_REMOTE_DIR:-$REISEN_UI_REMOTE_DIR_DEFAULT}"
  local suffix
  case "$raw" in
    "~/"*)
      # ${var#~/} tilde-expandiert das Muster — Prefix literal quoten
      suffix="${raw#"~/"}"
      reisen_ui_remote_ssh "$host" "printf '%s\n' \"\$HOME/${suffix}\""
      ;;
    "~")
      reisen_ui_remote_ssh "$host" 'printf "%s\n" "$HOME"'
      ;;
    /*)
      printf '%s\n' "$raw"
      ;;
    *)
      reisen_ui_remote_ssh "$host" "printf '%s\n' $(printf '%q' "$raw")"
      ;;
  esac
}

reisen_ui_remote_make_run_id() {
  local stamp rand
  if [[ -n "${REISEN_UI_REMOTE_RUN_ID:-}" ]]; then
    printf '%s\n' "$REISEN_UI_REMOTE_RUN_ID"
    return 0
  fi
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  rand="$(printf '%04x' "$((RANDOM % 65536))")"
  printf '%s-%s-%s\n' "$stamp" "$$" "$rand"
}

reisen_ui_remote_run_dir() {
  local base="$1"
  local run_id="$2"
  printf '%s/%s\n' "${base%/}" "$run_id"
}

reisen_ui_remote_acquire_lock() {
  local host="$1"
  local run_id="$2"
  local q_run q_lock q_stale q_wait
  q_run="$(printf '%q' "$run_id")"
  q_lock="$(printf '%q' "$REISEN_UI_REMOTE_LOCK_DIR")"
  q_stale="$(printf '%q' "$REISEN_UI_REMOTE_LOCK_STALE_SEC")"
  q_wait="$(printf '%q' "$REISEN_UI_REMOTE_LOCK_WAIT_MAX")"
  reisen_ui_remote_ssh_stdin "$host" <<EOF
set -euo pipefail
lock_dir=$q_lock
run_id=$q_run
stale_sec=$q_stale
wait_max=$q_wait
waited=0
reisen_ui_lock_is_stale() {
  local owner_file="\$lock_dir/owner"
  local age now ts
  # Aktiver macos-ui-test.sh → nie stehlen (auch ohne Owner-Datei / Legacy-Lock).
  if pgrep -f 'Scripts/macos-ui-test.sh' >/dev/null 2>&1; then
    return 1
  fi
  [[ -f "\$owner_file" ]] || return 0
  ts="\$(awk '{print \$2}' "\$owner_file" 2>/dev/null || true)"
  [[ -n "\$ts" ]] || return 0
  now="\$(date +%s)"
  age=\$((now - ts))
  if [[ "\$age" -lt "\$stale_sec" ]]; then
    return 1
  fi
  return 0
}
while ! mkdir "\$lock_dir" 2>/dev/null; do
  if reisen_ui_lock_is_stale; then
    echo "Hinweis: stale Remote-XCUI-Sperre — übernehme \$lock_dir" >&2
    rm -rf "\$lock_dir"
    continue
  fi
  if [[ "\$waited" -ge "\$wait_max" ]]; then
    echo "Fehler: Remote-XCUI-Sperre nach 30 Minuten nicht frei: \$lock_dir" >&2
    exit 73
  fi
  if [[ "\$waited" -eq 0 ]]; then
    echo "Remote-XCUI läuft bereits; warte auf die bestehende Ausführung …" >&2
  fi
  sleep 5
  waited=\$((waited + 1))
done
printf '%s %s\\n' "\$run_id" "\$(date +%s)" > "\$lock_dir/owner"
echo "Remote-XCUI-Sperre gehalten (run-id=\$run_id)." >&2
EOF
}

reisen_ui_remote_release_lock() {
  local host="$1"
  local run_id="$2"
  local q_run q_lock
  q_run="$(printf '%q' "$run_id")"
  q_lock="$(printf '%q' "$REISEN_UI_REMOTE_LOCK_DIR")"
  reisen_ui_remote_ssh_stdin "$host" <<EOF
set -euo pipefail
lock_dir=$q_lock
run_id=$q_run
if [[ ! -d "\$lock_dir" ]]; then
  exit 0
fi
if [[ -f "\$lock_dir/owner" ]]; then
  owner="\$(awk '{print \$1}' "\$lock_dir/owner" 2>/dev/null || true)"
  if [[ -n "\$owner" && "\$owner" != "\$run_id" ]]; then
    echo "Hinweis: Lock-Owner \$owner ≠ \$run_id — gebe nicht frei." >&2
    exit 0
  fi
fi
rm -rf "\$lock_dir"
EOF
}

reisen_ui_remote_cleanup_run_dir() {
  local host="$1"
  local abs_run="$2"
  local q_run
  q_run="$(printf '%q' "$abs_run")"
  reisen_ui_remote_ssh "$host" "rm -rf ${q_run}"
}

# 0 = Primär-Checkout (.git Directory); 1 = Git-Worktree (.git Datei); sonst Fehler.
reisen_ui_remote_git_source_kind() {
  if [[ -d "$ROOT/.git" ]]; then
    printf 'primary\n'
    return 0
  fi
  if [[ -f "$ROOT/.git" ]] && grep -q '^gitdir:' "$ROOT/.git"; then
    printf 'worktree\n'
    return 0
  fi
  echo "Fehler: kein Git-Repo unter ${ROOT} (.git fehlt)." >&2
  return 1
}

reisen_ui_remote_assert_git_source() {
  local kind
  kind="$(reisen_ui_remote_git_source_kind)" || return 1
  case "$kind" in
    primary)
      echo "Sync-Quelle: Primär-Checkout (.git Directory)." >&2
      ;;
    worktree)
      echo "Sync-Quelle: Git-Worktree — Working Tree wird gespiegelt; .git wird excluded (kein Common-Dir-Partial-Sync)." >&2
      ;;
    *)
      echo "Fehler: unbekannte Git-Quelle: ${kind}" >&2
      return 1
      ;;
  esac
}

reisen_ui_remote_run_gates() {
  local host="$1"
  reisen_ui_remote_ssh_stdin "$host" <<'EOF'
set -euo pipefail
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Fehler: python3 fehlt remote (nötig für Terminal-Profil ReisenUIRemote)." >&2
  exit 1
fi

console="$(stat -f %Su /dev/console)"
me="$(whoami)"
if [[ "$console" != "$me" ]]; then
  echo "Fehler: Console-User (${console}) != SSH-User (${me}). GUI-Login als ${me} nötig." >&2
  exit 1
fi

# xcode-select kann auf CLT zeigen; DEVELOPER_DIR ohne sudo auf Xcode.app / Xcode-beta.app setzen.
pick_developer_dir() {
  local app dev major
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app /Applications/Xcode*.app; do
    [[ -d "$app" ]] || continue
    dev="${app}/Contents/Developer"
    [[ -x "${dev}/usr/bin/xcodebuild" ]] || continue
    major="$(
      { DEVELOPER_DIR="$dev" "${dev}/usr/bin/xcodebuild" -version 2>/dev/null || true; } \
        | awk '/^Xcode /{print $2; exit}' \
        | cut -d. -f1
    )"
    if [[ -n "$major" ]] && [[ "$major" -ge 27 ]]; then
      printf '%s\n' "$dev"
      return 0
    fi
  done
  return 1
}

if ! DEVELOPER_DIR="$(pick_developer_dir)"; then
  echo "Fehler: Kein Xcode ≥27 unter /Applications (Xcode.app / Xcode-beta.app). Optional dauerhaft: sudo xcode-select -s /Applications/Xcode-beta.app" >&2
  exit 1
fi
export DEVELOPER_DIR
echo "Remote DEVELOPER_DIR=${DEVELOPER_DIR}" >&2
printf '%s\n' "$DEVELOPER_DIR" > /tmp/reisen-macos-ui-developer-dir

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Fehler: xcodegen fehlt und brew nicht gefunden." >&2
    exit 1
  fi
  echo "Hinweis: installiere xcodegen via brew …" >&2
  NONINTERACTIVE=1 brew install xcodegen
fi
command -v xcodegen >/dev/null
EOF
}

reisen_ui_remote_sync() {
  local host="$1"
  local abs_dir="$2"
  local -a excludes
  local -a ssh_opts
  local kind
  while IFS= read -r line; do
    excludes+=("$line")
  done < <(reisen_ui_remote_rsync_excludes)
  kind="$(reisen_ui_remote_git_source_kind)" || return 1
  if [[ "$kind" == "worktree" ]]; then
    excludes+=(--exclude='.git')
  fi
  while IFS= read -r line; do
    ssh_opts+=("$line")
  done < <(reisen_ui_remote_ssh_base_opts)

  reisen_ui_remote_ssh "$host" "mkdir -p $(printf '%q' "$abs_dir")"
  echo "rsync → $(reisen_ui_remote_user)@${host}:${abs_dir}/ …" >&2
  rsync -a --delete \
    "${excludes[@]}" \
    -e "ssh ${ssh_opts[*]}" \
    "$ROOT/" "$(reisen_ui_remote_target "$host"):${abs_dir}/"
}

reisen_ui_remote_terminal_plist_py() {
  # Shared remote Python: mode=prepare|restore
  cat <<'PY'
import copy
import plistlib
import pathlib
import subprocess
import sys

plist_path = pathlib.Path.home() / "Library/Preferences/com.apple.Terminal.plist"
marker = pathlib.Path("/tmp/reisen-macos-ui-terminal-default-prev")
profile_name = "ReisenUIRemote"
shell_exit_close = 0  # Close the window
mode = sys.argv[1] if len(sys.argv) > 1 else "prepare"

def load():
    if plist_path.exists():
        with plist_path.open("rb") as f:
            return plistlib.load(f)
    return {}

def save(data):
    with plist_path.open("wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
    subprocess.run(
        ["killall", "cfprefsd"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

if mode == "prepare":
    data = load()
    window_settings = data.setdefault("Window Settings", {})
    basic = window_settings.get("Basic") or window_settings.get("Pro") or {}
    profile = copy.deepcopy(basic) if basic else {}
    profile["name"] = profile_name
    profile["type"] = "Window Settings"
    profile["shellExitAction"] = shell_exit_close
    profile["ProfileCurrentVersion"] = profile.get("ProfileCurrentVersion", "2.08")
    window_settings[profile_name] = profile
    data["Window Settings"] = window_settings
    prev = data.get("Default Window Settings", "Basic")
    if not marker.exists():
        marker.write_text(str(prev) + "\n", encoding="utf-8")
    data["Default Window Settings"] = profile_name
    save(data)
    print(f"Terminal-Profil {profile_name} shellExitAction={shell_exit_close}, Default={profile_name} (vorher {prev})")
elif mode == "restore":
    if not marker.exists() or not plist_path.exists():
        raise SystemExit(0)
    prev = marker.read_text(encoding="utf-8").strip() or "Basic"
    data = load()
    data["Default Window Settings"] = prev
    save(data)
    marker.unlink(missing_ok=True)
    print(f"Terminal Default wieder: {prev}")
else:
    raise SystemExit(f"unknown mode: {mode}")
PY
}

reisen_ui_remote_ensure_terminal_profile() {
  # Profil + kurz Default setzen. Fail-fast (kein || true) — sonst bleiben Fenster offen.
  local host="$1"
  reisen_ui_remote_ssh_stdin "$host" <<EOF
set -euo pipefail
python3 - prepare <<'PY'
$(reisen_ui_remote_terminal_plist_py)
PY
EOF
}

reisen_ui_remote_restore_terminal_default() {
  local host="$1"
  reisen_ui_remote_ssh_stdin "$host" <<EOF
set -euo pipefail
python3 - restore <<'PY'
$(reisen_ui_remote_terminal_plist_py)
PY
EOF
}

reisen_ui_remote_skip_stderr() {
  # Prints SKIP_STDERR to stdout; fails closed if Python/constant unavailable.
  local msg
  if ! msg="$(
    python3 -c "import importlib.util, sys; s=importlib.util.spec_from_file_location('m', sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(m.SKIP_STDERR, end='')" \
      "$ROOT/Scripts/macos_ui_select_tests.py"
  )" || [[ -z "$msg" ]]; then
    echo "Fehler: SKIP_STDERR aus macos_ui_select_tests.py nicht lesbar." >&2
    return 1
  fi
  printf '%s\n' "$msg"
}

reisen_ui_remote_parse_argv() {
  REMOTE_MODE=diff
  while (($#)); do
    case "$1" in
      --full)
        REMOTE_MODE=full
        shift
        ;;
      --self-test)
        echo "Fehler: --self-test nur als alleiniges Argument (bash ./Scripts/macos-ui-test-remote.sh --self-test)." >&2
        return 2
        ;;
      *)
        echo "Fehler: unbekanntes Argument: $1" >&2
        return 2
        ;;
    esac
  done
  return 0
}

reisen_ui_remote_resolve_test_args() {
  REMOTE_TEST_ARGS=()
  case "$REMOTE_MODE" in
    full)
      REMOTE_TEST_ARGS=(--full)
      ;;
    diff)
      local selector_out selector_status
      local -a only_lines=()
      selector_out="$(python3 "$ROOT/Scripts/macos_ui_select_tests.py" --repo-root "$ROOT")"
      selector_status=$?
      if [[ "$selector_status" -ne 0 ]]; then
        return "$selector_status"
      fi
      while IFS= read -r line; do
        [[ -n "$line" ]] && only_lines+=("$line")
      done <<EOF
$selector_out
EOF
      if ((${#only_lines[@]} == 0)); then
        reisen_ui_remote_skip_stderr >&2 || return 1
        # 10 = skip sentinel (not a python/selector exit code)
        return 10
      fi
      REMOTE_TEST_ARGS=(--reisen-ui-only-testing "${only_lines[@]}")
      ;;
    *)
      echo "Fehler: unbekannter Modus: $REMOTE_MODE" >&2
      return 2
      ;;
  esac
  return 0
}

reisen_ui_remote_quote_test_invoke() {
  local -a remote_test_args=("$@")
  local invoke arg
  invoke='bash ./Scripts/macos-ui-test.sh'
  for arg in "${remote_test_args[@]}"; do
    invoke="${invoke} $(printf '%q' "$arg")"
  done
  printf '%s\n' "$invoke"
}

reisen_ui_remote_run_ui_tests() {
  local host="$1"
  local abs_dir="$2"
  local run_id="$3"
  shift 3
  local -a remote_test_args=("$@")
  local qdir q_exit q_log q_cmd test_invoke
  local test_status
  qdir="$(printf '%q' "$abs_dir")"
  q_exit="$(printf '%q' "/tmp/reisen-macos-ui-run-${run_id}.exit")"
  q_log="$(printf '%q' "/tmp/reisen-macos-ui-run-${run_id}.log")"
  q_cmd="$(printf '%q' "/tmp/reisen-macos-ui-run-${run_id}.command")"
  if ((${#remote_test_args[@]} == 0)); then
    echo "Fehler: remote test args fehlen (Passthrough/--full Pflicht)" >&2
    return 2
  fi
  test_invoke="$(reisen_ui_remote_quote_test_invoke "${remote_test_args[@]}")"
  echo "macOS-UI-Tests remote auf ${host} (via Terminal/open, auto-close, run-id=${run_id}) …" >&2
  # Continuity/AirPlay-Dialog („MacBook Pro …“) blockiert XCUI-Hit-Tests.
  reisen_ui_remote_ssh "$host" 'killall AirPlayUIAgent 2>/dev/null || true'
  reisen_ui_remote_ensure_terminal_profile "$host"
  # EXIT: Terminal-Default zurücksetzen UND Lock freigeben (kein Ersatz der Main-Trap).
  trap 'reisen_ui_remote_restore_terminal_default "'"$host"'" || true; if [[ "${lock_held:-0}" -eq 1 ]]; then reisen_ui_remote_release_lock "'"$HOST"'" "'"$RUN_ID"'"; fi' EXIT
  # Kein osascript/AppleScript: Default-Profil nur bis open, dann sofort restore.
  # Fenster erbt Profil beim open; kein Automation-TCC, kein close-Dialog.
  reisen_ui_remote_ssh_stdin "$host" <<EOF
set -euo pipefail
exit_file=$q_exit
log_file=$q_log
cmd_file=$q_cmd
rm -f "\$exit_file" "\$log_file" "\$cmd_file"
{
  echo '#!/bin/bash'
  echo 'set -euo pipefail'
  echo 'printf "\\033]0;reisen-macos-ui-run\\007"'
  echo 'export DEVELOPER_DIR="\$(cat /tmp/reisen-macos-ui-developer-dir)"'
  echo 'export REISEN_MAC_UI_CODE_SIGNING_OFF=true'
  echo 'cd ${qdir}'
  echo 'rm -rf DerivedData/ReisenMacUITests'
  echo 'set +e'
  echo "${test_invoke} > \${log_file} 2>&1"
  echo 'status=\$?'
  echo 'set -e'
  echo "printf '%s\\n' \"\\\$status\" > \${exit_file}"
  # Immer clean exit → Terminal schließt Fenster (shellExitAction), ohne Nutzerdialog.
  echo 'exit 0'
} > "\$cmd_file"
chmod +x "\$cmd_file"
xattr -cr "\$cmd_file" 2>/dev/null || true
open -a Terminal "\$cmd_file"
# Default sofort zurück — geöffnetes Fenster behält ReisenUIRemote; Race mit Nutzer-Terminals kurz.
python3 - restore <<'PY'
$(reisen_ui_remote_terminal_plist_py)
PY
status=1
for _ in \$(seq 1 360); do
  if [[ -f "\$exit_file" ]]; then
    status="\$(cat "\$exit_file")"
    if [[ -f "\$log_file" ]]; then
      tail -80 "\$log_file" >&2 || true
    fi
    break
  fi
  sleep 5
done
if [[ ! -f "\$exit_file" ]]; then
  echo "Fehler: Timeout — keine Exit-Datei von Terminal-Runner." >&2
  if [[ -f "\$log_file" ]]; then
    tail -80 "\$log_file" >&2 || true
  fi
  status=1
fi
exit "\$status"
EOF
  test_status=$?
  reisen_ui_remote_restore_terminal_default "$host" || true
  # Main-Lock-Trap wiederherstellen (Terminal bereits restored).
  trap 'if [[ "${lock_held:-0}" -eq 1 ]]; then reisen_ui_remote_release_lock "'"$HOST"'" "'"$RUN_ID"'"; fi' EXIT
  return "$test_status"
}

reisen_ui_remote_fetch_xcresult() {
  local host="$1"
  local abs_dir="$2"
  local dest="$ROOT/DerivedData/ReisenMacUITests-remote"
  local -a ssh_opts
  while IFS= read -r line; do
    ssh_opts+=("$line")
  done < <(reisen_ui_remote_ssh_base_opts)
  mkdir -p "$dest"
  echo "xcresult ← ${host}:${abs_dir}/DerivedData/ReisenMacUITests/ …" >&2
  rsync -a \
    -e "ssh ${ssh_opts[*]}" \
    "$(reisen_ui_remote_target "$host"):${abs_dir}/DerivedData/ReisenMacUITests/" \
    "$dest/"
}

reisen_ui_remote_self_test() {
  local excludes out opts script_path
  script_path="$ROOT/Scripts/macos-ui-test-remote.sh"
  excludes="$(reisen_ui_remote_rsync_excludes)"
  printf '%s\n' "$excludes" | grep -Fqx -- '--exclude=Secrets/'
  printf '%s\n' "$excludes" | grep -Fqx -- '--exclude=.signing/'
  printf '%s\n' "$excludes" | grep -Fqx -- '--exclude=HAR/'
  printf '%s\n' "$excludes" | grep -Fqx -- '--exclude=*.har'
  printf '%s\n' "$excludes" | grep -Fqx -- '--exclude=.netrc'
  printf '%s\n' "$excludes" | grep -Fq 'GitHubIssueToken.generated.swift'

  [[ "$REISEN_UI_REMOTE_PRIMARY_HOST" == "imac.altanis.de" ]]
  [[ "$(reisen_ui_remote_strict_host_key)" == "yes" ]]
  opts="$(reisen_ui_remote_ssh_base_opts)"
  printf '%s\n' "$opts" | grep -Fqx -- 'StrictHostKeyChecking=yes'

  out="$(printf 'cd %q && exec bash ./Scripts/macos-ui-test.sh' '/Users/roschmac/Entwicklung/Reisen')"
  case "$out" in
    *'/Users/roschmac/Entwicklung/Reisen'*) ;;
    *)
      echo "self-test: Absolutpfad-Quoting fehlgeschlagen: $out" >&2
      return 1
      ;;
  esac
  case "$out" in
    *'$REMOTE_DIR'*)
      echo "self-test: \$REMOTE_DIR darf nicht im Invoke stehen" >&2
      return 1
      ;;
  esac

  reisen_ui_remote_is_imac_bonjour_name 'iMac'
  reisen_ui_remote_is_imac_bonjour_name 'iMac-3'
  if reisen_ui_remote_is_imac_bonjour_name 'MacBook'; then
    echo "self-test: MacBook darf nicht matchen" >&2
    return 1
  fi

  grep -Fq 'REISEN_MAC_UI_CODE_SIGNING_OFF=true' "$script_path"
  grep -Fq 'REISEN_UI_REMOTE_LOCK_DIR="/tmp/reisen-macos-ui-run.lock"' "$script_path"
  grep -Fq 'reisen_ui_remote_acquire_lock' "$script_path"
  grep -Fq 'reisen_ui_remote_release_lock' "$script_path"
  grep -Fq 'reisen_ui_remote_make_run_id' "$script_path"
  grep -Fq 'Reisen-ui-runs' "$script_path"
  grep -Fq 'while ! mkdir "\$lock_dir"' "$script_path"
  grep -Fq 'open -a Terminal' "$script_path"
  grep -Fq 'shellExitAction' "$script_path"
  grep -Fq 'command -v python3' "$script_path"
  grep -Fq 'StrictHostKeyChecking=' "$script_path"
  grep -Fq 'open -a Terminal "\$cmd_file"' "$script_path"
  grep -Fq 'reisen_ui_remote_release_lock' "$script_path"
  awk '
    /reisen_ui_remote_run_ui_tests\(\)/ { in_fn=1 }
    in_fn && /^}/ { in_fn=0 }
    in_fn && /trap .*EXIT/ {
      line=$0
      if (line ~ /reisen_ui_remote_restore_terminal_default/ && line !~ /reisen_ui_remote_release_lock/) {
        print "self-test: EXIT-Trap in run_ui_tests ohne Lock-Release: " line > "/dev/stderr"
        exit 1
      }
    }
  ' "$script_path"
  grep -Fq 'reisen_ui_remote_assert_git_source' "$script_path"
  grep -Fq "excludes+=(--exclude='.git')" "$script_path"
  acquire_line="$(grep -n '^reisen_ui_remote_acquire_lock "$HOST" "$RUN_ID"' "$script_path" | head -1 | cut -d: -f1)"
  sync_line="$(grep -n '^reisen_ui_remote_sync "$HOST" "$ABS_DIR"' "$script_path" | head -1 | cut -d: -f1)"
  [[ -n "$acquire_line" && -n "$sync_line" && "$acquire_line" -lt "$sync_line" ]]

  grep -Fq 'macos_ui_select_tests.py' "$script_path"
  grep -Fqe '--reisen-ui-only-testing' "$script_path"
  grep -Fq 'reisen_ui_remote_skip_stderr' "$script_path"
  grep -Fq 'reisen_ui_remote_resolve_test_args' "$script_path"
  grep -Fq 'reisen_ui_remote_quote_test_invoke' "$script_path"
  grep -Fq 'test_invoke' "$script_path"

  skip_spec="$(reisen_ui_remote_skip_stderr)"
  printf '%s\n' "$skip_spec" | grep -Fq 'macos-ui-test: no smoke selection (diff); skip XCUI.'

  fake_arg='-only-testing:ReisenMacUITests/MacUISmokeTests/testFoo'
  passthrough_out="$(reisen_ui_remote_quote_test_invoke --reisen-ui-only-testing "$fake_arg")"
  case "$passthrough_out" in
    *'--reisen-ui-only-testing'*) ;;
    *)
      echo "self-test: Passthrough ohne --reisen-ui-only-testing: $passthrough_out" >&2
      return 1
      ;;
  esac
  case "$passthrough_out" in
    *testFoo*) ;;
    *)
      echo "self-test: Passthrough-Quoting für testFoo fehlgeschlagen: $passthrough_out" >&2
      return 1
      ;;
  esac
  grep -Fq 'echo "${test_invoke} > \${log_file} 2>&1"' "$script_path"

  resolve_line="$(grep -n '^reisen_ui_remote_resolve_test_args || resolve_status=\$?' "$script_path" | head -1 | cut -d: -f1)"
  [[ -n "$resolve_line" && -n "$acquire_line" && "$resolve_line" -lt "$acquire_line" ]]
  grep -Fq 'return 10' "$script_path"

  full_out="$(reisen_ui_remote_quote_test_invoke --full)"
  case "$full_out" in
    *'bash ./Scripts/macos-ui-test.sh --full'*) ;;
    *)
      echo "self-test: --full quoting fehlgeschlagen: $full_out" >&2
      return 1
      ;;
  esac

  echo "macos-ui-test-remote.sh self-test: OK" >&2
  echo "Resolve-Reihenfolge: REISEN_UI_REMOTE_HOST → ${REISEN_UI_REMOTE_PRIMARY_HOST} → Bonjour imac*.local (niedrigste RTT)" >&2
}

if [[ "${1:-}" == "--self-test" ]]; then
  if (($# != 1)); then
    echo "Fehler: --self-test nur als alleiniges Argument (bash ./Scripts/macos-ui-test-remote.sh --self-test)." >&2
    exit 2
  fi
  reisen_ui_remote_self_test
  exit 0
fi

reisen_ui_remote_parse_argv "$@" || exit $?

cd "$ROOT"
reisen_ui_remote_assert_git_source

resolve_status=0
reisen_ui_remote_resolve_test_args || resolve_status=$?
if [[ "$resolve_status" -eq 10 ]]; then
  exit 0
fi
if [[ "$resolve_status" -ne 0 ]]; then
  exit "$resolve_status"
fi

HOST="$(reisen_ui_remote_resolve_host)"
if [[ "${REISEN_UI_REMOTE_HOST:-}" == "$HOST" ]]; then
  echo "Remote-Host (Override): ${HOST}" >&2
elif [[ "$HOST" == "$REISEN_UI_REMOTE_PRIMARY_HOST" ]]; then
  echo "Remote-Host (Primär): ${HOST}" >&2
fi

reisen_ui_remote_run_gates "$HOST"
ABS_BASE="$(reisen_ui_remote_expand_dir "$HOST")"
if [[ -z "$ABS_BASE" || "$ABS_BASE" == ~* ]]; then
  echo "Fehler: Remote-Pfad nicht absolut expandiert: '${ABS_BASE}'" >&2
  exit 1
fi

RUN_ID="$(reisen_ui_remote_make_run_id)"
ABS_DIR="$(reisen_ui_remote_run_dir "$ABS_BASE" "$RUN_ID")"
echo "Remote-Run-Dir: ${ABS_DIR} (run-id=${RUN_ID})" >&2

reisen_ui_remote_acquire_lock "$HOST" "$RUN_ID"
lock_held=1
trap 'if [[ "${lock_held:-0}" -eq 1 ]]; then reisen_ui_remote_release_lock "'"$HOST"'" "'"$RUN_ID"'"; fi' EXIT

reisen_ui_remote_sync "$HOST" "$ABS_DIR"

set +e
reisen_ui_remote_run_ui_tests "$HOST" "$ABS_DIR" "$RUN_ID" "${REMOTE_TEST_ARGS[@]}"
status=$?
set -e

if [[ "${REISEN_UI_REMOTE_FETCH_XCRESULT:-}" == "1" ]]; then
  set +e
  reisen_ui_remote_fetch_xcresult "$HOST" "$ABS_DIR"
  fetch_status=$?
  set -e
  if [[ "$fetch_status" -ne 0 ]]; then
    echo "Fehler: xcresult-Fetch fehlgeschlagen (Exit ${fetch_status})." >&2
    if [[ "$status" -eq 0 ]]; then
      status="$fetch_status"
    fi
  fi
fi

if [[ "$status" -eq 0 ]]; then
  set +e
  reisen_ui_remote_cleanup_run_dir "$HOST" "$ABS_DIR"
  set -e
else
  echo "Fehler: Remote-UI-Tests Exit ${status}. Run-Dir belassen: ${ABS_DIR}" >&2
  echo "Log remote: /tmp/reisen-macos-ui-run-${RUN_ID}.log bzw. ${ABS_DIR}/DerivedData/ReisenMacUITests/macos-ui-xcodebuild.log" >&2
fi

reisen_ui_remote_release_lock "$HOST" "$RUN_ID"
lock_held=0
trap - EXIT

if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi
