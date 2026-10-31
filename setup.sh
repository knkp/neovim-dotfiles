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

if [ "$(uname -s)" = "Darwin" ]; then
    # Install Homebrew if it isn't already available
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found, installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Make brew available in this shell (Apple Silicon or Intel location)
        if [ -x /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    brew update
    brew install neovim python node git ripgrep fzf imagemagick lazygit
    # Google Chrome is used by strudel.nvim (via Puppeteer)
    brew install --cask google-chrome
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y curl git ripgrep fzf imagemagick python3 python3-pip python3-venv pipx

            # Release binaries for Lazygit and Neovim both use x86_64/arm64 naming
            case "$(uname -m)" in
                aarch64|arm64) LINUX_ARCH="arm64" ;;
                *) LINUX_ARCH="x86_64" ;;
            esac

            # Install Lazygit manually
            LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_${LINUX_ARCH}.tar.gz"
            tar xf lazygit.tar.gz
            sudo mv lazygit /usr/local/bin
            rm lazygit.tar.gz

            # Install Neovim from the official release (apt's version is too old for lspconfig/mason)
            curl -Lo nvim.tar.gz "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${LINUX_ARCH}.tar.gz"
            sudo rm -rf "/opt/nvim-linux-${LINUX_ARCH}"
            sudo tar -C /opt -xzf nvim.tar.gz
            sudo ln -sf "/opt/nvim-linux-${LINUX_ARCH}/bin/nvim" /usr/local/bin/nvim
            rm nvim.tar.gz

            # Install Node.js and npm
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt install -y nodejs npm

            # Install Google Chrome (used by strudel.nvim); Google only ships x86_64 Linux builds
            if [ "$LINUX_ARCH" = "x86_64" ]; then
                curl -Lo google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
                sudo apt install -y ./google-chrome.deb
                rm google-chrome.deb
            else
                echo "Google Chrome isn't available for $LINUX_ARCH Linux; install a Chromium-based browser manually for strudel.nvim."
            fi
            ;;
        arch)
            sudo pacman -Syu --noconfirm neovim python python-pip nodejs npm git ripgrep fzf imagemagick lazygit

            # Google Chrome is only in the AUR, so use an AUR helper if there is one, otherwise fall back to Chromium
            if command -v yay &> /dev/null; then
                yay -S --noconfirm google-chrome
            elif command -v paru &> /dev/null; then
                paru -S --noconfirm google-chrome
            else
                echo "No AUR helper found, installing Chromium instead of Google Chrome for strudel.nvim..."
                sudo pacman -S --noconfirm chromium
            fi
            ;;
        fedora)
            sudo dnf install -y neovim python3 python3-pip nodejs npm git ripgrep fzf ImageMagick lazygit
            # Install Google Chrome (used by strudel.nvim)
            sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
            ;;
        nixos)
            nix-env -iA nixpkgs.neovim nixpkgs.python3 nixpkgs.nodejs nixpkgs.npm nixpkgs.git nixpkgs.ripgrep nixpkgs.fzf nixpkgs.imagemagick nixpkgs.lazygit
            # Google Chrome (used by strudel.nvim) is unfree, so it has to be allowed explicitly
            NIXPKGS_ALLOW_UNFREE=1 nix-env -iA nixpkgs.google-chrome
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

