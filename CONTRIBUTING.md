# Contributing to Kamlux

Thank you for your interest in contributing to Kamlux!

## Ways to Contribute

- **Bug reports** - Open an issue with details about what happened
- **Feature requests** - Describe what you'd like to see added
- **Code contributions** - Submit a pull request
- **Documentation** - Improve README, add translations
- **Testing** - Test on different hardware/setup

## Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/kamlux.git
cd kamlux

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install numpy

# Run the application
python src/kamlux.py
```

## Code Style

- Follow PEP 8
- Use type hints where possible
- Add docstrings for new functions
- Keep functions small and focused

## Testing

Run the application in terminal mode to test:

```bash
python src/kamlux.py
```

Watch the output for:
- Camera initialization
- V4L2 values reading
- Brightness calculations
- Setting brightness

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Submit a pull request

## Common Issues to Check

- [ ] Camera device is correct
- [ ] KDE Plasma is running
- [ ] qdbus commands work
- [ ] No permission issues with v4l2-ctl

## Questions?

Open an issue for questions about contributing.
