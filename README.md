# docker_gen_cli.sh

## Overview

`docker_gen_cli.sh` is a comprehensive shell script tool designed to dynamically create `Dockerfile` and `docker-compose.yml` files for your projects. It offers both interactive and non-interactive modes, allowing you to generate Docker configurations tailored to your application's needs effortlessly. The tool is suitable for professional use and includes advanced features like GPU support, multi-stage builds, and secrets management.

---

## Features

- **Interactive User Input**
  - Prompt for project name and directory structure.
  - Select from preconfigured base images or add custom images.
  - Specify ports, environment variables, volumes, and dependencies.

- **Template Support**
  - Use predefined templates for common project types (e.g., Python Flask API, Node.js Express).
  - Save custom configurations as reusable templates.

- **Validation and Error Handling**
  - Validates user inputs (e.g., port ranges, volume paths).
  - Warns about potential conflicts (e.g., overlapping ports).

- **GPU and CUDA Support**
  - Adds NVIDIA-specific labels and environment variables for GPU support with CUDA images.

- **Customizable Service Configurations**
  - Add multiple services with individual configurations.

- **Dynamic File Handling**
  - Detects and includes additional project files (e.g., `static/`, `config/`).
  - Generates a `.dockerignore` file for better caching performance.

- **Production-Ready Features**
  - Configure Docker health checks for services.
  - Manage build contexts and arguments in `docker-compose.yml`.
  - Supports Docker secrets for securely passing sensitive data.
  - Implements multi-stage builds in the `Dockerfile` for optimized image size.

- **Usability Enhancements**
  - Supports CLI arguments for non-interactive usage.
  - Provides output previews and allows interactive editing before saving.
  - Integrates with Git for version control, including `.gitignore` generation.

- **Additional Utilities**
  - Optionally runs `docker-compose up` after file generation.
  - Includes a cleanup option to remove generated Docker images and containers.
  - Extensible with modular functions to easily add new features.

---

## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)
    - [Interactive Mode](#interactive-mode)
    - [Non-Interactive Mode](#non-interactive-mode)
3. [Examples](#examples)
4. [Features Explained](#features-explained)
    - [Templates](#templates)
    - [Secrets Management](#secrets-management)
    - [Multi-Stage Builds](#multi-stage-builds)
    - [GPU and CUDA Support](#gpu-and-cuda-support)
    - [Health Checks](#health-checks)
5. [Extensibility](#extensibility)
6. [Dependencies](#dependencies)
7. [Troubleshooting](#troubleshooting)
8. [Contributing](#contributing)
9. [License](#license)

---

## Installation

### Clone the Repository

```bash
git clone git@github.com:Loke-60000/docker-create.git
cd docker-create
```

### Make the Script Executable

```bash
chmod +x docker_gen_cli.sh
```

### (Optional) Add to PATH

To use the script from anywhere, add it to your PATH.

```bash
export PATH=$PATH:$(pwd)
```

---

## Usage

### Interactive Mode

Run the script without any arguments:

```bash
./docker_gen_cli.sh
```

You will be prompted to provide necessary information, such as project name, base image, ports, environment variables, etc.

### Non-Interactive Mode

Use CLI arguments for automation:

```bash
./docker_gen_cli.sh --project my_project --base python:3.10 --ports 5000,8000 --dependencies flask,requests
```

#### Available CLI Options:

- `--project NAME` : Set the project name.
- `--base IMAGE` : Set the base Docker image.
- `--ports PORTS` : Comma-separated list of ports to expose.
- `--env VARS` : Comma-separated list of environment variables (KEY=VALUE).
- `--volumes VOLUMES` : Comma-separated list of volumes (host_path:container_path).
- `--dependencies DEPS` : Comma-separated list of dependencies.
- `--help` : Display help message.

---

## Examples

### Example 1: Interactive Mode

```bash
./docker_gen_cli.sh
```

Sample Interaction:
```plaintext
Enter the project name:
> my_flask_app
Enter the directory structure (e.g., src/, tests/):
> src/,templates/,static/
...
Do you want to run 'docker-compose up' now? (y/n):
> y
```

### Example 2: Non-Interactive Mode

```bash
./docker_gen_cli.sh --project my_node_app --base node:14 --ports 3000 --dependencies express
```

---

## Features Explained

### Templates

- **Using Templates**: Select a predefined template during the interactive session.
- **Saving Templates**: After configuring your setup, save it as a custom template for future use.

### Secrets Management

- **Using Secrets**: Manage secrets during the setup.
- **Security**: Ensures sensitive data like API keys are securely passed to the containers.

### Multi-Stage Builds

- **Optimization**: Reduces the final image size by building dependencies in intermediate stages.

### GPU and CUDA Support

- **NVIDIA Labels and Environment Variables**: Added when using CUDA images.
- **GPU Support**: Allows containers to access GPU resources.

### Health Checks

- **Configuration**: Set up health check commands for services.
- **Docker Integration**: Adds health check configurations to `docker-compose.yml`.

---

## Extensibility

- **Modular Functions**: Add new features easily by updating modular functions.
- **Base Images and Templates**: Update the list of base images or add new templates.

---

## Dependencies

- **Docker and Docker Compose**: Ensure both are installed and running.
- **Bash Shell**: Compatible with most Unix-like systems.

---

## Troubleshooting

- **Permission Denied**: Ensure the script has execute permissions.

    ```bash
    chmod +x docker_gen_cli.sh
    ```

- **Docker Daemon Not Running**: Start the Docker daemon.
- **Port Conflicts**: Verify that the ports are not already in use.

---

## Contributing

Contributions are welcome! Fork the repository and submit a pull request.

---

## License

This project is licensed under the MIT License.
