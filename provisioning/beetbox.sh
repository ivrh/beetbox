#!/bin/bash -eu

# Set default environment variables.
ANSIBLE_VERSION=${ANSIBLE_VERSION:-"2.0.0.2"}
BEET_HOME=${BEET_HOME:-"/beetbox"}
BEET_BASE=${BEET_BASE:-"/var/beetbox"}
BEET_USER=${BEET_USER:-"vagrant"}
BEET_REPO=${BEET_REPO:-"https://github.com/beetboxvm/beetbox.git"}
BEET_VERSION=${BEET_VERSION:-"master"}
BEET_TAG=${BEET_TAG:-""}
BEET_DEBUG=${BEET_DEBUG:-false}
CIRCLECI=${CIRCLECI:-false}
ANSIBLE_HOME="$BEET_HOME/provisioning/ansible"
ANSIBLE_DEBUG=""

# Ansible config.
export DISPLAY_SKIPPED_HOSTS=${DISPLAY_SKIPPED_HOSTS:-False}
export ANSIBLE_DEPRECATION_WARNINGS=${ANSIBLE_DEPRECATION_WARNINGS:-False}
export ANSIBLE_REMOTE_TEMP=${ANSIBLE_REMOTE_TEMP:-/tmp}

# Enable debug mode?
if [ $BEET_DEBUG = "true" ]; then
  set -x
  DEPRECATION_WARNINGS=True
  ANSIBLE_DEBUG="-vvv"
fi

beetbox_setup()
{
  # Remove default circle CI packages.
  if [ "$CIRCLECI" == "true" ]; then
    echo "Removing default circle CI packages"
    sudo apt-get -qq update
    sudo apt-get -y purge apache2 php5-cli mysql-common mysql-server mysql-common
    sudo apt-get -y autoremove
    sudo apt-get -y autoclean
    sudo rm -rf /etc/apache2/mods-enabled/*
    sudo rm -rf /var/lib/mysql
  fi

  # Install ansible.
  sudo apt-get -y install python-pip python-dev
  sudo -H pip install ansible==$ANSIBLE_VERSION

  # Clone beetbox if BEET_HOME doesn't exist.
  if [ ! -d "$BEET_HOME" ]; then
    sudo apt-get -y install git
    sudo mkdir -p $BEET_HOME
    sudo chown -R $BEET_USER:$BEET_USER $BEET_HOME
    echo "==> Checking out beetbox from $BEET_REPO"
    git clone $BEET_REPO $BEET_HOME
    [ ! -d "$BEET_HOME" ] && exit 1
  fi

  # Check version.
  beetbox_play config && beetbox_play update

  # Packer setup.
  beetbox_play packer

  # Create $BEET_HOME/.beetbox_installed
  touch $BEET_HOME/.beetbox/installed
}

beetbox_play()
{
  ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ansible-playbook $ANSIBLE_DEBUG "$ANSIBLE_HOME/playbook-$1.yml" -i 'localhost,'
}

# Initialise beetbox.
[ ! -f "$BEET_HOME/.beetbox/installed" ] && beetbox_setup

# Create default config files.
beetbox_play config

# Check for updates.
beetbox_play update

# Install ansible galaxy roles.
beetbox_play roles

# Provision VM.
beetbox_play provision

# Run tests on Circle CI.
[ "$CIRCLECI" == "true" ] && beetbox_play tests

# Print welcome message.
touch ~/welcome.txt
cat ~/welcome.txt
