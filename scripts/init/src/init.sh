#!/usr/bin/env bash

if [[ -z "${DOTFILES_PATH:-}" ]]; then
  output::error "DOTFILES_PATH is not set"
  exit 4
fi

# PR annotation
# If you change this folders you should also change them in init-dotly.sh
SLOTH_INIT_SCRIPTS_PATH="${SLOTH_PATH:-${DOTLY_PATH:-}}/shell/init.scripts"
DOTFILES_INIT_SCRIPTS_PATH="${DOTFILES_INIT_SCRIPTS_PATH:-$DOTFILES_PATH/shell/init.scripts}"
ENABLED_INIT_SCRIPTS_PATH="${ENABLED_INIT_SCRIPTS_PATH:-$DOTFILES_PATH/shell/init.scripts-enabled}"

[[ ! -d "$ENABLED_INIT_SCRIPTS_PATH" ]] &&
  output::error "The folder path to enable scripts does not exists." &&
  output::write "If you want to disble init script add in your exports \`export SLOTH_INIT_SCRIPTS=false\` " &&
  output::write "If you want to enable. Execute \`dot self migration v2.0.0\` first." &&
  exit 1

[[ ! -d "$SLOTH_INIT_SCRIPTS_PATH" ]] &&
  output::error "The init scripts of .Sloth does not exists." &&
  output::write "Try with \`dot self migration v2.0.0\` first." &&
  exit 1

init::exists_script() {
  [[ -e "$SLOTH_INIT_SCRIPTS_PATH/$1" ]] || [[ -e "$DOTFILES_INIT_SCRIPTS_PATH" ]]
}

init::status() {
  init::exists_script "$1" && [[ -f "$ENABLED_INIT_SCRIPTS_PATH/$1" ]]
}

init::get_scripts() {
  [[ -d "$SLOTH_INIT_SCRIPTS_PATH" ]] &&
    [[ -d "$DOTFILES_INIT_SCRIPTS_PATH" ]] &&
    find "$SLOTH_INIT_SCRIPTS_PATH" \
      "$DOTFILES_INIT_SCRIPTS_PATH" -name "*" -type f,l -print0 -exec echo {} \; |
    xargs -0 -I _ basename _ | sort | uniq
}

init::get_enabled() {
  [[ -d "$ENABLED_INIT_SCRIPTS_PATH" ]] &&
    find "$ENABLED_INIT_SCRIPTS_PATH" -name "*" -type l -print0 -exec echo {} \; |
    xargs -0 -I _ basename _ | sort | uniq
}

init::fzf() {
  local piped_values preview_cmd
  piped_values="$(< /dev/stdin)"

  preview_cmd=("echo 'Press Tab+Shift to select multiple options.\nPress Ctrl+C to exit with no selection.\n--\n';")
  preview_cmd+=("{ [[ -f \"$SLOTH_INIT_SCRIPTS_PATH/\$(echo {})\" ]] && cat \"$SLOTH_INIT_SCRIPTS_PATH/\$(echo {})\"; } ||")
  preview_cmd+=("{ [[ -f \"$DOTFILES_INIT_SCRIPTS_PATH/\$(echo {})\" ]] && cat \"$DOTFILES_INIT_SCRIPTS_PATH/\$(echo {})\"; } || ")
  preview_cmd+=("echo 'Init script not found'")

  printf "%s\n" "${piped_values[@]}" | fzf -m --extended \
    --header "$1" \
    --preview "${preview_cmd[*]}"
}

init::enable() {
  local sloth_init_path dotfiles_init_path to item status=0
  sloth_init_path="$SLOTH_INIT_SCRIPTS_PATH"
  dotfiles_init_path="$DOTFILES_INIT_SCRIPTS_PATH"
  to="$ENABLED_INIT_SCRIPTS_PATH"

  for item in "$@"; do
    if
      [[ -e "$sloth_init_path/$item" ]] &&
        [[ ! -e "$to/$item" ]]
    then
      rm -f "$to/$item" &&
        ln -s "$sloth_init_path/$item" "$to/"
      continue
    fi

    if
      [[ -e "$dotfiles_init_path/$item" ]] &&
        [[ ! -e "$to/$item" ]]
    then
      rm -f "$to/$item" &&
        ln -s "$dotfiles_init_path/$item" "$to/"
      continue
    fi

    status=1
  done

  return $status
}

init::disable() {
  local enabled_path item status=0
  enabled_path="$ENABLED_INIT_SCRIPTS_PATH"

  for item in "$@"; do
    if [[ -e "$enabled_path/$item" ]]; then
      rm -f "$enabled_path/$item"
    else
      status=1
    fi
  done

  return $status
}
