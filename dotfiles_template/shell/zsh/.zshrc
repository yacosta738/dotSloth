# Uncomment for debuf with `zprof`
# zmodload zsh/zprof

###### .Sloth Loader ######
if [[ -f "${SLOTH_PATH:-${DOTLY_PATH:-}}/shell/init-sloth.sh" ]]
then
  #shellcheck disable=SC1091
  . "${SLOTH_PATH:-${DOTLY_PATH:-}}/shell/init-sloth.sh"
else
  echo "\033[0;31m\033[1mSLOTH Loader could not be found, check \$DOTFILES_PATH & \$SLOTH_PATH variables\033[0m"
fi
###### End of .Sloth loader ######
