local root = vim.fn.fnamemodify("./.repro", ":p")
-- set stdpaths to use .repro
for _, name in ipairs({ "config", "data", "state", "cache" }) do
	vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end
-- bootstrap lazy
local lazypath = root .. "/plugins/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--single-branch",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.runtimepath:prepend(lazypath)
-- install plugins
local plugins = {
	-- do not remove the colorscheme!
	"folke/tokyonight.nvim",
	"nvim-treesitter/nvim-treesitter",
	"neovim/nvim-lspconfig",
	{
		"hrsh7th/nvim-cmp",
		lazy = false,
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{
				"xzbdmw/colorful-menu.nvim",
				config = function()
					require("colorful-menu").setup({})
				end,
			},
		},
		config = function(_, opts)
			local cmp = require("cmp")
			require("cmp").setup({
				mapping = cmp.mapping.preset.insert({
					["<cr>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.confirm()
						end
					end, { "i" }),
				}),
				completion = {
					completeopt = "menu,menuone,noinsert",
				},

				formatting = {
					-- kind is icon, abbr is completion name, menu is [Function]
					fields = { "kind", "abbr", "menu" },
					format = function(entry, vim_item)
						local completion_item = entry:get_completion_item()
						local highlights_info = require("colorful-menu").highlights(
							completion_item,
							vim.bo.filetype ~= "" and vim.bo.filetype or "lua"
						)
						if highlights_info == nil then
							vim_item.abbr = completion_item.label
						else
							vim_item.abbr_hl_group = highlights_info.highlights
							vim_item.abbr = highlights_info.text
						end
						vim_item.kind = ""
						vim_item.menu = ""
						return vim_item
					end,
				},
				sources = require("cmp").config.sources({
					{ name = "nvim_lsp" },
				}, {}),
			})
		end,
	},
}
require("lazy").setup(plugins, {
	root = root .. "/plugins",
})
require("lspconfig")["rust-analyzer"].setup({})
vim.cmd([[colorscheme tokyonight]])
