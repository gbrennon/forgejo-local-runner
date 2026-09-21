#!/usr/bin/env bash
set -euo pipefail

fjr_resolve_repo_root() {
  cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
  pwd
}

fjr_choose_share_dir() {
  printf '%s' "${FJR_HOME:-$HOME/.local/share/fjr}"
}

fjr_choose_bin_dir() {
  printf '%s' "${FJR_BIN_DIR:-$HOME/.local/bin}"
}

fjr_is_own_symlink() {
  local bin_dir="$1" share_dir="$2"
  [ -L "$bin_dir/fjr" ] && [ "$(readlink "$bin_dir/fjr")" = "$share_dir/fjr" ]
}

fjr_backup_foreign_cli() {
  local bin_dir="$1" share_dir="$2"
  if fjr_is_own_symlink "$bin_dir" "$share_dir"; then
    return
  fi
  if [ -e "$bin_dir/fjr" ] || [ -L "$bin_dir/fjr" ]; then
    mv "$bin_dir/fjr" "$bin_dir/fjr.bak"
  fi
}

fjr_copy_cli_into_share_dir() {
  local repo_root="$1" share_dir="$2"
  mkdir -p "$share_dir/lib"
  install -m 755 "$repo_root/cli/fjr" "$share_dir/fjr"
  cp "$repo_root/cli/lib/"*.sh "$share_dir/lib/"
}

fjr_link_cli_in_bin_dir() {
  local share_dir="$1" bin_dir="$2"
  mkdir -p "$bin_dir"
  ln -sfn "$share_dir/fjr" "$bin_dir/fjr"
}

fjr_verify_installed_cli() {
  local bin_dir="$1"
  local resolved
  resolved="$(PATH="$bin_dir:$PATH" command -v fjr || true)"
  if [ -z "$resolved" ]; then
    echo "fjr: install failed; 'fjr' is not resolvable with $bin_dir on PATH" >&2
    exit 1
  fi
  PATH="$bin_dir:$PATH" fjr --help >/dev/null
}

fjr_print_path_notice() {
  local bin_dir="$1"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "fjr: $bin_dir is not on PATH; add it with: export PATH=\"$bin_dir:\$PATH\"" ;;
  esac
}

fjr_install_main() {
  local repo_root share_dir bin_dir
  repo_root="$(fjr_resolve_repo_root)"
  share_dir="$(fjr_choose_share_dir)"
  bin_dir="$(fjr_choose_bin_dir)"
  fjr_backup_foreign_cli "$bin_dir" "$share_dir"
  fjr_copy_cli_into_share_dir "$repo_root" "$share_dir"
  fjr_link_cli_in_bin_dir "$share_dir" "$bin_dir"
  fjr_verify_installed_cli "$bin_dir"
  fjr_print_path_notice "$bin_dir"
  echo "fjr: installed $(readlink -f "$bin_dir/fjr")"
}

fjr_install_main
