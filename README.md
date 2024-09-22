# Project Environment Setup

This repository contains a Bash script to automate the setup of multiple Laravel projects on an Ubuntu server. The script installs necessary dependencies, clones projects from Git, configures Apache virtual hosts, and manages `/etc/hosts` entries.

## Features

- Installs multiple PHP versions (7.0, 8.0, 8.1, 8.2) and necessary extensions.
- Clones projects from specified Git repositories.
- Automatically adds entries to `/etc/hosts` to point project domains to `127.0.0.1`.
- Creates Apache virtual host configurations for each project.
- Sets appropriate permissions and ownership for project directories.

## Prerequisites

Before running the script, ensure you have:

- A Ubuntu server or system.
- `git` installed.
- Basic permissions to execute `sudo` commands.

## Installation

 **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd <repository-folder>
```

Make the script executable:

```bash
chmod +x setup.sh
```

**Modify the script:**

Edit the setup.sh file to include your project details in the projects associative array. The format is:

```bash
["project-name"]="git@github.com:username/repo.git"
```

## Usage
Run the setup script with sudo privileges:

```bash
sudo ./setup.sh
```

## Script Flow
**Dependency Installation:**
- Updates package lists.
- Adds the necessary PPA for PHP versions.
- Install required PHP versions and extensions.
- Installs Apache and enables necessary modules.

**Project Cloning:**

Clones each project specified in the projects array to the `/var/www/` directory.

**Hosts Configuration:**

- Checks if a host entry already exists in `/etc/hosts` to avoid duplicates.
- Adds a new entry for each project if it doesn’t already exist.

**Apache Configuration:**

- Creates a virtual host configuration file for each project.
- Enables the site configuration in Apache.

**Permissions:**

Sets the appropriate file permissions and ownership for each project directory.

**Final Restart:**

Restart Apache to apply all changes.
Troubleshooting
If you encounter issues, please make sure that all commands in the script execute without errors.

Check the `/etc/hosts` file for duplicate entries manually:
```bash
cat /etc/hosts
```

## Troubleshooting
If you encounter issues, please ensure all commands in the script execute without errors.
Check the `/etc/hosts` file for duplicate entries manually:

```bash
cat /etc/hosts
```

