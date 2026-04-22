
CURRENT_GIT_VERSION=""

function current-git-version() {
  if [ -z "$CURRENT_GIT_VERSION" ]; then
    local homepage
    homepage=$(curl -fsSL https://git-scm.com/ 2>/dev/null)
    CURRENT_GIT_VERSION=$(printf '%s' "$homepage" | grep -oE '<span class="version">[0-9]+\.[0-9]+\.[0-9]+</span>' | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ -z "$CURRENT_GIT_VERSION" ]; then
      CURRENT_GIT_VERSION=$(printf '%s' "$homepage" | grep -oE 'RelNotes/[0-9]+\.[0-9]+\.[0-9]+\.adoc' | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
  fi
  echo "$CURRENT_GIT_VERSION"
}

function do-make() {
  make OSX_VERSION=${OSX_VERSION:-10.13} VERSION=${GIT_VERSION:-$(current-git-version)} "${@}"
}

