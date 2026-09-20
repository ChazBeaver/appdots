-- This highlights the hex colors in the terminal
-- It makes editting color codes exponentially easier

return {
  "catgoose/nvim-colorizer.lua",
  enabled = true,
  config = function()
    require("colorizer").setup()
  end,
}
