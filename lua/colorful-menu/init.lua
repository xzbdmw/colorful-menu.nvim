local M = {}

M.insertTextFormat = { PlainText = 1, Snippet = 2 }
-- stylua: ignore
M.Kind = { Text = 1, Method = 2, Function = 3, Constructor = 4, Field = 5, Variable = 6, Class = 7, Interface = 8, Module = 9, Property = 10, Unit = 11, Value = 12, Enum = 13, Keyword = 14, Snippet = 15, Color = 16, File = 17, Reference = 18, Folder = 19, EnumMember = 20, Constant = 21, Struct = 22, Event = 23, Operator = 24, TypeParameter = 25 }

---@alias CMHighlightRange {hl_group: string, range: integer[], text: string}
---
---@class CMHighlights
---@field text string
---@field highlights CMHighlightRange[]

---@class ColorfulMenuConfig
M.config = {
    ls = {
        lua_ls = {
            -- Maybe you want to dim arguments a bit.
            arguments_hl = "@comment",
        },
        gopls = {
            -- When true, label for field and variable will format like "foo: Foo"
            -- instead of go's original syntax "foo Foo".
            add_colon_before_type = false,
            align_type_to_right = true,
            -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
            preserve_type_when_truncate = true,
        },
        ts_ls = {
            -- false means do not include any extra info,
            -- see https://github.com/xzbdmw/colorful-menu.nvim/issues/42
            extra_info_hl = "@comment",
        },
        vtsls = {
            -- false means do not include any extra info,
            -- see https://github.com/xzbdmw/colorful-menu.nvim/issues/42
            extra_info_hl = "@comment",
        },
        zls = {
            align_type_to_right = true,
        },
        ["rust-analyzer"] = {
            -- Such as (as Iterator), (use std::io).
            extra_info_hl = "@comment",
            align_type_to_right = true,
            -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
            preserve_type_when_truncate = true,
        },
        clangd = {
            -- Such as "<stdio.h>".
            extra_info_hl = "@comment",
            -- the hl of leading dot of "•std::filesystem::permissions(..)"
            import_dot_hl = "@comment",
            align_type_to_right = true,
            -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
            preserve_type_when_truncate = true,
        },
        roslyn = {
            extra_info_hl = "@comment",
        },
        -- The same applies to pyright/pylance
        basedpyright = {
            extra_info_hl = "@comment",
        },
        pylsp = {
            extra_info_hl = "@comment",
            -- Dim the function argument area, which is the main
            -- difference with pyright.
            arguments_hl = "@comment",
        },
        dartls = {
            extra_info_hl = "@comment",
        },
        fallback = true,
        fallback_extra_info_hl = "@comment",
    },
    fallback_highlight = "@variable",
    max_width = 60,
}

local hl_cache = {}
local hl_cache_size = 0
-- about 30M max memory usage.
local MAX_HL_CACHE_SIZE = 10000

---@param completion_item lsp.CompletionItem
---@param ls string
---@return string
local function cache_key(completion_item, ls)
    return string.format(
        "%s!%s!%s!%s!%s%s",
        completion_item.label or "",
        completion_item.detail or "",
        completion_item.labelDetails
                and (completion_item.labelDetails.detail or "") .. (completion_item.labelDetails.description or "")
            or "",
        completion_item.kind and tostring(completion_item.kind) or "",
        ls,
        require("colorful-menu.utils").max_width()
    )
end

---@param completion_item lsp.CompletionItem
---@param ls string?
---@return CMHighlights?
local function _highlights(completion_item, ls)
    if completion_item == nil or ls == nil or ls == "" or vim.b.ts_highlight == false then
        return nil
    end

    local item

    local key = cache_key(completion_item, ls)
    if hl_cache[key] ~= nil then
        return hl_cache[key]
    end

    if ls == "gopls" then
        item = require("colorful-menu.languages.go").gopls(completion_item, ls)
        --
    elseif ls == "rust-analyzer" or ls == "rust_analyzer" then
        item = require("colorful-menu.languages.rust").rust_analyzer(completion_item, ls)
        ls = "rust-analyzer"
        --
    elseif ls == "lua_ls" then
        item = require("colorful-menu.languages.lua").lua_ls(completion_item, ls)
        --
    elseif ls == "clangd" then
        item = require("colorful-menu.languages.cpp").clangd(completion_item, ls)
        --
    elseif ls == "typescript-language-server" or ls == "ts_ls" or ls == "tsserver" or ls == "typescript-tools" then
        item = require("colorful-menu.languages.typescript").ts_server(completion_item, ls)
        --
    elseif ls == "vtsls" then
        item = require("colorful-menu.languages.typescript").vtsls(completion_item, ls)
        --
    elseif ls == "zls" then
        item = require("colorful-menu.languages.zig").zls(completion_item, ls)
        --
    elseif ls == "intelephense" then
        item = require("colorful-menu.languages.php").intelephense(completion_item, ls)
        --
    elseif ls == "roslyn" then
        item = require("colorful-menu.languages.cs").roslyn(completion_item, ls)
        --
    elseif ls == "dartls" then
        item = require("colorful-menu.languages.dart").dartls(completion_item, ls)
        --
    elseif ls == "basedpyright" or ls == "pyright" or ls == "pylance" or ls == "pylsp" then
        item = require("colorful-menu.languages.python").py(completion_item, ls)
        --
    else
        -- No languages detected so check if we should highlight with default or not
        if not M.config.ls.fallback then
            return nil
        end
        item = require("colorful-menu.languages.default").default_highlight(
            completion_item,
            completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail,
            nil,
            M.config.ls.fallback_extra_info_hl
        )
    end

    if item then
        item = require("colorful-menu.utils").validate_newline(completion_item, item)
        require("colorful-menu.utils").apply_post_processing(completion_item, item, ls)
    end

    hl_cache_size = hl_cache_size + 1
    if hl_cache_size > MAX_HL_CACHE_SIZE then
        hl_cache_size = 0
        hl_cache = {}
    end
    hl_cache[key] = item

    return item
end

---@diagnostic disable-next-line: undefined-doc-name
---@param entry cmp.Entry
function M.cmp_highlights(entry)
    local client = vim.tbl_get(entry, "source", "source", "client") -- For example `lua_ls` etc
    if client and not client:is_stopped() then
        ---@diagnostic disable-next-line: undefined-field
        return _highlights(entry:get_completion_item(), client.name)
    end
    return nil
end

---@diagnostic disable-next-line: undefined-doc-name
---@param ctx blink.cmp.DrawItemContext
function M.blink_components_text(ctx)
    local highlights_info = M.blink_highlights(ctx)
    if highlights_info ~= nil then
        return highlights_info.label
    else
        ---@diagnostic disable-next-line: undefined-field
        return ctx.label
    end
end

---@diagnostic disable-next-line: undefined-doc-name
---@param ctx blink.cmp.DrawItemContext
function M.blink_components_highlight(ctx)
    local highlights = {}
    local highlights_info = M.blink_highlights(ctx)
    if highlights_info ~= nil then
        highlights = highlights_info.highlights
    end
    ---@diagnostic disable-next-line: undefined-field
    for _, idx in ipairs(ctx.label_matched_indices) do
        table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
    end
    return highlights
end

---@diagnostic disable-next-line: undefined-doc-name
---@param ctx blink.cmp.DrawItemContext
function M.blink_highlights(ctx)
    ---@diagnostic disable-next-line: undefined-field
    local client = vim.lsp.get_client_by_id(ctx.item.client_id)
    local highlights = {}
    if client and not client:is_stopped() then
        ---@diagnostic disable-next-line: undefined-field
        local highlights_info = _highlights(ctx.item, client.name)
        if highlights_info ~= nil then
            for _, info in ipairs(highlights_info.highlights or {}) do
                table.insert(highlights, {
                    info.range[1],
                    info.range[2],
                    ---@diagnostic disable-next-line: undefined-field
                    group = ctx.deprecated and "BlinkCmpLabelDeprecated" or info[1],
                })
            end
        else
            return nil
        end
        return { label = highlights_info.text, highlights = highlights }
    end
    return nil
end

---@param completion_item lsp.CompletionItem
---@param ls string?
---@return CMHighlights?
function M.highlights(completion_item, ls)
    if ls == vim.bo.filetype then
        vim.notify_once(
            "colorful-menu.nvim: Integration with nvim-cmp or blink.cmp has been simplified, and legacy per-filetype options is also deprecated"
                .. " to prefer per-language-server options, please see README",
            vim.log.levels.WARN
        )
        return nil
    end

    return _highlights(completion_item, ls)
end

---@param opts ColorfulMenuConfig
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
