#!/usr/bin/env bash

set -euxo pipefail

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root!"
  exit 1
fi

# change default settings
timedatectl set-timezone Europe/Amsterdam
timedatectl set-ntp true
hostnamectl set-hostname archvm
localectl set-keymap us
localectl set-locale en_US.UTF-8
