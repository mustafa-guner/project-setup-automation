#!/bin/bash

# Base directory for the projects
base_dir="/var/www/"

# Install all the required dependencies
install_dependencies() {
  echo "Updating package list..."
  sudo apt update

  echo "Adding PHP PPA repository for multiple PHP versions..."
  sudo add-apt-repository -y ppa:ondrej/php
  sudo apt update

  echo "Installing grep..."
  sudo apt install -y grep

  echo "Installing PHP versions and FPM modules..."
  sudo apt install -y \
    php7.0 php7.0-fpm php7.0-mbstring php7.0-xml php7.0-zip php7.0-curl \
    php8.0 php8.0-fpm php8.0-mbstring php8.0-xml php8.0-zip php8.0-curl \
    php8.1 php8.1-fpm php8.1-mbstring php8.1-xml php8.1-zip php8.1-curl \
    php8.2 php8.2-fpm php8.2-mbstring php8.2-xml php8.2-zip php8.2-curl

  echo "Installing additional required dependencies (MySQL, Apache modules)..."
  sudo apt install -y apache2 libapache2-mod-fcgid

  echo "Enabling FPM module for Apache..."
  sudo a2enmod proxy_fcgi setenvif

  echo "Restarting Apache..."
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
  echo "Cloning $project from $git_repo_url..."
  git clone "$git_repo_url" "$base_dir/$project"

  # Check if the host entry already exists
  echo "Checking if $project is already in /etc/hosts..."
  if ! check_host_exists "$project"; then
    # Add project to /etc/hosts if not already added
    echo "Adding $project to /etc/hosts..."
    echo "127.0.0.1 $project.test" | sudo tee -a /etc/hosts
  else
    echo "$project is already in /etc/hosts. Skipping..."
  fi

  # Create symbolic link for the project
  echo "Creating symbolic link for the project..."
  sudo ln -s "$base_dir/$project/public" "/var/www/html/$project"

  # Get PHP version dynamically from composer.json
  php_version=$(get_php_version_from_composer "$base_dir/$project")

  # Create Apache Virtual Host Configuration
  echo "Creating Apache config for $project..."
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
  echo "Enabling $project site in Apache..."
  sudo a2ensite "$project"

  # Set file permissions and ownership
  echo "Setting file permissions and ownership for $project..."
  sudo chmod -R 775 "$base_dir/$project"
  sudo chown -R www-data:"$current_user" "$base_dir/$project"

  # Set the git config as global
  git config --global --add safe.directory "$base_dir/$project"

  # Set the core files for git config
  git config core.fileMode false

done

# Restart Apache after enabling the sites
sudo systemctl restart apache2

echo "All projects have been set up!"
