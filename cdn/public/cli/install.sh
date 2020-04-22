#!/bin/sh
set -o errexit

# GitHub's URL for the latest release, will redirect.
DESTDIR="${DESTDIR:-/usr/local/bin}"
INSTALL_PATH="${DESTDIR}/apollo"

error_exit() {
	echo "$1" 1>&2
	exit 1
}

check_environment_readiness() {
  if [ -z "$(command -v curl)" ]; then
    echo "The curl command is not installed on this machine. Please install curl before installing the Apollo CLI"
    return 1
  fi

  if [ -z "$(command -v tar)" ]; then
    echo "The tar command is not installed on this machine. Please install tar before installing the Apollo CLI"
    return 1
  fi

  if ! [ -d "$DESTDIR" ]; then
    echo "Attempting to install the Apollo CLI in $DESTDIR but that directory wasn't found on your filesystem. Please create a directory by using mkdir $DESTDIR or specify a DESTDIR variable when running the installer"
    return 1
  fi

  if ! [ -w "$DESTDIR" ]; then
    echo "Attempting to install the Apollo CLI in $DESTDIR but the permissions deny writing to that directory."
    return 1
  fi

  EXISTING_APOLLO="$(command -v apollo)"
  if [ -n "$EXISTING_APOLLO" ]; then
    echo "An existing version of 'apollo' is already installed at $EXISTING_APOLLO. If you want the latest version, please uninstall the old one first then run this again."
    return 1
  fi

  return
}

download_and_install() {
  # Determine release filename. This can be expanded with CPU arch in the future.
  if [ "$(uname)" = "Linux" ]; then
    OS="linux"
  elif [ "$(uname)" = "Darwin" ]; then
    OS="darwin"
  else
    echo "This operating system ('$(uname)') is not supported."
    return 1
  fi

  download_from_proxy || fallback_and_download_from_github

  if ! [ -e "./apollo" ] ; then
    echo "After installing the CLI tarball we were unable to find the apollo binary"
    return 1
  fi

  mv apollo "$DESTDIR"
  chmod +x "$INSTALL_PATH"

  command -v apollo

  return
}

download_from_proxy() {
  RELEASE_URL="https://install.apollographql.workers.dev/cli/${OS}/${VERSION}"
  # Download & unpack the release tarball.
  curl -sL --retry 3 "${RELEASE_URL}" | tar zx --strip 1
}

fallback_and_download_from_github() {
  
  echo "Could not install from the Apollo CDN, falling back to GitHub installation"

  if [ -z "$(command -v cut)" ]; then
    echo "The cut command is not installed on this machine. Please install cut before installing the Apollo CLI"
    return 1
  fi

  # GitHub's URL for the latest release, will redirect.
  LATEST_URL="https://github.com/apollographql/apollo-cli/releases/latest/"
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -sLI -o /dev/null -w '%{url_effective}' $LATEST_URL | cut -d "v" -f 2)
  fi

  RELEASE_URL="https://github.com/apollographql/apollo-cli/releases/download/v${VERSION}/apollo-v${VERSION}-x86_64-${OS}.tar.gz"

  # Download & unpack the release tarball.
  curl -sL --retry 3 "${RELEASE_URL}" | tar zx --strip 1
}

run_main() {
  echo "Installing Apollo CLI..."

  check_environment_readiness || error_exit "Environment setup failed!"

   # Run the script in a temporary directory that we know is empty.
  SCRATCH="$(mktemp -d || mktemp -d -t 'tmp')"
  cd "$SCRATCH"

  download_and_install || error_exit "An error occured installing the tool. The contents of the directory $SCRATCH have been left in place to help to debug the issue."

  # Delete the working directory when the install was successful.
  rm -r "$SCRATCH"

  echo "Apollo CLI was successfully installed!"

  return
}

# if we aren't in our testing framework, run the main installer
if [ -z $BATS_RUNNING ] ; then
  run_main
fi

