REPO_URL="https://github.com/52Lxcloud/newrelease.git"
PROJECT_DIR="newrelease"
COMPOSE_CMD=""

print_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_error() { echo -e "\033[31m[ERROR]\033[0m $1" >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run with root or sudo privileges to manage Docker."
fi

for cmd in git docker; do
    if ! command -v $cmd &> /dev/null; then
        print_info "$cmd not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            apt-get update >/dev/null
            apt-get install -y git docker.io
        elif command -v yum &> /dev/null; then
            yum install -y git docker
            systemctl start docker && systemctl enable docker
        else
            print_error "Unsupported OS. Please install $cmd manually and re-run."
        fi
        print_success "$cmd has been installed."
    fi
done

if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    print_info "docker compose not found. Attempting to install..."
    if command -v apt-get &> /dev/null; then
        apt-get update >/dev/null
        apt-get install -y docker-compose-plugin || apt-get install -y docker-compose
    elif command -v yum &> /dev/null; then
        yum install -y docker-compose-plugin || yum install -y docker-compose
    else
        print_error "Unsupported OS. Please install docker compose manually and re-run."
    fi

    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        print_error "docker compose installation failed. Please install it manually."
    fi
fi

if [ -d "$PROJECT_DIR" ]; then
    print_info "Project directory found. Pulling latest changes from GitHub..."
    cd "$PROJECT_DIR" && git pull && cd .. || exit
else
    print_info "Cloning repository from GitHub..."
    git clone "$REPO_URL" || print_error "Failed to clone repository."
fi

cd "$PROJECT_DIR" || print_error "Failed to enter project directory."


if [ -f ".env" ]; then
    print_info "Found existing .env file. Skipping credential entry and using the current secrets."
else
    print_info "No .env file found. Please provide your Telegram Bot credentials."
    read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Enter your numeric Telegram User ID (This will be the Admin): " ADMIN_ID

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        print_error "Bot Token cannot be empty and Admin ID must be a valid number. Aborting."
    fi

    print_info "Creating .env file with your secrets..."
    cat << EOF > .env
# This file contains secrets and is loaded by docker-compose.
# It should NOT be committed to Git.

TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
ADMIN_ID=${ADMIN_ID}
EOF
    print_success ".env file created."
fi

print_info "Stopping any old containers to prevent conflicts..."
$COMPOSE_CMD down --remove-orphans

print_info "Building and starting the bot container via docker compose..."
$COMPOSE_CMD up --build -d

if [ "$($COMPOSE_CMD ps -q)" ]; then
    print_success "Deployment complete! Your bot is now running in the background."
    print_info "Your docker-compose.yml from GitHub was used directly."
    print_info "Bot configuration is stored in the './data/bot_configs.json' file."
    echo
    print_info "To view live logs, run this command from the '${PROJECT_DIR}' directory:"
    echo "  $COMPOSE_CMD logs -f"
    echo
    print_info "To stop the bot, run this command from the '${PROJECT_DIR}' directory:"
    echo "  $COMPOSE_CMD down"
else
    print_error "The container failed to start. Check the build logs above or run '$COMPOSE_CMD logs' for details."
fi
