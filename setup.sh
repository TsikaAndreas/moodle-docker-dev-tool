#!/bin/bash

# Function to print messages with optional colors
color_echo() {
    local message=$1
    local color_name=${2:-"reset"}

    # Define associative array with color codes
    declare -A colors
    colors=(
        ["red"]="\e[31m"
        ["green"]="\e[32m"
        ["yellow"]="\e[33m"
        ["blue"]="\e[34m"
        ["magenta"]="\e[35m"
        ["cyan"]="\e[36m"
        ["reset"]="\e[0m"
    )

    # Get the color code if color_name is provided and exists in the array
    local color_code=${colors[$color_name]}
    local reset_color=${colors["reset"]}

    # If no valid color_name is provided, don't use any color
    if [ -z "$color_code" ]; then
        echo -e "$message"
    else
        echo -e "${color_code}${message}${reset_color}"
    fi
}

set_directory_permissions() {
    local directory="$1"

    # Add user to www-data group
    sudo usermod -a -G www-data $linux_user
    # Set permissions to 775 for directories
    sudo find $directory -type d -exec chmod 775 {} +
    # Set permissions to 664 for files
    sudo find $directory -type f ! -executable -exec chmod 664 {} +
    # Ensure that any new files or subdirectories created inherit the group of the directory
    sudo chmod g+s $directory
    # Recursively change the group ownership of the directory
    sudo chown -R :www-data $directory

    # Check if ACL package is installed
    if ! dpkg -s acl &> /dev/null
    then
        echo "ACL package is not installed. Installing..."
        # Install ACL package using apt
        sudo apt update
        sudo apt install acl
        color_echo "ACL package installed successfully" "green"
    fi

    # Set the default permissions directory (775 directories & 664 files):
    sudo setfacl -R -d -m "u::rwx,g::rwx,o::rx" $directory

    color_echo "Permissions have been set on $directory." "green"
}

# Function for full development setup
full_development_setup() {
    # Check if $root_project_dir is unset
    if [ -z "$root_project_dir" ]; then
        prompt_root_project_dir
    fi

    # Set direnv files
    direnv_configuration_setup

    # Create the needed directories
    mkdir -p "${root_project_dir}/html"
    mkdir -p "${root_project_dir}/moodledata"
    mkdir -p "${root_project_dir}/dbdata"
    mkdir -p "${root_project_dir}/tools"

    # Clone moodle-docker repository
    git clone https://github.com/moodlehq/moodle-docker.git moodle-docker

    # Check the exit code of the git clone command
    if [ $? -eq 0 ]; then
        color_echo "moodle-docker repository cloned successfully" "green"
    else
        color_echo "Error: Cloning moodle-docker repository failed" "red"
        exit 1
    fi

    # Check if local.yml exists in $script_directory
    if [ -f "$script_directory/local.yml" ]; then
        # Copy local.yml to $root_project_dir/moodle-docker if it exists
        cp "$script_directory/local.yml" "$root_project_dir/moodle-docker/"
        color_echo "local.yml copied successfully" "green"
    else
        # Abort if local.yml doesn't exist
        color_echo "Error: local.yml does not exist in $script_directory. Aborting..." "red"
        exit 1
    fi

    # Check if webserver.dockerfile exists in $script_directory
    if [ -f "$script_directory/webserver.dockerfile" ]; then
        # Copy lwebserver.dockerfile to $root_project_dir/moodle-docker if it exists
        cp "$script_directory/webserver.dockerfile" "$root_project_dir/moodle-docker/"
        color_echo "webserver.dockerfile copied successfully" "green"
    else
        # Abort if webserver.dockerfile doesn't exist
        color_echo "Error: webserver.dockerfile does not exist in $script_directory. Aborting..." "red"
        exit 1
    fi

    # Ask for moodle codebase installation
    prompt_moodle_codebase_installation

    # Check if config.php already exists in $root_project_dir/html
    if [[ ! -f "$root_project_dir/html/config.php" ]]; then
        # Check if config.docker-template.php exists
        if [[ -f "$root_project_dir/moodle-docker/config.docker-template.php" ]]; then
            cp "$root_project_dir/moodle-docker/config.docker-template.php" "$root_project_dir/html/config.php"
            color_echo "config.php copied successfully" "green"
        else
            # Abort if config.docker-template.php doesn't exist
            color_echo "Error: config.docker-template.php does not exist in $root_project_dir/moodle-docker. Aborting..." "red"
            exit 1
        fi
    else
        color_echo "Error: config.php already exists in $root_project_dir/html. Skipping..." "red"
    fi

    # Build and Run the docker containers
    build_docker_containers
}

# Installs the moodle codebase
add_moodle_codebase() {
    local moodle_repo_url="https://github.com/moodle/moodle.git"
    local latest_version
    local version_input
    local version_to_use
    local codebase_type

    # Get latest version
    latest_version=$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --sort='version:refname' --tags "$moodle_repo_url" '*.*.*' | tail --lines=1 | cut --delimiter='/' --fields=3 | sed 's/^v//')

    while true; do
        # Prompt the user for a version name
        color_echo "Enter the version or branch name (default: $latest_version): " "yellow"
        read -r version_input

        if [ -z "$version_input" ]; then
            # Use the latest version
            version_to_use="v$latest_version"
            break
        elif [[ "$version_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # Version in X.Y.Z format
            search_pattern="v$version_input"
        elif [[ "$version_input" =~ ^[0-9]+\.[0-9]+$ ]]; then
            # Version in X.Y format
            search_pattern="v$version_input.*"
        elif [[ "$version_input" =~ ^[0-9]+$ ]]; then
            # Version in X format
            search_pattern="v$version_input.*.*"
        else
            # Check if the input matches a branch name
            branch_exists=$(git ls-remote --exit-code --heads "$moodle_repo_url" "$version_input")

            if [ -n "$branch_exists" ]; then
                # Use the specified branch
                version_to_use="$version_input"
                echo "Using branch: $version_to_use"
                break
            else
                echo "Invalid version format. Please provide a version in the format $latest_version or a valid branch name."
                continue
            fi
        fi

        # Get the latest tag with the specified version
        version_to_use=$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --sort='version:refname' --tags "$moodle_repo_url" "$search_pattern" | tail --lines=1 | cut --delimiter='/' --fields=3)

        if [ -z "$version_to_use" ]; then
            echo "No version found for $version_input. Please try again."
        else
            echo "Using version: $version_to_use"
            break
        fi
    done

    if [ -n "$branch_exists" ]; then
        codebase_type="branch"
    else
        codebase_type="version"
    fi

    # Clone the repository on the specified tag
    git clone --branch "$version_to_use" --depth 1 "$moodle_repo_url" "$root_project_dir/html" && \
    color_echo "Moodle codebase for $codebase_type $version_to_use has been added" "green" || \
    color_echo "Error: Failed to clone Moodle codebase for $codebase_type $version_to_use" "red"
}

add_iomad_codebase() {
    local iomad_repo_url="https://github.com/iomad/iomad.git"
    local latest_stable_branch
    local branch_input
    local branch_to_use
    local codebase_type="branch"

    # Get the latest STABLE branch
    latest_stable_branch=$(git ls-remote --heads "$iomad_repo_url" | grep 'STABLE$' | cut --delimiter='/' --fields=3 | sort -r | head -n 1)

    while true; do
        # Prompt the user for a branch name
        color_echo "Enter the branch name (default: $latest_stable_branch): " "yellow"
        read -r branch_input

        if [ -z "$branch_input" ]; then
            # Use the latest STABLE branch
            branch_to_use="$latest_stable_branch"
            break
        else
            # Check if the input matches a branch with the STABLE suffix
            branch_exists=$(git ls-remote --exit-code --heads "$iomad_repo_url" "$branch_input" | grep 'STABLE$')

            if [ -n "$branch_exists" ]; then
                # Use the specified branch
                branch_to_use="$branch_input"
                echo "Using branch: $branch_to_use"
                break
            else
                echo "Invalid, branch name not found. Please provide a valid branch with the 'STABLE' suffix."
                continue
            fi
        fi
    done

    # Clone the repository on the specified branch
    git clone --branch "$branch_to_use" --depth 1 "$iomad_repo_url" "$root_project_dir/html" && \
    color_echo "IOMAD codebase for branch $branch_to_use has been added" "green" || \
    color_echo "Error: Failed to clone IOMAD codebase for branch $branch_to_use" "red"
}

# Install moodle plugins
moodle_plugins_installation() {
    # Check if $root_project_dir is unset
    if [ -z "$root_project_dir" ]; then
        prompt_root_project_dir
    fi

    check_directory_exists "$root_project_dir/html" || return 1
    check_directory_exists "$root_project_dir/html/local" || return 1

    # If all checks pass, proceed with moodle plugins installation
    echo "Proceeding with moodle plugins installation..."

    # List of Moodle plugins to install
    plugins=(
        "local_codechecker,https://github.com/moodlehq/moodle-local_codechecker.git,local/codechecker"
        "local_moodlecheck,https://github.com/moodlehq/moodle-local_moodlecheck.git,local/moodlecheck"
        "local_mailtest,https://github.com/michael-milette/moodle-local_mailtest.git,local/mailtest"
    )

    # Iterate over the list and clone each plugin
    for plugin in "${plugins[@]}"; do
        IFS=',' read -r plugin_name repo_url install_path <<< "$plugin"
        install_path="$root_project_dir/html/$install_path"
        git_clone_moodle_plugin "$plugin_name" "$repo_url" "$install_path"
    done
}

# Clone the provided moodle plugin
git_clone_moodle_plugin() {
    local plugin_name=$1
    local repo_url=$2
    local install_path=$3

    echo "Installing $plugin_name..."

    if git clone --depth 1 "$repo_url" "$install_path"; then
        color_echo "Plugin $plugin_name was installed." "green"
    else
        color_echo "Error: Plugin $plugin_name was not installed. Skipping..." "red"
    fi
}

# Checks if the provided directory exists
check_directory_exists() {
    local directory=$1

    if [ ! -d "$directory" ]; then
        color_echo "Error: Directory $directory does not exist." "red"
        return 1
    fi
}

# Build and start the docker containers
build_docker_containers() {
    cd "$root_project_dir"
    source "$root_project_dir/set_env_vars.sh"
    direnv allow

    local image_exists=$(docker images -q moodlehq/moodle-php-apache:$moodle_config_php)

    if [ -n "$image_exists" ]; then
        color_echo "Image moodlehq/moodle-php-apache:$moodle_config_php exists. Starting containers." "green"
        moodle-docker/bin/moodle-docker-compose up -d
    else
        color_echo "Image moodlehq/moodle-php-apache:$moodle_config_php does not exist. Building and starting containers." "green"
        moodle-docker/bin/moodle-docker-compose up -d --build
    fi
}

direnv_configuration_setup() {
    # Check if $root_project_dir is unset
    if [ -z "$root_project_dir" ]; then
        prompt_root_project_dir
    fi

    # Check if direnv is installed
    if ! command -v direnv &> /dev/null
    then
        echo "direnv is not installed. Installing..."
        # Install direnv using apt
        sudo apt update
        sudo apt install direnv
        color_echo "direnv package installed successfully" "green"
    fi

    # Ask for the rest moodle config options
    prompt_extra_moodle_config_info

    # Create the set_env_vars.sh file
    generate_moodle_env_variables_file

    # Create the .envrc file
    generate_moodle_envrc_file

    # Add hook to bash config file
    add_direnv_hook

    # Navigate to the moodle project to get the enviroment variables
    cd $root_project_dir

    # Allow direnv process
    direnv allow
}

add_direnv_hook() {
    local shell_config_file_bash=~/.bashrc
    local shell_config_file_zsh=~/.zshrc
    local hook_line_bash='eval "$(direnv hook bash)"'
    local hook_line_zsh='eval "$(direnv hook zsh)"'

    # Check if the bash config file exists before adding the hook line
    if [ -f "$shell_config_file_bash" ]; then
        # Add the hook line to the bash config file if it doesn't already exist
        if ! grep -Fxq "$hook_line_bash" "$shell_config_file_bash"; then
            echo "$hook_line_bash" >> "$shell_config_file_bash"
            echo "Direnv hook added to $shell_config_file_bash"
        else
            echo "Direnv hook already exists in $shell_config_file_bash. Skipping..."
        fi
        # Source the bash config file to apply changes
        source "$shell_config_file_bash"
    else
        echo "Bash config file ($shell_config_file_bash) not found. Skipping..."
    fi

    # Check if the zsh config file exists before adding the hook line
    if [ -f "$shell_config_file_zsh" ]; then
        # Add the hook line to the zsh config file if it doesn't already exist
        if ! grep -Fxq "$hook_line_zsh" "$shell_config_file_zsh"; then
            echo "$hook_line_zsh" >> "$shell_config_file_zsh"
            echo "Direnv hook added to $shell_config_file_zsh"
        else
            echo "Direnv hook already exists in $shell_config_file_zsh. Skipping..."
        fi
        # Source the zsh config file to apply changes
        zsh -c "source $shell_config_file_zsh"
    else
        echo "Zsh config file ($shell_config_file_zsh) not found. Skipping..."
    fi
}

generate_moodle_env_variables_file() {
    # Create set_env_vars.sh file
    cat <<EOF >"${root_project_dir}/set_env_vars.sh"
#!/bin/bash
export MOODLE_DOCKER_ROOT=${root_project_dir}
export MOODLE_DOCKER_WWWROOT=${root_project_dir}/html
export MOODLE_DOCKER_DATAROOT=${root_project_dir}/moodledata
export MOODLE_DOCKER_DBROOT=${root_project_dir}/dbdata
export MOODLE_DOCKER_WEB_HOST=localhost
export MOODLE_DOCKER_DB=$moodle_config_db
export MOODLE_DOCKER_PHP_VERSION=$moodle_config_php
export MOODLE_DOCKER_DB_PORT=$moodle_config_db_port
export MOODLE_DOCKER_WEB_PORT=$moodle_config_web_port
export COMPOSE_PROJECT_NAME=$(basename "$root_project_dir")

# xDebug
export XDEBUG_IDE_KEY=$moodle_config_xdebug_ide_key
export XDEBUG_CLIENT_PORT=9003
EOF

    sudo chmod +x "${root_project_dir}/set_env_vars.sh"
}

generate_moodle_envrc_file() {
    # Create the .envrc file
    cat <<EOF >"${root_project_dir}/.envrc"
cd $root_project_dir
source ${root_project_dir}/set_env_vars.sh
EOF
}

# Function to prompt for directory full path and ensure it exists
prompt_root_project_dir() {
    color_echo "Enter the project absolute path (default: /home/$USER/dev/moodle or ~/dev/moodle): " "yellow"
    read -r root_project_dir
    root_project_dir="${root_project_dir:-$HOME/dev/moodle}"

    eval root_project_dir="$root_project_dir"
    # Check if the directory exists
    if [ -d "$root_project_dir" ]; then
        echo "Using directory: $root_project_dir"
    else
        while true; do
            # If directory doesn't exist, ask user if they want to create it
            read -p "Directory does not exist. Do you want to create it? (yes/no): " create_dir
            case $create_dir in
                [Yy]*)
                    mkdir -p "$root_project_dir"
                    echo "Project directory was created: $root_project_dir"
                    set_directory_permissions "$root_project_dir"
                    echo "Using directory: $root_project_dir"
                    break
                    ;;
                [Nn]*)
                    echo "Process aborted."
                    exit 0
                    ;;
                *)
                    echo "Invalid input. Please enter 'yes' or 'no'."
                    ;;
            esac
        done
    fi
}

prompt_permission_change_directory() {
    local directory_path
    read -p "Enter the directory path for permission change: " directory_path

    # Check if the directory exists
    if [ -d "$directory_path" ]; then
        set_directory_permissions "$directory_path"
    else
        echo "Directory does not exist. Aborting..."
        exit 1
    fi
}

prompt_extra_moodle_config_info() {
    # PHP Version
    read -p "Enter the desired Moodle PHP Version (eg. ..., 7.4, 8.0, 8.1, ...) [default: 8.2]: " moodle_config_php
    moodle_config_php="${moodle_config_php:-8.2}"

    # Database Type
    while true; do
        read -p "Enter your Database type (mariadb, mysql) [default: mariadb]: " moodle_config_db
        moodle_config_db="${moodle_config_db:-mariadb}"

        # Check if the input is either mariadb or mysql
        if [[ "$moodle_config_db" == "mariadb" || "$moodle_config_db" == "mysql" ]]; then
            break  # Exit the loop if the input is valid
        else
            echo "Invalid input. Please enter either 'mariadb' or 'mysql'."
        fi
    done

    # Web Port
    read -p "Enter your Web host Port [default: 8080]: " moodle_config_web_port
    moodle_config_web_port="${moodle_config_web_port:-8080}"

    # Database Port
    read -p "Enter your DB host Port [default: 3306]: " moodle_config_db_port
    moodle_config_db_port="${moodle_config_db_port:-3306}"

    # xDebug IDE Key
    read -p "Enter your xDebug IDE key [default: PHPSTORM]: " moodle_config_xdebug_ide_key
    moodle_config_xdebug_ide_key="${moodle_config_xdebug_ide_key:-PHPSTORM}"
}

prompt_moodle_codebase_installation() {
    # Check if $root_project_dir is unset
    if [ -z "$root_project_dir" ]; then
        prompt_root_project_dir
    fi

    color_echo "Do you want to proceed with Moodle codebase installation?" "yellow"
    echo "Options:"
    echo "0. None (skip)"
    echo "1. Moodle"
    echo "2. IOMAD"

    # Prompt the user for input
    while true; do
        read -rp "Enter your choice [0-2]: " choice

        case "$choice" in
            0)
                echo "Skipping Moodle codebase installation."
                break
                ;;
            1)
                echo "Proceeding with Moodle codebase installation..."
                add_moodle_codebase
                moodle_plugins_installation
                break
                ;;
            2)
                echo "Proceeding with IOMAD codebase installation..."
                add_iomad_codebase
                moodle_plugins_installation
                break
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    done

}

# Script
echo "Welcome to the Moodle Docker Development Tool!"
echo ""
linux_user=$USER
script_directory=$(pwd)

while true; do
    color_echo "Please select an option by entering the corresponding number:" "yellow"
    echo ""
    echo "1. Full Development Setup"
    echo "2. Fix Permissions"
    echo "3. Add Moodle Codebase"
    echo "0. Exit"
    echo ""

    read -p "Enter your choice: " choice

    case $choice in
        0)
            echo "Exiting the Moodle Docker Development Tool."
            exit 0
            ;;
        1)
            echo "Initiating Full Development Setup..."
            full_development_setup
            color_echo "Setup Complete!" "green"
            exit 0
            ;;
        2)
            echo "Starting Permissions Fix..."
            prompt_permission_change_directory
            color_echo "Permissions Fix Complete!" "green"
            exit 0
            ;;
        3)
            echo "Starting Moodle Codebase Addition..."
            prompt_moodle_codebase_installation
            color_echo "Codebase Added Successfully!" "green"
            exit 0
            ;;
        *)
            echo "Invalid selection. Please choose a valid option."
            ;;
    esac
done