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
                    format = function(entry, vim_item)
                        local highlights_info = require("colorful-menu").cmp_highlights(entry)
                        if highlights_info ~= nil then
                            vim_item.abbr_hl_group = highlights_info.highlights
                            vim_item.abbr = highlights_info.text
                        end
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
require("lspconfig").lua_ls.setup({
    settings = {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
        Lua = {
            runtime = {
                version = "LuaJIT",
            },
            workspace = {
                library = {
                    "/usr/local/share/nvim/runtime",
                },
            },
            completion = {
                callSnippet = "Replace",
            },
        },
    },
})
vim.cmd([[colorscheme tokyonight]])
