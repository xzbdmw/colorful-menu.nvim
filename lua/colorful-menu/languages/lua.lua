local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
local function _lua_compute_completion_highlights(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind

    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    if kind == Kind.Field then
        local text = string.format("%s", label)
        local source = string.format("v.%s", text)
        return utils.highlight_range(source, ls, 2, 2 + #text)
    end

    local highlight_name
    if kind == Kind.Constant then
        highlight_name = "@constant.lua"
    elseif kind == Kind.Function or kind == Kind.Method then
        highlight_name = "@function.lua"
    elseif kind == Kind.Property then
        highlight_name = "@property.lua"
    elseif kind == Kind.Variable then
        highlight_name = "@variable.lua"
    elseif kind == Kind.Keyword then
        highlight_name = "@keyword.lua"
    else
        highlight_name = config.fallback_highlight
    end

    return {
        text = label,
        highlights = {
            {
                highlight_name,
                range = { 0, #label },
            },
        },
    }
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.lua_ls(completion_item, ls)
    local vim_item = _lua_compute_completion_highlights(completion_item, ls)
    if vim_item.text ~= nil then
        local s, e = string.find(vim_item.text, "%b()")
        if s ~= nil and e ~= nil then
            table.insert(vim_item.highlights, {
                config.ls.lua_ls.arguments_hl,
                range = { s - 1, e },
            })
        end
    end
    return vim_item
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.emmylua_ls(completion_item, ls)
    local vim_item = _lua_compute_completion_highlights(completion_item, ls)
    local detail = vim.tbl_get(completion_item, "labelDetails", "detail")
    if type(detail) == "string" and detail ~= "" then
        local detail_start = #vim_item.text
        vim_item.text = vim_item.text .. detail
        local kind = completion_item.kind
        local detail_hl = config.ls.fallback_extra_info_hl
        if kind == Kind.Function or kind == Kind.Method or kind == Kind.Constructor then
            detail_hl = config.ls.lua_ls.arguments_hl
        end
        table.insert(vim_item.highlights, {
            detail_hl,
            range = { detail_start, #vim_item.text },
        })
    end

    local description = vim.tbl_get(completion_item, "labelDetails", "description")
    if type(description) == "string" and description ~= "" then
        local spaces = utils.align_spaces(vim_item.text, description)
        local description_start = #vim_item.text + #spaces
        vim_item.text = vim_item.text .. spaces .. description
        table.insert(vim_item.highlights, {
            config.ls.fallback_extra_info_hl,
            range = { description_start, #vim_item.text },
        })
    end

    return vim_item
end

return M
