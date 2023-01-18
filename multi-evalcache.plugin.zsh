#!/usr/bin/env zsh
# Inspired by https://github.com/mroth/evalcache

# default cache directory
export ZSH_MULTI_EVALCACHE_DIR=${ZSH_MULTI_EVALCACHE_DIR:-"$HOME/.zsh-multi-evalcache"}

function _multi_ec_start() {
  [ "$ZSH_EVALCACHE_DISABLE" = "true" ] && return 0
  local cacheFile="$ZSH_MULTI_EVALCACHE_DIR/init-${1##*/}.zsh"

  [ -d "$ZSH_MULTI_EVALCACHE_DIR" ] && mkdir -p "$ZSH_MULTI_EVALCACHE_DIR"
  printf "%s\n" "#!/usr/bin/env zsh" >>"$cacheFile"
}

# Usage: __single_ec <cache file> <id string> <command> <arguments ...>
function __single_ec() {
  local cacheFile="$1"
  local idString="$2"
  shift 2

  (echo >&2 "$1 initialization not fully cached, caching output of: $*")
  echo "$idString" >>"$cacheFile"
  "$@" >>"$cacheFile"
}

# Usage: __single_ec <command> <arguments ...>
function _multi_ec() {
  local cacheFile="$ZSH_MULTI_EVALCACHE_DIR/init-${1##*/}.zsh"
  local idString="# $*"

  if [ "$ZSH_EVALCACHE_DISABLE" = "true" ]; then
    eval "$("$@")"
  else
    if type "$1" >/dev/null; then
      # Check if the temp cache file exists
      if [ ! -f "$cacheFile" ]; then
        (echo >&2 "multi-evalcache ERROR: _multi_ec_start was not called for $1, eval '$*' not cached")
        return 1
      fi
      # Return immediately if the eval is already in the full cache file
      if [ $(/usr/bin/grep -c "\b$idString\b" "$cacheFile") -gt 0 ]; then
        return 0
      fi
      __single_ec "$cacheFile" "$idString" "$@"
    else
      echo "multi-evalcache ERROR: $1 is not installed or in PATH"
      return 1
    fi
  fi
}

function _multi_ec_end() {
  [ "$ZSH_EVALCACHE_DISABLE" = "true" ] && return 0
  local cacheFile="$ZSH_MULTI_EVALCACHE_DIR/init-${1##*/}.zsh"

  [ -s "$cacheFile" ] && source "$cacheFile" || echo "Could not source $cacheFile"
}

function _multi_ec_clear() {
  local OPTIND o force
  while getopts ":f" o; do
    case "${o}" in
    f)
      force=true
      ;;
    *)
      force=false
      ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ "$force" = true ]; then
    rm -f "$ZSH_MULTI_EVALCACHE_DIR"/init-*.zsh
  else
    rm -i "$ZSH_MULTI_EVALCACHE_DIR"/init-*.zsh
  fi
}

# Interop function to maintain backwards compat with evalcache
# Usage: _evalcache <command> <arguments ...>
function _evalcache() {
  local cacheFile="$ZSH_MULTI_EVALCACHE_DIR/init-${1##*/}.zsh"
  local ecRes

  if [ "$ZSH_EVALCACHE_DISABLE" = "true" ]; then
    eval "$("$@")"
  else
    if type "$1" >/dev/null; then
      mkdir -p "$ZSH_MULTI_EVALCACHE_DIR"
      if [ ! -f "$cacheFile" ]; then
        printf "%s\n" "#!/usr/bin/env zsh" >>"$cacheFile"
        __single_ec "$cacheFile" "# $*" "$@" || ecRes=1
        ecRes=$?
      fi
    else
      echo "multi-evalcache ERROR: $1 is not installed or in PATH"
    fi

    if [ "$ecRes" -eq 0 ]; then
      [ -s "$cacheFile" ] && source "$cacheFile" || echo "Could not source $cacheFile"
    fi
  fi
}

# As above, backwards compat function
function _evalcache_clear() {
  _multi_ec_clear "$@"
}
