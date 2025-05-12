" Initial configuration from:
"   https://builtin.com/software-engineering-perspectives/neovim-configuration
set nocompatible            " disable compatibility to old-time vi
set showmatch               " show matching 
set ignorecase              " case insensitive 
set mouse=v                 " middle-click paste with 
set hlsearch                " highlight search 
set incsearch               " incremental search
set tabstop=4               " number of columns occupied by a tab 
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
set expandtab               " converts tabs to white space
set shiftwidth=4            " width for autoindents
set autoindent              " indent a new line the same amount as the line just typed
"set number                  " add line numbers
"set relativenumber          " add relative line numbers
set wildmode=longest,list   " get bash-like tab completions
filetype plugin indent on   "allow auto-indenting depending on file type
syntax on                   " syntax highlighting
set mouse=a                 " enable mouse click
set clipboard=unnamedplus   " using system clipboard
filetype plugin on
"set cursorline              " highlight current cursorline
set ttyfast                 " Speed up scrolling in Vim
" set spell                 " enable spell check (may need to download language package)
" set noswapfile            " disable creating swap file
" set backupdir=~/.cache/vim " Directory to store backup files.


let mapleader = "\<Space>"

call plug#begin("~/.vim/plugged")
 " Plugin Section
 Plug 'dracula/vim'
 Plug 'ryanoasis/vim-devicons'
 Plug 'SirVer/ultisnips'
 Plug 'honza/vim-snippets'
 Plug 'preservim/nerdcommenter'
 Plug 'mhinz/vim-startify'
" Plug 'neoclide/coc.nvim', {'branch': 'release'} " doesn't  automatically detect new lsps

 "These are items I chose from previous experience
 Plug 'neovim/nvim-lspconfig'      " Core LSP support
 Plug 'williamboman/mason.nvim'    " Easy LSP installation
 Plug 'williamboman/mason-lspconfig.nvim' " Auto-connect Mason to LSP
 Plug 'hrsh7th/nvim-cmp'           " Autocompletion plugin
 Plug 'hrsh7th/cmp-nvim-lsp'       " LSP source for nvim-cmp

 Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
 Plug 'kdheepak/lazygit.nvim'
 Plug 'stevearc/aerial.nvim'

 " dependency for neo-tree and lualine
 Plug 'nvim-tree/nvim-web-devicons'

 " Dependency for buffer_manager, telescope and neo-tree
 Plug 'nvim-lua/plenary.nvim'

 " Dependency for neo-tree
 Plug 'MunifTanjim/nui.nvim'

 " Dependency for neo-tree (image preview feature)
 Plug '3rd/image.nvim'

 "Moving away from Nerdtree
 "Plug 'nvim-tree/nvim-tree.lua' <-- this one is actually less sophisiticated anyway
 Plug 'nvim-neo-tree/neo-tree.nvim', {'branch': 'v3.x'}


 "Interesting tool for handling buffers
 Plug 'j-morano/buffer_manager.nvim'


 "Add transparent option
 Plug 'xiyaowong/transparent.nvim'

 "using telescope as fuzzyfinder and search-and-replace tool 
 Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.8' }

 Plug 'nvim-lualine/lualine.nvim'

call plug#end()



" === Setup Mason, LSP, and Autocomplete ===
lua << EOF
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "tailwindcss", "html", "ts_ls" },  -- Auto-install these
  automatic_installation = true,
})

local lspconfig = require("lspconfig")

-- Enable autocompletion from cmp-nvim-lsp
local capabilities = require('cmp_nvim_lsp').default_capabilities()

require("mason-lspconfig").setup_handlers({
  function(server_name)
    lspconfig[server_name].setup({
      capabilities = capabilities
    })
  end,
})

local cmp = require'cmp'

cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<C-n>"] = cmp.mapping.select_next_item(), -- Select next suggestion
    ["<C-p>"] = cmp.mapping.select_prev_item(), -- Select previous suggestion
    ["<C-Space>"] = cmp.mapping.complete(),     -- Manually trigger completion
    ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Confirm selection with Enter
    ["<Tab>"] = cmp.mapping.confirm({ select = true }), -- Confirm with Tab
  }),
  sources = {
    { name = 'nvim_lsp' },  -- LSP-based completion
    { name = 'buffer' },    -- Buffer word completion
  }
})

-- NVIMTree (TODO: might not be needed anymore since we're moving to Neo-Tree)
-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

-- empty setup using defaults
-- require("nvim-tree").setup()

-- Setup buffer_manager
require("buffer_manager").setup({ })

-- Setup lualine
require('lualine').setup()


-- Setup Neo-Tree with image.nvim plugin
require("neo-tree").setup({
  filesystem = {
    follow_current_file = {
      enabled = true,
    },
    hijack_netrw_behavior = "open_current",
  },
  event_handlers = {
    {
      event = "file_opened",
      handler = function(file_path)
        if file_path:match("%.png$") or file_path:match("%.jpg$") or file_path:match("%.jpeg$") or file_path:match("%.webp$") then
          require("image").display_image({ path = file_path })
        end
      end
    }
  },
  window = {
    mappings = {
      ["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
      ["l"] = "focus_preview",
      ["<C-b>"] = { "scroll_preview", config = {direction = 10} },
      ["<C-f>"] = { "scroll_preview", config = {direction = -10} },
    }
  }
})


require("image").setup({
  backend = "kitty",
  processor = "magick_cli",
  integrations = {
    markdown = {
      enabled = true,
    },
  },
})

EOF

" move line or visually selected block - alt+j/k
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv
" move split panes to left/bottom/top/right
 nnoremap <A-h> <C-W>H
 nnoremap <A-j> <C-W>J
 nnoremap <A-k> <C-W>K
 nnoremap <A-l> <C-W>L
" move between panes to left/bottom/top/right
 nnoremap <C-h> <C-w>h
 nnoremap <C-j> <C-w>j
 nnoremap <C-k> <C-w>k
 nnoremap <C-l> <C-w>l

" Press i to enter insert mode, and ii to exit insert mode.
:inoremap ii <Esc>
:inoremap jk <Esc>
:inoremap kj <Esc>
:vnoremap jk <Esc>
:vnoremap kj <Esc>

" open file in a text by placing text and gf
nnoremap gf :vert winc f<cr>
" copies filepath to clipboard by pressing yf
:nnoremap <silent> yf :let @+=expand('%:p')<CR>
" copies pwd to clipboard: command yd
:nnoremap <silent> yd :let @+=expand('%:p:h')<CR>
" Vim jump to the last position when reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif


"Not using NvimTree anymore
"
:nnoremap <Leader>e :Neotree toggle<CR>

" Toggle <None / Line Numbers / Relative Line Numbers>
"

function! ToggleNumbers()
    if (&number == 1)
        set number!
        set norelativenumber
    else
        set number
        set relativenumber
    endif
endfunction

:nnoremap <silent> <Leader>ul :call ToggleNumbers()<CR>
":nnoremap <Leader>ul :exec &nu==&rnu? "se nu!" : "se rnu!"<CR>
"


:nnoremap <silent> <Leader>gg :LazyGit<CR>



" Setup Aerial and keymap for codetree support
"
lua require("aerial").setup({})
:nnoremap <silent> <Leader>co :AerialToggle<CR>



" Setup buffer_manager keymaps
"
:nnoremap <silent> <Leader>fb :lua require("buffer_manager.ui").toggle_quick_menu()<CR>
:nnoremap <silent> <Tab>      :lua require("buffer_manager.ui").nav_next()<CR>
:nnoremap <silent> <S-Tab>    :lua require("buffer_manager.ui").nav_prev()<CR>


" Setup transparent keymaps
"
:nnoremap <silent> <Leader>tb :TransparentToggle<CR>

" Find files using Telescope command-line sugar.
"
nnoremap <Leader>ff <cmd>Telescope find_files<CR>
nnoremap <Leader>fg <cmd>Telescope live_grep<CR>
"nnoremap <Leader>fb <cmd>Telescope buffers<CR>
" I actually prefer buffer_manager.nvim
nnoremap <Leader>fh <cmd>Telescope help_tags<CR>

" Set colorscheme to dracula by default
"
colorscheme dracula
