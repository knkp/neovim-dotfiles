#!/usr/bin/env bash

CONFIG_DIR="$HOME/.config/nvim"
AUTOLOAD_DIR="$HOME/.local/share/nvim/site/autoload"
PLUGINS_DIR="$HOME/.vim/plugged"

# Create necessary directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$AUTOLOAD_DIR"
mkdir -p "$PLUGINS_DIR"

# Symlink the init.vim and plug.vim
ln -sf "$(pwd)/init.vim" "$CONFIG_DIR/init.vim"
cp -f "$(pwd)/plug.vim" "$AUTOLOAD_DIR/plug.vim"

echo "Symlinks created in $CONFIG_DIR"
echo "plug.vim copied to $AUTOLOAD_DIR"

# Install basic dependencies
echo "Installing essential packages..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y curl git ripgrep fzf imagemagick python3 python3-pip python3-venv pipx

            # Install Lazygit manually
            LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz
            sudo mv lazygit /usr/local/bin
            rm lazygit.tar.gz

            # Install Node.js and npm
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt install -y nodejs npm
            ;;
        arch)
            sudo pacman -Syu --noconfirm neovim python python-pip nodejs npm git ripgrep fzf imagemagick lazygit
            ;;
        fedora)
            sudo dnf install -y neovim python3 python3-pip nodejs npm git ripgrep fzf ImageMagick lazygit
            ;;
        nixos)
            nix-env -iA nixpkgs.neovim nixpkgs.python3 nixpkgs.nodejs nixpkgs.npm nixpkgs.git nixpkgs.ripgrep nixpkgs.fzf nixpkgs.imagemagick nixpkgs.lazygit
            ;;
        *)
            echo "Unsupported OS: Please install the dependencies manually."
            exit 1
            ;;
    esac
else
    echo "Unsupported OS: Please install the dependencies manually."
    exit 1
fi

# Install Python support for Neovim
echo "Installing Python support for Neovim..."
pip3 install --user pynvim --break-system-packages

# Install Node.js support for Neovim
echo "Installing Node.js support for Neovim..."
npm install -g neovim

# Install LSP servers using Mason if available
if command -v nvim &> /dev/null; then
    echo "Installing LSP servers via Mason..."
    nvim --headless +PlugInstall +qall
    nvim --headless -c 'MasonInstall tailwindcss-language-server html-lsp typescript-language-server' -c 'qall'
fi

echo "Setup complete! You can now start Neovim."

