# Kamlux

Automatic screen brightness adjustment daemon for KDE Plasma using camera-based ambient light detection.

![KDE Plasma](https://img.shields.io/badge/Environment-KDE%20Plasma-2175b8?style=flat&logo=kde)
![Python](https://img.shields.io/badge/Python-3.10+-3776ab?style=flat&logo=python)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Camera-based ambient light detection** - Uses your webcam's auto-exposure to measure room brightness
- **KDE Plasma native integration** - Uses `qdbus` to communicate with KDE's PowerDevil
- **Smooth transitions** - Exponential moving average prevents jarring brightness changes
- **Manual override** - Keyboard shortcuts and KDE controls work normally; script respects your changes
- **Lightweight** - Minimal dependencies, no external services needed
- **Configurable** - Easy to customize brightness curve, intervals, and behavior

## How It Works

Kamlux reads your camera's gain and exposure values to estimate ambient light levels:

1. **Camera AE as light sensor** - Modern webcams have auto-exposure that automatically adjusts to light
2. **Dark room** → High gain/exposure → Lower screen brightness
3. **Bright room** → Low gain/exposure → Higher screen brightness

The brightness curve maps darkness scores (0-1) to screen brightness (0-100%).

## Requirements

- **KDE Plasma** (uses Plasma's brightness control)
- **Python 3.10+**
- **v4l-utils** (for camera access)
- **A webcam** with auto-exposure support

## Installation

### Quick Install (Arch Linux)

```bash
curl -sL https://yourusername.github.io/kamlux/install-arch.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/yourusername/kamlux.git
cd kamlux
./install-arch.sh
```

The installer will:
1. Check dependencies
2. Ask for your preferences (target brightness, check interval, etc.)
3. Install to `~/.local/share/kamlux`
4. Create config at `~/.config/kamlux/config.json`
5. Set up systemd user service

### Manual Install

```bash
# Install dependencies
sudo pacman -S python python-v4l-utils

# Create directories
mkdir -p ~/.local/share/kamlux
mkdir -p ~/.config/kamlux

# Copy files
cp src/kamlux.py ~/.local/share/kamlux/
cp src/config.json ~/.config/kamlux/config.json
chmod +x ~/.local/share/kamlux/kamlux.py

# Create launcher
mkdir -p ~/.local/bin
cat > ~/.local/bin/kamlux << 'EOF'
#!/usr/bin/env bash
python3 "$HOME/.local/share/kamlux/kamlux.py" "$@"
EOF
chmod +x ~/.local/bin/kamlux

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"

# Setup systemd service
mkdir -p ~/.config/systemd/user
cp systemd/kamlux.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now kamlux.service
```

## Usage

### Commands

```bash
kamlux              # Run in terminal (for debugging)
systemctl --user start kamlux   # Start service
systemctl --user stop kamlux    # Stop service  
systemctl --user status kamlux  # Check status
journalctl --user -u kamlux -f  # View logs
```

### Configuration

Edit `~/.config/kamlux/config.json`:

```json
{
    "device": "/dev/video0",
    "interval": 10,
    "smoothing_alpha": 0.8,
    "curve": [
        [0.0, 100.0],
        [0.31, 80.0],
        [0.5, 40.0],
        [0.8, 20.0],
        [1.0, 5.0]
    ],
    "override_cooldown_minutes": 30
}
```

| Setting | Description |
|---------|-------------|
| `device` | Camera device (default: /dev/video0) |
| `interval` | Seconds between brightness checks |
| `smoothing_alpha` | Response speed (0.1=slow, 1.0=instant) |
| `curve` | Maps darkness (0-1) to brightness (0-100%) |
| `override_cooldown_minutes` | How long to wait after manual override |

### Tuning the Brightness Curve

The curve maps camera darkness score to screen brightness:

```
[darkness_score, brightness%]

[0.0, 100.0]    # Full light → 100% brightness
[0.31, 80.0]    # Your typical room → 80% brightness  
[0.5, 40.0]     # Dim room → 40% brightness
[0.8, 20.0]     # Dark room → 20% brightness
[1.0, 5.0]      # Very dark → 5% brightness
```

To find your optimal values:
1. Run `kamlux` in terminal
2. Note the "Darkness" value in different lighting
3. Adjust curve points accordingly

## Troubleshooting

### Brightness not changing?

1. Check camera is accessible:
   ```bash
   v4l2-ctl -d /dev/video0 --get-ctrl=gain
   ```

2. Check KDE brightness control:
   ```bash
   qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness
   ```

3. Run in terminal to see debug output:
   ```bash
   kamlux
   ```

### Camera not detected?

- Check device: `ls /dev/video*`
- Update if different: edit `device` in config.json

### Service won't start?

```bash
journalctl --user -u kamlux.service
```

## Website

The project includes a static website that can be deployed to Cloudflare Pages.

### Deploy to Cloudflare Pages

1. Fork this repository
2. Go to Cloudflare Dashboard → Pages
3. Connect your GitHub account
4. Select your forked repository
5. Set:
   - Build command: (empty)
   - Build output directory: `/docs`
6. Click "Save and Deploy"

Your site will be available at `https://yourusername.pages.dev`

Or use direct upload:
1. Go to Cloudflare Dashboard → Pages
2. Select "Direct upload"
3. Upload the `docs` folder
4. Your site will be deployed

## How It Differs from Other Solutions

| Method | Pros | Cons |
|--------|------|------|
| **Kamlux (this)** | No extra hardware, works on laptops | Requires camera |
| lightd/automedia | Works everywhere | Needs ambient light sensor |
| xbacklight | Simple | Doesn't work on modern systems |
| brightnessctl | Many backends | May conflict with KDE |

## License

MIT License - See LICENSE file for details.

## Contributing

Pull requests welcome! Please ensure tests pass before submitting.
