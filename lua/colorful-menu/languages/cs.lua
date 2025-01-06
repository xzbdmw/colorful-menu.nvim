local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.roslyn(completion_item, ls)
    local label = completion_item.label
    local description = completion_item.labelDetails and completion_item.labelDetails.description
    local kind = completion_item.kind

    local text = label

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

    if description then
        text = label .. " " .. description
        table.insert(highlights, {
            config.ls.roslyn.extra_info_hl,
            range = { #label + 1, #text },
        })
    end

    return {
        text = text,
        highlights = highlights,
    }
end

return M
