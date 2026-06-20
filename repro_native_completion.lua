local root = vim.fn.fnamemodify("./.repro", ":p")

-- set stdpaths to use .repro
for _, name in ipairs({ "config", "data", "state", "cache" }) do
    vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end

-- bootstrap lazy
local lazypath = root .. "/plugins/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none", "--single-branch",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end
vim.opt.runtimepath:prepend(lazypath)

local kind_map = {
    [1] = "Text",
    [2] = "Method",
    [3] = "Function",
    [4] = "Constructor",
    [5] = "Field",
    [6] = "Variable",
    [7] = "Class",
    [8] = "Interface",
    [9] = "Module",
    [10] = "Property",
    [11] = "Unit",
    [12] = "Value",
    [13] = "Enum",
    [14] = "Keyword",
    [15] = "Snippet",
    [16] = "Color",
    [17] = "File",
    [18] = "Reference",
    [19] = "Folder",
    [20] = "EnumMember",
    [21] = "Constant",
    [22] = "Struct",
    [23] = "Event",
    [24] = "Operator",
    [25] = "TypeParameter",
}
-- install plugins
local plugins = {
    -- do not remove the colorscheme!
    "folke/tokyonight.nvim",
    "neovim/nvim-lspconfig",
    {
        "xzbdmw/colorful-menu.nvim",
        config = function()
            require("colorful-menu").setup({})
        end,
    },
}

require("lazy").setup(plugins, {
    root = root .. "/plugins",
})

local colorful = require("colorful-menu")
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("EnableNativeCompletion", { clear = true }),
    desc = "Enable vim.lsp.completion and documentation",
    callback = function(args)
        local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
        if not client:supports_method("textDocument/completion") then
            return
        end
        vim.lsp.completion.enable(true, client.id, args.buf, {
            convert = function(item)
                local nchigh = colorful.native_completion_highlight(item, client)
                local abbr = item.label:gsub("%b()", ""):gsub("%b{}", ""):match("[%w_.]+.*") or item.label
                local menu = "[LSP]"
                return {
                    abbr = abbr,
                    abbr_hlgroup = nchigh and nchigh.highlights or nil,
                    label = nchigh and nchigh.label or item.label,
                    menu = menu,
                    kind = kind_map[item.kind] or item.kind,
                    kind_hlgroup = nchigh and nchigh.highlights or nil,
                }
            end,
            autotrigger = false,
        })
    end,
})
require("lspconfig").lua_ls.setup({
    settings = {
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
