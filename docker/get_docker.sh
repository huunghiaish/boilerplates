#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or use sudo."
    exit 1
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo "Docker is already installed. Version: $(docker --version)"
    exit 0
fi

# Update the package index
echo "Updating package index..."
apt-get update -y || yum update -y || dnf update -y

# Install prerequisites
echo "Installing prerequisites..."
if command -v apt-get &> /dev/null; then
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
elif command -v yum &> /dev/null; then
    yum install -y yum-utils device-mapper-persistent-data lvm2
elif command -v dnf &> /dev/null; then
    dnf install -y dnf-plugins-core
else
    echo "Unsupported package manager. Exiting."
    exit 1
fi

# Add Docker's official GPG key and repository
echo "Adding Docker's GPG key and repository..."
if command -v apt-get &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
fi

# Install Docker
echo "Installing Docker..."
if command -v apt-get &> /dev/null; then
    apt-get install -y docker-ce docker-ce-cli containerd.io
elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
    yum install -y docker-ce docker-ce-cli containerd.io || dnf install -y docker-ce docker-ce-cli containerd.io
fi

# Enable and start Docker
echo "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

# Verify installation
if command -v docker &> /dev/null; then
    echo "Docker installed successfully!"
    docker --version
else
    echo "Docker installation failed."
    exit 1
fi
