#!/usr/bin/env bash

set -e

echo "Installing Kamlux..."

# Create necessary directories
INSTALL_DIR="$HOME/.local/share/kamlux"
CONFIG_DIR="$HOME/.config/kamlux"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$BIN_DIR"

# Copy files
cp src/kamlux.py "$INSTALL_DIR/kamlux.py"
chmod +x "$INSTALL_DIR/kamlux.py"

# Copy config if it doesn't exist
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    cp src/config.json "$CONFIG_DIR/config.json"
    echo "Created default configuration."
else
    echo "Configuration already exists, skipping."
fi

# Create a symlink or wrapper in ~/.local/bin
cat > "$BIN_DIR/kamlux" << 'EOF'
#!/usr/bin/env bash
python3 "$HOME/.local/share/kamlux/kamlux.py" "$@"
EOF

chmod +x "$BIN_DIR/kamlux"

# Setup Systemd service
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
cp systemd/kamlux.service "$SYSTEMD_USER_DIR/"

# Reload Systemd and Enable the service
systemctl --user daemon-reload
systemctl --user enable kamlux.service
systemctl --user restart kamlux.service

echo "Kamlux installed successfully!"
echo "Configuration file is located at $CONFIG_DIR/config.json"
echo "You can check the service status with: systemctl --user status kamlux.service"
