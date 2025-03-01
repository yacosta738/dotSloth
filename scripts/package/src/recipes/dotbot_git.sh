#!/usr/bin/env bash
#shellcheck disable=SC2088
#? Author:
#?   Gabriel Trabanco Llano <gtrabanco@users.noreply.github.com>
#? v1.0.0

DOTBOT_GIT_REPOSITORY_URL="${DOTBOT_GIT_REPOSITORY_URL:-https://github.com/anishathalye/dotbot}"
DOTBOT_GIT_REPOSITORY="${DOTBOT_GIT_REPOSITORY:-anishathalye/dotbot}"
DOTBOT_GIT_DEFAULT_REMOTE="${DOTBOT_GIT_DEFAULT_REMOTE:-origin}"
DOTBOT_GIT_DEFAULT_BRANCH="${DOTBOT_GIT_DEFAULT_BRANCH:-}"

DOTBOT_BASEDIR="${DOTBOT_BASEDIR:-${DOTFILES_PATH:-${HOME}/.dotfiles}}"
DOTBOT_SUBMODULE_DIR="${DOTBOT_SUBMODULE_DIR:-modules/dotbot}"
DOTBOT_SUBMODULE_NAME="${DOTBOT_SUBMODULE_NAME:-dotbot}"
DOTBOT_INSTALL_METHOD="${DOTBOT_INSTALL_METHOD:-module}"

dotbot_git::get_dotbot_path() {
  if [[ -n "${DOTFILES_PATH:-}" && -d "$DOTFILES_PATH" ]]; then
    printf "%s" "${DOTFILES_PATH}/${DOTBOT_SUBMODULE_DIR}"
  else
    printf "%s" "${HOME}/.dotbot"
  fi
}

dotbot_git::get_repository_tag_version() {
  git::remote_latest_tag_version "$DOTBOT_GIT_REPOSITORY_URL" "v*.*.*"
}

dotbot_git::get_remote_default_branch() {
  if [[ -n "$DOTBOT_GIT_DEFAULT_BRANCH" ]]; then
    printf "%s" "$DOTBOT_GIT_DEFAULT_BRANCH"
  else
    local -r default_branch="$(github::get_api_url "$DOTBOT_GIT_REPOSITORY" | github::curl | jq -r '.default_branch' || true)"
    DOTBOT_GIT_DEFAULT_BRANCH="${default_branch:-master}"

    printf "%s" "$DOTBOT_GIT_DEFAULT_BRANCH"
  fi
}

dotbot_git::get_remote_latest_commit_sha() {
  local -r default_branch="$(dotbot_git::get_remote_default_branch)"
  {
    [[ -n "$default_branch" ]] && github::get_api_url "$DOTBOT_GIT_REPOSITORY" "commits/${default_branch}" | jq -r '.sha' 2> /dev/null
  } || true
}

dotbot_git::get_local_lastest_commit_sha() {
  git::git -C "$(dotbot_git::get_dotbot_path)" rev-parse "$(dotbot_git::get_remote_default_branch)"
}

dotbot_git::update_local_repository() {
  local -r dotbot_path="$(dotbot_git::get_dotbot_path)"
  local -r default_branch="$(dotbot_git::get_remote_default_branch)"

  git::init_repository_if_necessary "$DOTBOT_GIT_REPOSITORY_URL" "$DOTBOT_GIT_DEFAULT_REMOTE" "$default_branch" -C "$dotbot_path"
  git::pull_branch "$DOTBOT_GIT_DEFAULT_REMOTE" "$default_branch" -C "$dotbot_path"
}

dotbot_git::symlinks() {
  if [[ -d "${DOTFILES_PATH:-}" ]]; then
    dot::load_library "dotbot.sh" "symlinks"
    dotbot::add_or_edit_json_value_to_directive "link" "~/bin/dotbot" "${DOTBOT_SUBMODULE_DIR}/bin/dotbot" "$(dotbot::yaml_file_path)" > /dev/null 2>&1
    ln -fs "$(dotbot_git::get_dotbot_path)/bin/dotbot" "${HOME}/bin/dotbot"

  elif [[ -d "${HOME}/.dotbot" ]]; then
    ln -fs "${HOME}/.dotbot/bin/dotbot" "${HOME}/bin/dotbot"
  fi
}

dotbot_git::is_installed() {
  [[ -d "$(dotbot_git::get_dotbot_path)" && -x "${HOME}/bin/dotbot" ]] || package::which_package_manager "dotbot" > /dev/null 2>&1
}

dotbot_git::install() {
  if [[ $* == *"--force"* ]]; then
    # output::answer "\`--force\` option is ignored with this recipe"
    dotbot_git::force_install "$@" && return
  else
    if
      [[ -n "${DOTFILES_PATH:-}" ]] &&
        [[ -d "${DOTFILES_PATH:-}" ]] &&
        ! git::git -C "$DOTFILES_PATH" config -f ".gitmodules" submodule."$DOTBOT_SUBMODULE_DIR".path > /dev/null 2>&1
    then
      git::git -C "$DOTFILES_PATH" submodule add -b "$(dotbot_git::get_remote_default_branch)" --name "$DOTBOT_SUBMODULE_NAME" "$DOTBOT_GIT_REPOSITORY_URL" "$DOTBOT_SUBMODULE_DIR" >&2 || true
      git::git -C "$DOTFILES_PATH" config -f ".gitmodules" submodule."$DOTBOT_SUBMODULE_NAME".ignore dirty >&2 || true
    elif [[ -z "${DOTFILES_PATH:-}" ]]; then
      git::git clone "$DOTBOT_GIT_REPOSITORY_URL" "${HOME}/.dotbot" || true
      dotbot_git::update_local_repository || true
      mkdir -p "${HOME}/bin"
      ln -fs "$(dotbot_git::get_dotbot_path)/bin/dotbot" "${HOME}/bin/dotbot"
    fi
  fi

  dotbot_git::symlinks

  dotbot_git::is_installed &&
    return

  return 1
}

# OPTIONAL
dotbot_git::uninstall() {
  [[ -d "$(dotbot_git::get_dotbot_path)" ]] && rm -rf "$(dotbot_git::get_dotbot_path)"
  [[ -d "${DOTFILES_PATH:-}" ]] && git::remove_submodule "$DOTBOT_SUBMODULE_DIR" -C "$DOTFILES_PATH"
  {
    package::which_package_manager "dotbot" > /dev/null 2>&1 && package::uninstall dotbot
  } || true
}

# OPTIONAL
dotbot_git::force_install() {
  local _args
  mapfile -t _args < <(array::substract "--force" "$@")

  dotbot_git::uninstall "${_args[@]}"
  dotbot_git::install "${_args[@]}"
  dotbot_git::is_installed "${_args[@]}"
}

# ONLY REQUIRED IF YOU WANT TO IMPLEMENT AUTO UPDATE WHEN USING `up` or `up registry`
# Description, url and versions only be showed if defined
dotbot_git::is_outdated() {
  [[ "$(package::which_package_manager "dotbot")" != registry ]] && return # Use the package manager used to install

  [[ $(dotbot_git::get_local_lastest_commit_sha) != $(dotbot_git::get_remote_latest_commit_sha) ]]
}

dotbot_git::upgrade() {
  if [[ "$(package::which_package_manager "dotbot")" == registry ]]; then
    dotbot_git::update_local_repository
  fi
}

dotbot_git::description() {
  printf "%s" "Dotbot is a tool that bootstraps your dotfiles (it's a [Dot]files [bo]o[t]strapper, get it?). It does less than you think, because version control systems do more than you think."
}

dotbot_git::url() {
  printf "%s" "${DOTBOT_GIT_REPOSITORY_URL:-https://github.com/anishathalye/dotbot}"
}

dotbot_git::version() {
  # Get the current installed version
  local dotbot_bin
  dotbot_bin="$(command -v dotbot)"

  [[ -z "$dotbot_bin" ]] &&
    dotbot_git::is_installed &&
    dotbot_bin="$(dotbot_git::get_dotbot_path)/bin/dotbot"

  [[ -x "$dotbot_bin" ]] &&
    "$dotbot_bin" --version &&
    return

  return 1
}

dotbot_git::latest() {
  if dotbot_git::is_outdated; then
    local -r dotbot_remote_tag="$(dotbot_git::get_repository_tag_version)"
    local -r local_dotbot_version="$(dotbot_git::version)"

    if [[ $local_dotbot_version != "$dotbot_remote_tag" ]]; then
      echo -n "$dotbot_remote_tag"
    else
      echo -n "$(dotbot_git::get_remote_latest_commit_sha)"
    fi
  else
    dotbot_git::version
  fi
}

dotbot_git::title() {
  echo -n "🤖 dotbot"
}