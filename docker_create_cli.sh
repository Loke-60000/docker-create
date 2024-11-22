RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_NAME=""
DIRECTORY_STRUCTURE=""
BASE_IMAGE=""
PORTS=""
ENV_VARS=""
VOLUMES=""
DEPENDENCIES=""
SERVICES=()
TEMPLATE=""
HEALTH_CHECK_CMD=""
BUILD_CONTEXT="."
SECRETS=""
MULTI_STAGE=false
RUN_DOCKER=false
CLEANUP_OPTION=false
USE_SECRETS=false
SAVE_TEMPLATE=false
GPU_SUPPORT=false
CONFIGURE_HEALTH=false
EDIT_DOCKERFILE=false
EDIT_DOCKER_COMPOSE=false

usage() {
    echo -e "${CYAN}Usage:${NC} $0 [options]"
    echo -e "${CYAN}Options:${NC}"
    echo -e "  --project NAME             Set the project name"
    echo -e "  --base IMAGE               Set the base Docker image"
    echo -e "  --ports PORTS              Comma-separated list of ports to expose"
    echo -e "  --env VARS                 Comma-separated list of environment variables (KEY=VALUE)"
    echo -e "  --volumes VOLUMES          Comma-separated list of volumes (host_path:container_path)"
    echo -e "  --dependencies DEPS        Comma-separated list of dependencies"
    echo -e "  --help                     Display this help message"
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --project) PROJECT_NAME="$2"; shift ;;
        --base) BASE_IMAGE="$2"; shift ;;
        --ports) PORTS="$2"; shift ;;
        --env) ENV_VARS="$2"; shift ;;
        --volumes) VOLUMES="$2"; shift ;;
        --dependencies) DEPENDENCIES="$2"; shift ;;
        --help) usage; exit 0 ;;
        *) echo -e "${RED}Unknown parameter passed: $1${NC}"; usage; exit 1 ;;
    esac
    shift
done
get_input() {
    local PROMPT=$1
    local VARIABLE_NAME=$2
    local DEFAULT_VALUE=$3
    echo -e "${YELLOW}$PROMPT${NC}"
    read INPUT
    if [ -z "$INPUT" ] && [ -n "$DEFAULT_VALUE" ]; then
        INPUT=$DEFAULT_VALUE
    fi
    eval $VARIABLE_NAME="'$INPUT'"
}

if [ -z "$PROJECT_NAME" ]; then
    get_input "Enter the project name:" PROJECT_NAME
fi

if [ -z "$DIRECTORY_STRUCTURE" ]; then
    get_input "Enter the directory structure (e.g., src/, tests/):" DIRECTORY_STRUCTURE
fi

if [ -z "$BASE_IMAGE" ]; then
    BASE_IMAGES=("python:3.10" "node:14" "nginx" "nvidia/cuda" "Custom")
    echo -e "${YELLOW}Select a base image:${NC}"
    select BI in "${BASE_IMAGES[@]}"; do
        if [ "$BI" == "Custom" ]; then
            get_input "Enter the custom base image:" BASE_IMAGE
            break
        elif [ -n "$BI" ]; then
            BASE_IMAGE=$BI
            break
        else
            echo -e "${RED}Invalid selection.${NC}"
        fi
    done
fi

if [ -z "$PORTS" ]; then
    get_input "Enter ports to expose (comma-separated):" PORTS
fi

if [ -z "$ENV_VARS" ]; then
    get_input "Enter environment variables (KEY=VALUE, comma-separated):" ENV_VARS
fi

if [ -z "$VOLUMES" ]; then
    get_input "Enter volumes to mount (host_path:container_path, comma-separated):" VOLUMES
fi

if [ -z "$DEPENDENCIES" ]; then
    get_input "Enter dependencies (comma-separated):" DEPENDENCIES
fi

if [[ -f "requirements.txt" ]]; then
    DEP_FILE="requirements.txt"
    INSTALL_CMD="pip install -r requirements.txt"
elif [[ -f "package.json" ]]; then
    DEP_FILE="package.json"
    INSTALL_CMD="npm install"
else
    DEP_FILE=""
    INSTALL_CMD=""
fi

if [[ $BASE_IMAGE == *"cuda"* ]]; then
    GPU_SUPPORT=true
    NVIDIA_LABELS='LABEL com.nvidia.volumes.needed="nvidia_driver"'
    NVIDIA_ENV_VARS='ENV NVIDIA_VISIBLE_DEVICES all\nENV NVIDIA_DRIVER_CAPABILITIES compute,utility'
fi

echo -e "${YELLOW}Do you want to add additional services? (y/n):${NC}"
read ADD_SERVICES
if [[ $ADD_SERVICES == "y" ]]; then
    while true; do
        echo -e "${YELLOW}Do you want to add a service? (y/n):${NC}"
        read ADD_SERVICE
        if [[ $ADD_SERVICE == "n" ]]; then
            break
        fi

        get_input "Enter service name:" SERVICE_NAME
        get_input "Enter image for $SERVICE_NAME:" SERVICE_IMAGE
        get_input "Enter ports for $SERVICE_NAME (comma-separated):" SERVICE_PORTS

        SERVICES+=("$SERVICE_NAME|$SERVICE_IMAGE|$SERVICE_PORTS")
    done
fi

TEMPLATES=("Python Flask API" "Node.js Express" "React Frontend" "Custom")
echo -e "${YELLOW}Select a project template:${NC}"
select TEMPLATE_SELECTION in "${TEMPLATES[@]}"; do
    if [ "$TEMPLATE_SELECTION" == "Custom" ]; then
        break
    elif [ -n "$TEMPLATE_SELECTION" ]; then
        TEMPLATE=$TEMPLATE_SELECTION
        echo -e "${GREEN}Template '$TEMPLATE' selected.${NC}"
        break
    else
        echo -e "${RED}Invalid selection.${NC}"
    fi
done

if [ "$TEMPLATE" == "Python Flask API" ]; then
    BASE_IMAGE="python:3.10"
    DEPENDENCIES="flask"
    INSTALL_CMD="pip install flask"
    PORTS="5000"
elif [ "$TEMPLATE" == "Node.js Express" ]; then
    BASE_IMAGE="node:14"
    DEPENDENCIES="express"
    INSTALL_CMD="npm install express"
    PORTS="3000"
elif [ "$TEMPLATE" == "React Frontend" ]; then
    BASE_IMAGE="node:14"
    DEPENDENCIES="create-react-app"
    INSTALL_CMD="npx create-react-app my-app"
    PORTS="3000"
fi

echo -e "${YELLOW}Do you want to save this configuration as a template? (y/n):${NC}"
read SAVE_TEMPLATE
if [[ $SAVE_TEMPLATE == "y" ]]; then
    get_input "Enter a name for the template:" TEMPLATE_NAME
    mkdir -p ~/.docker_gen_cli/templates
    TEMPLATE_FILE="$HOME/.docker_gen_cli/templates/$TEMPLATE_NAME.conf"
    echo "BASE_IMAGE=$BASE_IMAGE" > "$TEMPLATE_FILE"
    echo "DEPENDENCIES=$DEPENDENCIES" >> "$TEMPLATE_FILE"
    echo "PORTS=$PORTS" >> "$TEMPLATE_FILE"
    echo -e "${GREEN}Template saved as '$TEMPLATE_NAME'.${NC}"
fi

IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
for PORT in "${PORT_ARRAY[@]}"; do
    if ! [[ $PORT =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo -e "${RED}Invalid port: $PORT${NC}"
        exit 1
    fi
done

ADDITIONAL_FILES=("static/" "config/")
for FILE in "${ADDITIONAL_FILES[@]}"; do
    if [[ -d $FILE || -f $FILE ]]; then
        echo -e "${GREEN}$FILE will be included in the Docker image.${NC}"
    fi
done

cat > .dockerignore <<EOL
.git
node_modules
*.env
*.pyc
__pycache__/
EOL

echo -e "${YELLOW}Do you want to configure health checks? (y/n):${NC}"
read CONFIGURE_HEALTH
if [[ $CONFIGURE_HEALTH == "y" ]]; then
    get_input "Enter health check command:" HEALTH_CHECK_CMD
fi

get_input "Enter custom build context (leave empty for default '.'): " BUILD_CONTEXT "."

echo -e "${YELLOW}Do you want to use Docker secrets? (y/n):${NC}"
read USE_SECRETS
if [[ $USE_SECRETS == "y" ]]; then
    get_input "Enter secret keys (comma-separated):" SECRETS
fi

echo -e "${YELLOW}Do you want to use multi-stage builds? (y/n):${NC}"
read USE_MULTI_STAGE
if [[ $USE_MULTI_STAGE == "y" ]]; then
    MULTI_STAGE=true
fi

DOCKERFILE_CONTENT=""
if [ "$MULTI_STAGE" == true ]; then
    DOCKERFILE_CONTENT+="FROM $BASE_IMAGE AS builder\n"
    DOCKERFILE_CONTENT+="WORKDIR /app\n"
    DOCKERFILE_CONTENT+="COPY . .\n"
    if [ -n "$INSTALL_CMD" ]; then
        DOCKERFILE_CONTENT+="RUN $INSTALL_CMD\n"
    fi
    DOCKERFILE_CONTENT+="\nFROM $BASE_IMAGE-slim\n"
    DOCKERFILE_CONTENT+="WORKDIR /app\n"
    DOCKERFILE_CONTENT+="COPY --from=builder /app /app\n"
else
    DOCKERFILE_CONTENT+="FROM $BASE_IMAGE\n"
    DOCKERFILE_CONTENT+="WORKDIR /app\n"
    DOCKERFILE_CONTENT+="COPY . .\n"
    if [ -n "$INSTALL_CMD" ]; then
        DOCKERFILE_CONTENT+="RUN $INSTALL_CMD\n"
    fi
fi
if [ "$GPU_SUPPORT" == true ]; then
    DOCKERFILE_CONTENT+="$NVIDIA_LABELS\n"
    DOCKERFILE_CONTENT+="$NVIDIA_ENV_VARS\n"
fi
DOCKERFILE_CONTENT+="CMD [\"your-start-command\"]\n"

echo -e "${CYAN}Dockerfile Preview:${NC}"
echo -e "$DOCKERFILE_CONTENT"
echo -e "${YELLOW}Do you want to edit the Dockerfile before saving? (y/n):${NC}"
read EDIT_DOCKERFILE
if [[ $EDIT_DOCKERFILE == "y" ]]; then
    echo -e "$DOCKERFILE_CONTENT" > Dockerfile.tmp
    ${EDITOR:-nano} Dockerfile.tmp
    DOCKERFILE_CONTENT=$(cat Dockerfile.tmp)
    rm Dockerfile.tmp
fi

echo -e "$DOCKERFILE_CONTENT" > Dockerfile
echo -e "${GREEN}Dockerfile has been generated.${NC}"

DOCKER_COMPOSE_CONTENT="version: '3.8'\nservices:\n  $PROJECT_NAME:\n"
DOCKER_COMPOSE_CONTENT+="    build:\n"
DOCKER_COMPOSE_CONTENT+="      context: $BUILD_CONTEXT\n"
DOCKER_COMPOSE_CONTENT+="    ports:\n"
for PORT in "${PORT_ARRAY[@]}"; do
    DOCKER_COMPOSE_CONTENT+="      - \"$PORT:$PORT\"\n"
done
if [ -n "$ENV_VARS" ]; then
    DOCKER_COMPOSE_CONTENT+="    environment:\n"
    IFS=',' read -ra ENV_ARRAY <<< "$ENV_VARS"
    for ENV in "${ENV_ARRAY[@]}"; do
        DOCKER_COMPOSE_CONTENT+="      - \"$ENV\"\n"
    done
fi
if [ -n "$VOLUMES" ]; then
    DOCKER_COMPOSE_CONTENT+="    volumes:\n"
    IFS=',' read -ra VOLUME_ARRAY <<< "$VOLUMES"
    for VOL in "${VOLUME_ARRAY[@]}"; do
        DOCKER_COMPOSE_CONTENT+="      - $VOL\n"
    done
fi
if [ "$CONFIGURE_HEALTH" == true ]; then
    DOCKER_COMPOSE_CONTENT+="    healthcheck:\n"
    DOCKER_COMPOSE_CONTENT+="      test: \"$HEALTH_CHECK_CMD\"\n"
    DOCKER_COMPOSE_CONTENT+="      interval: 30s\n"
    DOCKER_COMPOSE_CONTENT+="      timeout: 10s\n"
    DOCKER_COMPOSE_CONTENT+="      retries: 3\n"
fi
if [ "$USE_SECRETS" == true ]; then
    DOCKER_COMPOSE_CONTENT+="    secrets:\n"
    IFS=',' read -ra SECRET_ARRAY <<< "$SECRETS"
    for SECRET in "${SECRET_ARRAY[@]}"; do
        DOCKER_COMPOSE_CONTENT+="      - $SECRET\n"
    done
fi

if [ ${#SERVICES[@]} -gt 0 ]; then
    for SERVICE in "${SERVICES[@]}"; do
        IFS='|' read -ra SERVICE_DETAILS <<< "$SERVICE"
        SERVICE_NAME=${SERVICE_DETAILS[0]}
        SERVICE_IMAGE=${SERVICE_DETAILS[1]}
        SERVICE_PORTS=${SERVICE_DETAILS[2]}
        DOCKER_COMPOSE_CONTENT+="  $SERVICE_NAME:\n"
        DOCKER_COMPOSE_CONTENT+="    image: $SERVICE_IMAGE\n"
        if [ -n "$SERVICE_PORTS" ]; then
            DOCKER_COMPOSE_CONTENT+="    ports:\n"
            IFS=',' read -ra SERVICE_PORT_ARRAY <<< "$SERVICE_PORTS"
            for SPORT in "${SERVICE_PORT_ARRAY[@]}"; do
                DOCKER_COMPOSE_CONTENT+="      - \"$SPORT:$SPORT\"\n"
            done
        fi
    done
fi

echo -e "${CYAN}docker-compose.yml Preview:${NC}"
echo -e "$DOCKER_COMPOSE_CONTENT"
echo -e "${YELLOW}Do you want to edit the docker-compose.yml before saving? (y/n):${NC}"
read EDIT_DOCKER_COMPOSE
if [[ $EDIT_DOCKER_COMPOSE == "y" ]]; then
    echo -e "$DOCKER_COMPOSE_CONTENT" > docker-compose.tmp.yml
    ${EDITOR:-nano} docker-compose.tmp.yml
    DOCKER_COMPOSE_CONTENT=$(cat docker-compose.tmp.yml)
    rm docker-compose.tmp.yml
fi

echo -e "$DOCKER_COMPOSE_CONTENT" > docker-compose.yml
echo -e "${GREEN}docker-compose.yml has been generated.${NC}"

if [ ! -d ".git" ]; then
    git init
    echo -e "${GREEN}Git repository initialized.${NC}"
fi

if [ ! -f ".gitignore" ]; then
    cat > .gitignore <<EOL
*.pyc
__pycache__/
.env
Dockerfile
docker-compose.yml
EOL
    echo -e "${GREEN}.gitignore file has been created.${NC}"
fi

echo -e "${YELLOW}Do you want to run 'docker-compose up' now? (y/n):${NC}"
read RUN_DOCKER
if [[ $RUN_DOCKER == "y" ]]; then
    docker-compose up -d
    echo -e "${GREEN}Docker containers are up and running.${NC}"
fi

echo -e "${YELLOW}Do you want to add a cleanup option? (y/n):${NC}"
read ADD_CLEANUP
if [[ $ADD_CLEANUP == "y" ]]; then
    CLEANUP_OPTION=true
fi

if [ "$CLEANUP_OPTION" == true ]; then
    echo -e "${YELLOW}Cleaning up Docker images and containers...${NC}"
    docker-compose down --rmi all
    echo -e "${GREEN}Cleanup completed.${NC}"
fi

echo -e "${GREEN}docker_gen_cli.sh execution completed.${NC}"