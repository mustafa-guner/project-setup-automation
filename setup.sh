#!/bin/bash

# Base directory for the projects
base_dir="/var/www/"

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Function to print colored messages
print_message() {
  echo -e "${1}${2}${RESET}"
}

# Install all the required dependencies
install_dependencies() {
  print_message $BLUE "Updating package list..."
  sudo apt update

  print_message $BLUE "Adding PHP PPA repository for multiple PHP versions..."
  sudo add-apt-repository -y ppa:ondrej/php
  sudo apt update

  print_message $BLUE "Installing grep..."
  sudo apt install -y grep

  print_message $BLUE "Installing PHP versions and FPM modules..."
  sudo apt install -y \
    php5.6 php5.6-cli php5.6-common php5.6-curl php5.6-fpm php5.6-gd \
    php5.6-json php5.6-mbstring php5.6-mcrypt php5.6-mysql php5.6-opcache \
    php5.6-readline php5.6-soap php5.6-xml php5.6-zip \
    php7.0 php7.0-cli php7.0-common php7.0-curl php7.0-fpm php7.0-gd \
    php7.0-json php7.0-ldap php7.0-mbstring php7.0-mysql php7.0-opcache \
    php7.0-readline php7.0-soap php7.0-xml php7.0-xmlrpc php7.0-zip \
    php7.1 php7.1-cli php7.1-common php7.1-curl php7.1-fpm php7.1-gd \
    php7.1-json php7.1-mbstring php7.1-mysql php7.1-opcache php7.1-readline \
    php7.1-xml php7.4 php7.4-cli php7.4-common php7.4-curl php7.4-fpm \
    php7.4-gd php7.4-json php7.4-mbstring php7.4-mysql php7.4-opcache \
    php7.4-readline php7.4-xml php8.0 php8.0-cli php8.0-common php8.0-curl \
    php8.0-fpm php8.0-gd php8.0-mailparse php8.0-mbstring php8.0-mysql \
    php8.0-opcache php8.0-readline php8.0-xml php8.0-zip \
    php8.1 php8.1-cli php8.1-common php8.1-curl php8.1-fpm php8.1-gd \
    php8.1-mbstring php8.1-mysql php8.1-opcache php8.1-readline php8.1-uopz \
    php8.1-xml php8.1-zip php8.2 php8.2-bcmath php8.2-cli php8.2-common \
    php8.2-curl php8.2-fpm php8.2-gd php8.2-imagick php8.2-imap \
    php8.2-intl php8.2-ldap php8.2-mbstring php8.2-mysql php8.2-opcache \
    php8.2-readline php8.2-tidy php8.2-xml php8.2-xmlrpc php8.2-zip \
    php8.3 php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-mbstring \
    php8.3-opcache php8.3-phpdbg php8.3-readline php8.3-xdebug php8.3-xml

  print_message $BLUE "Installing additional required dependencies (MySQL, Apache modules)..."
  sudo apt install -y apache2 libapache2-mod-fcgid

  print_message $BLUE "Enabling FPM module for Apache..."
  sudo a2enmod proxy_fcgi setenvif

  print_message $BLUE "Restarting Apache..."
  sudo systemctl restart apache2
}

# Function to get PHP version from composer.json
get_php_version_from_composer() {
  project_dir=$1
  composer_file="$project_dir/composer.json"

  # Extract the PHP version requirement from composer.json
  php_version=$(eval "grep -Po '\"php\": *\"[\^~]?\K[0-9.]+' \"$composer_file\"")
  echo "$php_version"
}

# Function to check if a host entry already exists
check_host_exists() {
  local project_name=$1
  if grep -q "127.0.0.1[[:space:]]$project_name.test" /etc/hosts; then
    return 0 # Host entry exists
  else
    return 1 # Host entry does not exist
  fi
}

# Array of projects (project name -> Git repo)
declare -A projects=(
  ["APP_NAME"]="GITLINK"
)

# Install required dependencies
install_dependencies

# Get the username of the current user
current_user=$(whoami)

# Loop through each project and perform operations
for project in "${!projects[@]}"; do
  git_repo_url="${projects[$project]}"

  # Clone project into /var/www/
  print_message $BLUE "Cloning $project from $git_repo_url..."
  git clone "$git_repo_url" "$base_dir/$project"

  # Check if the host entry already exists
  print_message $BLUE "Checking if $project is already in /etc/hosts..."
  if ! check_host_exists "$project"; then
    # Add project to /etc/hosts if not already added
    print_message $BLUE "Adding $project to /etc/hosts..."
    print_message $GREEN "127.0.0.1 $project.test" | sudo tee -a /etc/hosts
  else
    print_message $YELLOW "$project is already in /etc/hosts. Skipping..."
  fi

  # Create symbolic link for the project
  print_message $BLUE "Creating symbolic link for the project..."
  sudo ln -s "$base_dir/$project/public" "/var/www/html/$project"

  # Get PHP version dynamically from composer.json
  php_version=$(get_php_version_from_composer "$base_dir/$project")

  # Create Apache Virtual Host Configuration
  print_message $BLUE "Creating Apache config for $project..."
  sudo bash -c "cat > /etc/apache2/sites-available/$project.conf <<EOF
<VirtualHost *:80>
    ServerName $project.test
    DocumentRoot $base_dir/$project/public

    <Directory $base_dir/$project/public>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$project-error.log
    CustomLog \${APACHE_LOG_DIR}/$project-access.log combined

    <FilesMatch \.php$>
        SetHandler \"proxy:unix:/run/php/php$php_version-fpm.sock|fcgi://localhost/\"
    </FilesMatch>
</VirtualHost>
EOF"

  # Enable the site
  print_message $BLUE "Enabling $project site in Apache..."
  sudo a2ensite "$project"

  # Set file permissions and ownership
  print_message $BLUE "Setting file permissions and ownership for $project..."
  sudo chmod -R 775 "$base_dir/$project"
  sudo chown -R www-data:"$current_user" "$base_dir/$project"

  print_message $BLUE "Global git configs are being set for the project..."
  # Set the git config as global
  git config --global --add safe.directory "$base_dir/$project"

  # Set the core files for git config
  git config core.fileMode false

done

# Restart Apache after enabling the sites
print_message $GREEN "Restarting the apache2..."
sudo systemctl reload apache2

print_message $GREEN "All projects have been set up!"
