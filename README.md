# 🛠️ Moodle Docker Development Tool

This repository contains a bash script designed to simplify the setup and management of a Moodle development environment using Docker. The script automates the installation, configuration, and permissions setup required for running Moodle within a Dockerized environment.

Key features include:

- **Full Development Setup:** Automates the creation of project directories, cloning of the Moodle Docker repository, copying necessary configuration files, and setting up environment variables using `direnv`.

- **Permission Management:** Ensures proper file and directory permissions for the Moodle project, setting defaults that work seamlessly with the `www-data` group used by web servers.

- **Moodle Codebase Management:** Automatically clones a specific version or branch of the Moodle codebase and installs popular plugins like Codechecker, Moodlecheck, and Mailtest by default.

- **Docker Integration:** Handles the building and running of Docker containers for Moodle, including options for customizing PHP versions and database configurations.

## 📋 Contents

- `local.yml`: YAML configuration file defining the local environment's dependencies.
- `webserver.dockerfile`: Dockerfile for configuring the web server container.
- `setup.sh`: Shell script that orchestrates the entire Docker environment setup process.

## 💻 Usage

### 1. Prerequisites

Before you begin, ensure that you have the following installed and configured on your system:

- Docker Desktop. If you don't have it, you can download it [here](https://www.docker.com/products/docker-desktop).

- [WSL 2 (Windows Subsystem for Linux)](https://docs.microsoft.com/en-us/windows/wsl/install-win10) enabled and properly set up on your Windows system. If not, follow the instructions [here](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

### 2. Quick Installation

Follow these steps to set up your Moodle Docker development environment quickly:

> **_NOTICE:_** The setup script does not include the Moodle codebase within the `html` directory. You will need to add the Moodle codebase manually after running the script.

### 1. Clone the Repository

Clone this repository into your WSL environment, preferably inside the `/home/$USER` directory:

```bash
git clone https://github.com/TsikaAndreas/moodle-docker-dev-tool.git
```

### 2. Navigate to the Project Directory

Change to the `moodle-docker-dev-tool` directory:

```bash
cd moodle-docker-dev-tool
```

### 3. Set Permissions

Grant executable permissions to the `setup.sh` script:

```bash
chmod +x setup.sh
```

### 4. Run the Setup Script

Execute the `setup.sh` script and follow the on-screen instructions to complete the setup:

```bash
./setup.sh
```

## 👨‍💻 Author

This project was created by Andrei-Robert Tsika. You can find me on:

- **Github:** [TsikaAndreas](https://github.com/TsikaAndreas)
- **LinkedIn:** [tsika](https://www.linkedin.com/in/tsika/)

## 🤝 Contributing

Contributions to this repository are welcome! If you have suggestions for improvements, bug fixes, or new features, please feel free to submit a pull request or open an issue.

To contribute:

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Make your changes and commit them with clear messages.
4. Push your changes to your fork.
5. Open a pull request with a description of your changes.

## ⚠️ Reporting Issues

If you encounter any problems or have questions about the tool, please open an issue on the [GitHub Issues page](https://github.com/TsikaAndreas/moodle-docker-dev-tool/issues). When reporting an issue, please provide the following information to help us assist you better:

- A clear and descriptive title.
- Detailed description of the issue, including steps to reproduce if applicable.
- Any error messages.
- Your operating system and Docker version.

<br>

**Thank you for your feedback and support!**
