local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

local function one_line(s)
    s = s:gsub("    ", "")
    s = s:gsub("\n", " ")
    return s
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.ts_server(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.detail
    local kind = completion_item.kind
    -- Combine label + detail for final display
    local text = (detail and config.ls.ts_ls.extra_info_hl ~= false) and (label .. " " .. one_line(detail)) or label

    if not kind then
        return utils.highlight_range(text, ls, 0, #text)
    end

    local highlight_name
    if kind == Kind.Class or kind == Kind.Interface or kind == Kind.Enum then
        highlight_name = "@type"
    elseif kind == Kind.Constructor then
        highlight_name = "@type"
    elseif kind == Kind.Constant then
        highlight_name = "@constant"
    elseif kind == Kind.Function or kind == Kind.Method then
        highlight_name = "@function"
    elseif kind == Kind.Property or kind == Kind.Field then
        highlight_name = "@property"
    elseif kind == Kind.Variable then
        highlight_name = "@variable"
    elseif kind == Kind.Keyword then
        highlight_name = "@keyword"
    else
        highlight_name = config.fallback_highlight
    end

    local highlights = {
        {
            highlight_name,
            range = { 0, #label },
        },
    }

    if detail and config.ls.ts_ls.extra_info_hl ~= false then
        local extra_info_hl = config.ls.ts_ls.extra_info_hl
        table.insert(highlights, {
            extra_info_hl,
            range = { #label + 1, #label + 1 + #detail },
        })
    end

    return {
        text = text,
        highlights = highlights,
    }
end

-- see https://github.com/zed-industries/zed/pull/13043
-- Untested.
---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.vtsls(completion_item, ls)
    local label = completion_item.label

    local kind = completion_item.kind
    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    local highlight_name
    if kind == Kind.Class or kind == Kind.Interface or kind == Kind.Enum then
        highlight_name = "@type"
    elseif kind == Kind.Constructor then
        highlight_name = "@type"
    elseif kind == Kind.Constant then
        highlight_name = "@constant"
    elseif kind == Kind.Function or kind == Kind.Method then
        highlight_name = "@function"
    elseif kind == Kind.Property or kind == Kind.Field then
        highlight_name = "@property"
    elseif kind == Kind.Variable then
        highlight_name = "@variable"
    else
        highlight_name = config.fallback_highlight
    end

    local description = completion_item.labelDetails and completion_item.labelDetails.description
    local detail = completion_item.detail

    local highlights = {
        {
            highlight_name,
            range = { 0, #label },
        },
    }
    local text = label
    if config.ls.vtsls.extra_info_hl ~= false then
        if description then
            text = label .. " " .. one_line(description)
            table.insert(highlights, {
                config.ls.vtsls.extra_info_hl,
                range = { #label + 1, #text },
            })
        elseif detail then
            text = label .. " " .. one_line(detail)
            table.insert(highlights, {
                config.ls.vtsls.extra_info_hl,
                range = { #label + 1, #text },
            })
        end
    end

    return {
        text = text,
        highlights = highlights,
    }
end

return M
