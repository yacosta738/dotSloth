#!/usr/bin/env bash

#
# If you need more system information, consider to add neofetch as submodule
#   https://github.com/dylanaraps/neofetch
#

if [[ -z "${SLOTH_OS:-}" || -z "${SLOTH_ARCH}" ]]; then
  #shellcheck disable=SC2034,SC2207
  [[ -z "${SLOTH_UNAME:-}" ]] && SLOTH_UNAME=($(uname -sm))
  if [[ -n "${SLOTH_UNAME[0]:-}" ]]; then
    SLOTH_OS="${SLOTH_UNAME[0]}"
    SLOTH_ARCH="${SLOTH_UNAME[1]}"
  else
    SLOTH_OS="${SLOTH_UNAME[1]}"
    SLOTH_ARCH="${SLOTH_UNAME[2]}"
  fi
fi
export SLOTH_UNAME SLOTH_OS SLOTH_ARCH

platform::command_exists() {
  type "$1" > /dev/null 2>&1
}

platform::macos_version() {
  { platform::is_macos && sw_vers -productVersion; } || return
}

platform::macos_version_name() {
  platform::is_macos && awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}'
}

platform::get_os() {
  echo "${SLOTH_OS}" | tr '[:upper:]' '[:lower:]'
}

platform::macos_is_rosetta() {
  [[ $(sysctl -n sysctl.proc_translated 2> /dev/null) == 1 ]]
}

platform::get_arch() {
  local architecture="unknown"
  case "${SLOTH_ARCH}" in
    x86_64)
      architecture="amd64"
      ;;
    arm*)
      architecture="arm"
      ;;
    ppc64)
      architecture="ppc64"
      ;;
    i?86)
      if platform::is_macos && sysctl hw.optional.x86_64 | grep -q ': 1$'; then
        architecture="amd64"
      else
        architecture="x86"
      fi
      ;;
  esac

  echo "$architecture"
}

platform::is_arm() {
  [[ $(platform::get_arch) == "arm" ]]
}

platform::is_macos() {
  [[ $SLOTH_OS == "Darwin"* ]]
}

platform::is_macos_arm() {
  platform::is_macos && platform::is_arm
}

platform::is_linux() {
  [[ $SLOTH_OS == *"Linux"* ]]
}

platform::is_windows() {
  [[ $SLOTH_OS == "Windows"* || $SLOTH_OS == "MINGW64"* || $SLOTH_OS == "CYGWIN_NT"* || $SLOTH_OS == "MS-DOS" || $SLOTH_OS == "MSYS"* || $SLOTH_OS == "Wine"* || $SLOTH_OS == "UWIN"* ]]
}

platform::is_wsl() {
  grep -qEi "(Microsoft|WSL|microsoft)" /proc/version > /dev/null 2>&1 || grep -q -F 'Microsoft' /proc/sys/kernel/osrelease
}

platform::is_bsd() {
  platform::is_macos || [[ $SLOTH_OS == *"BSD"* || $SLOTH_OS == "DragonFly" || $SLOTH_OS == "Minix" ]]
}

platform::os() {
  # Should never show unknown but expect the unexpected ;)
  local os="unknown"

  case "$(platform::get_os)" in
    darwin*)
      os="macos"
      ;;
    linux | gnu)
      if platform::is_wsl; then
        os="wsl"
      else
        os="linux"
      fi
      ;;
    *bsd*)
      os="bsd"
      ;;
    *)
      os="$SLOTH_OS"
      ;;
  esac

  echo "$os"
}

platform::wsl_home_path() {
  wslpath "$(wslvar USERPROFILE 2> /dev/null)"
}

# It does not support beta, rc and similar suffix
platform::semver_compare() {
  platform::semver compare "${1//v/}" "${2//v/}"
}

# Equal version return false because there is not difference
platform::semver_is_minor_or_patch_update() {
  local diff_type
  diff_type="$(platform::semver diff "${1//v/}" "${2//v/}" | tr '[:upper:]' '[:lower:]')"
  [[ -n "${diff_type}" && "$diff_type" != "major" ]]
}

platform::semver() {
  script::depends_on semver

  if [[ -z "${SEMVER_BIN:-}" || -x "$SEMVER_BIN" ]]; then
    if command -v semver > /dev/null 2>&1; then
      SEMVER_BIN="$(command -v "semver")"
    elif [[ -x "${DOTFILES_PATH}/bin/semver" ]]; then
      SEMVER_BIN="${DOTFILES_PATH}/bin/semver"
    elif [[ -x "${HOME}/bin/semver" ]]; then
      SEMVER_BIN="${HOME}/bin/semver"
    else
      return 1
    fi
  fi

  "$SEMVER_BIN" "$@"
}
