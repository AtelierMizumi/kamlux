#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Kamlux Installation Script                       ║"
    echo "║        Auto Brightness for KDE Plasma                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_dependencies() {
    print_header
    
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    local missing=()
    
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    if ! command -v v4l2-ctl &> /dev/null; then
        missing+=("v4l-utils")
    fi
    
    if ! command -v qdbus &> /dev/null; then
        missing+=("qtchooser (for qdbus)")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        print_warning "Missing dependencies:"
        for pkg in "${missing[@]}"; do
            echo "  - $pkg"
        done
        echo ""
        print_info "Install with: sudo pacman -S ${missing[*]}"
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "All dependencies found"
    fi
    
    echo ""
}

get_install_dir() {
    local default_dir="$HOME/.local/share/kamlux"
    echo -e "${YELLOW}Installation directory [default: $default_dir]:${NC}"
    read -r INSTALL_DIR
    if [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$default_dir"
    fi
}

get_config_dir() {
    local default_dir="$HOME/.config/kamlux"
    echo -e "${YELLOW}Config directory [default: $default_dir]:${NC}"
    read -r CONFIG_DIR
    if [ -z "$CONFIG_DIR" ]; then
        CONFIG_DIR="$default_dir"
    fi
}

configure_options() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}                    Configuration Options                       ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Target brightness
    echo -e "${YELLOW}Target brightness for well-lit room (0-100) [default: 80]:${NC}"
    read -r target_brightness
    if [ -z "$target_brightness" ]; then
        target_brightness=80
    fi
    
    # Check interval
    echo -e "${YELLOW}Check interval in seconds [default: 10]:${NC}"
    read -r interval
    if [ -z "$interval" ]; then
        interval=10
    fi
    
    # Smoothing alpha
    echo -e "${YELLOW}Smoothing alpha (0.1-1.0, higher = faster response) [default: 0.8]:${NC}"
    read -r alpha
    if [ -z "$alpha" ]; then
        alpha=0.8
    fi
    
    # Camera device
    echo -e "${YELLOW}Camera device [default: /dev/video0]:${NC}"
    read -r device
    if [ -z "$device" ]; then
        device="/dev/video0"
    fi
    
    # Override cooldown
    echo -e "${YELLOW}Manual override cooldown (minutes) [default: 30]:${NC}"
    read -r cooldown
    if [ -z "$cooldown" ]; then
        cooldown=30
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo "  Target brightness: $target_brightness%"
    echo "  Check interval: ${interval}s"
    echo "  Smoothing alpha: $alpha"
    echo "  Camera device: $device"
    echo "  Override cooldown: ${cooldown} minutes"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Proceed with installation? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0
    fi
}

install_files() {
    print_info "Installing files..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Copy main script
    cp src/kamlux.py "$INSTALL_DIR/kamlux.py"
    chmod +x "$INSTALL_DIR/kamlux.py"
    
    # Create config with user options
    cat > "$CONFIG_DIR/config.json" << EOF
{
    "device": "$device",
    "interval": $interval,
    "smoothing_alpha": $alpha,
    "curve": [
        [0.0, 100.0],
        [0.31, $target_brightness],
        [0.5, 40.0],
        [0.8, 20.0],
        [1.0, 5.0]
    ],
    "override_cooldown_minutes": $cooldown
}
EOF
    
    print_success "Installed to $INSTALL_DIR"
    print_success "Config created at $CONFIG_DIR/config.json"
}

create_launcher() {
    print_info "Creating launcher..."
    
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    cat > "$bin_dir/kamlux" << EOF
#!/usr/bin/env bash
# Kamlux launcher - Auto brightness control for KDE Plasma

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$INSTALL_DIR"

# Find Python - prefer venv if exists
if [ -f "$SCRIPT_DIR/../venv/bin/python" ]; then
    PYTHON="$SCRIPT_DIR/../venv/bin/python"
elif [ -f "$HOME/.local/share/kamlux/venv/bin/python" ]; then
    PYTHON="$HOME/.local/share/kamlux/venv/bin/python"
else
    PYTHON="python3"
fi

exec "$PYTHON" "$INSTALL_DIR/kamlux.py" "\$@"
EOF
    
    chmod +x "$bin_dir/kamlux"
    
    # Add to PATH if not already
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        print_warning "Add this to your shell profile (~/.bashrc, ~/.zshrc):"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    print_success "Launcher created at $bin_dir/kamlux"
}

setup_systemd() {
    echo ""
    print_info "Setting up systemd service..."
    
    local systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_dir"
    
    cat > "$systemd_dir/kamlux.service" << EOF
[Unit]
Description=Kamlux - Auto Brightness Daemon
Documentation=https://github.com/AtelierMizumi/kamlux
After=graphical.target

[Service]
Type=simple
ExecStart=%h/.local/share/kamlux/kamlux.py
Restart=on-failure
RestartSec=5
Environment=HOME=%h

[Install]
WantedBy=default.target
EOF
    
    print_success "Systemd service created"
    
    read -p "Enable and start service now? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        systemctl --user daemon-reload
        systemctl --user enable kamlux.service
        systemctl --user start kamlux.service
        
        sleep 2
        
        if systemctl --user is-active --quiet kamlux.service; then
            print_success "Service started successfully!"
        else
            print_error "Service failed to start. Check logs with:"
            echo "  journalctl --user -u kamlux.service"
        fi
    else
        print_info "To start manually, run:"
        echo "  systemctl --user start kamlux.service"
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Installation Complete!                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Install directory: $INSTALL_DIR"
    echo "  Config file: $CONFIG_DIR/config.json"
    echo "  Launcher: $HOME/.local/bin/kamlux"
    echo ""
    echo "Useful commands:"
    echo "  kamlux           - Run in terminal (for debugging)"
    echo "  systemctl --user start kamlux   - Start service"
    echo "  systemctl --user stop kamlux    - Stop service"
    echo "  systemctl --user status kamlux  - Check status"
    echo "  journalctl --user -u kamlux -f - View logs"
    echo ""
    echo "Edit config: $CONFIG_DIR/config.json"
    echo ""
}

main() {
    # Check for --non-interactive flag
    NON_INTERACTIVE=false
    for arg in "$@"; do
        if [ "$arg" = "--non-interactive" ]; then
            NON_INTERACTIVE=true
        fi
    done
    
    if [ "$NON_INTERACTIVE" = true ]; then
        INSTALL_DIR="$HOME/.local/share/kamlux"
        CONFIG_DIR="$HOME/.config/kamlux"
        device="/dev/video0"
        interval=10
        alpha=0.8
        target_brightness=80
        cooldown=30
    else
        check_dependencies
        get_install_dir
        get_config_dir
        configure_options
    fi
    
    install_files
    create_launcher
    
    if [ "$NON_INTERACTIVE" = false ]; then
        setup_systemd
    fi
    
    print_summary
}

main "$@"
