# docx.yazi
Instant `.docx` preview plugin for Yazi.

This plugin leverages `pandoc` to convert Microsoft Word `.docx` files to plain text on the fly,
and displays the content directly in Yazi's preview panel with zero delay.

## Features
- ✅ Instant preview for `.docx` files
- ⚡ Zero-lag conversion using `pandoc`
- 📝 Lightweight plain text preview in the Yazi preview pane
- 🚀 No additional dependencies beyond `pandoc`

## Dependencies
This plugin requires `pandoc` to be installed on your system:
```bash
# Arch Linux
sudo pacman -S pandoc

# Ubuntu/Debian
sudo apt install pandoc

# macOS (Homebrew)
brew install pandoc
