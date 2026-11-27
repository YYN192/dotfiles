-- Rosé Pine to match the rest of the rice. "auto" follows Neovim's background,
-- which Neovim detects from Ghostty (dark -> main, light -> dawn).
return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    opts = {
      variant = "auto",
      dark_variant = "main",
      styles = { transparency = true }, -- let Ghostty's blur show through
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "rose-pine" } },
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", name = "catppuccin", enabled = false },
}
