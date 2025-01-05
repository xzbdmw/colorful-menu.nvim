local M = {}

M.insertTextFormat = { PlainText = 1, Snippet = 2 }
-- stylua: ignore
M.Kind = { Text = 1, Method = 2, Function = 3, Constructor = 4, Field = 5, Variable = 6, Class = 7, Interface = 8, Module = 9, Property = 10, Unit = 11, Value = 12, Enum = 13, Keyword = 14, Snippet = 15, Color = 16, File = 17, Reference = 18, Folder = 19, EnumMember = 20, Constant = 21, Struct = 22, Event = 23, Operator = 24, TypeParameter = 25 }

---@alias CMHighlightRange {hl_group: string, range: integer[]}
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
        },
        ["typescript-language-server"] = {
            extra_info_hl = "@comment",
        },
        ts_ls = {
            extra_info_hl = "@comment",
        },
        tsserver = {
            extra_info_hl = "@comment",
        },
        vtsls = {
            extra_info_hl = "@comment",
        },
        ["rust-analyzer"] = {
            -- Such as (as Iterator), (use std::io).
            extra_info_hl = "@comment",
        },
        clangd = {
            -- Such as "From <stdio.h>".
            extra_info_hl = "@comment",
        },
        fallback = true,
    },
    fallback_highlight = "@variable",
    max_width = 60,
}

---@diagnostic disable-next-line: undefined-doc-name
---@param entry cmp.Entry
function M.cmp_highlights(entry)
    local client = vim.tbl_get(entry, "source", "source", "client") -- For example `lua_ls` etc
    if client and not client.is_stopped() then
        ---@diagnostic disable-next-line: undefined-field
        return M.highlights(entry:get_completion_item(), client.name)
    end
    return nil
end

---@diagnostic disable-next-line: undefined-doc-name
---@param ctx blink.cmp.DrawItemContext
function M.blink_components_text(ctx)
    local highlights_info = require("colorful-menu").blink_highlights(ctx)
    if highlights_info ~= nil then
        return highlights_info.label
    else
        return ctx.label
    end
end

---@diagnostic disable-next-line: undefined-doc-name
---@param ctx blink.cmp.DrawItemContext
function M.blink_components_highlight(ctx)
    local highlights = {}
    local highlights_info = require("colorful-menu").blink_highlights(ctx)
    if highlights_info ~= nil then
        highlights = highlights_info.highlights
    end
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
    if client and not client.is_stopped() then
        ---@diagnostic disable-next-line: undefined-field
        local highlights_info = M.highlights(ctx.item, client.name)
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

---@param item CMHighlights
---@return CMHighlights?
local function apply_post_processing(item)
    -- if the user override or fallback logic didn't produce a table, bail
    if type(item) ~= "table" or not item.text then
        return item
    end

    local text = item.text
    local max_width = M.config.max_width

    if max_width and max_width > 0 then
        -- if text length is beyond max_width, truncate
        local display_width = vim.fn.strdisplaywidth(text)
        if display_width > max_width then
            -- We can remove from the end
            -- or do partial truncation using `strcharpart` or `strdisplaywidth` logic.
            local truncated = vim.fn.strcharpart(text, 0, max_width - 1) .. "…"
            item.text = truncated
        end
    end
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights?
local function default_highlight(completion_item, ls)
    local label = completion_item.label
    if label == nil then
        return nil
    end
    return require("colorful-menu.utils").highlight_range(label, ls, 0, #label)
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

    if completion_item == nil or ls == nil or ls == "" or vim.b.ts_highlight == false then
        return nil
    end

    local item
    if ls == "gopls" then
        item = require("colorful-menu.languages.go").gopls(completion_item, ls)
        --
    elseif ls == "rust-analyzer" then
        item = require("colorful-menu.languages.rust").rust_analyzer(completion_item, ls)
        --
    elseif ls == "lua_ls" then
        item = require("colorful-menu.languages.lua").lua_ls(completion_item, ls)
        --
    elseif ls == "clangd" then
        item = require("colorful-menu.languages.cpp").clangd(completion_item, ls)
        --
    elseif ls == "typescript-language-server" or ls == "ts_ls" or ls == "tsserver" then
        item = require("colorful-menu.languages.typescript").ts_server(completion_item, ls, client)
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
    else
        -- No languages detected so check if we should highlight with default or not
        if not M.config.ls.fallback then
            return nil
        end
        item = default_highlight(completion_item, ls)
    end

    if item then
        apply_post_processing(item)
    end

    return item
end

---@param opts ColorfulMenuConfig
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
