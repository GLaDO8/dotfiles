-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Leader key (must be before lazy)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Core settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.showmode = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.undofile = true

-- Soft wrap
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- Auto-reload externally changed files
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  command = "silent! checktime",
})

-- Plugins
require("lazy").setup({
  -- Theme: Ayu dark
  {
    "Shatur/neovim-ayu",
    lazy = false,
    priority = 1000,
    config = function()
      require("ayu").setup({ mirage = false })
      vim.cmd.colorscheme("ayu-dark")
    end,
  },

  -- Treesitter: syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {},
  },

  -- Git signs in gutter
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end
          map("n", "]h", gs.next_hunk, { desc = "Next hunk" })
          map("n", "[h", gs.prev_hunk, { desc = "Prev hunk" })
          map("n", "<leader>hp", gs.preview_hunk, { desc = "Preview hunk" })
          map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
          map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
        end,
      })
    end,
  },

  -- File explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
    },
    config = function()
      require("neo-tree").setup({
        filesystem = {
          follow_current_file = { enabled = true },
          use_libuv_file_watcher = true,
        },
      })
    end,
  },
})
