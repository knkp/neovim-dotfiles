#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/nvim"
AUTOLOAD_DIR="$HOME/.local/share/nvim/site/autoload"

# Create the necessary directories if they don't exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$AUTOLOAD_DIR"

# Symlink the init.vim to the Neovim config directory
ln -sf "$(pwd)/init.vim" "$CONFIG_DIR/init.vim"

# Copy your saved plug.vim to the autoload directory
cp -f "$(pwd)/plug.vim" "$AUTOLOAD_DIR/plug.vim"

echo "Symlinks created in $CONFIG_DIR"
echo "plug.vim copied to $AUTOLOAD_DIR"

echo "Setup complete!"

