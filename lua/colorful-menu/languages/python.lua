local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.basedpyright(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.detail
    local kind = completion_item.kind

    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    local highlight_name
    if kind == Kind.Method then
        highlight_name = utils.hl_exist_or("@lsp.type.method.python", "@function.python")
    elseif kind == Kind.Function then
        highlight_name = utils.hl_exist_or("@lsp.type.function.python", "@function.python")
    elseif kind == Kind.Variable then
        highlight_name = utils.hl_exist_or("@lsp.type.variable.python", "@variable.python")
    elseif kind == Kind.Field then
        highlight_name = utils.hl_exist_or("@lsp.type.field.python", "@field.python")
    elseif kind == Kind.Keyword then
        highlight_name = "@keyword.python"
    elseif kind == Kind.Property then
        highlight_name = utils.hl_exist_or("@lsp.type.property.python", "@property.python")
    elseif kind == Kind.Module then
        highlight_name = utils.hl_exist_or("@lsp.type.namespace.python", "@namespace.python")
    elseif kind == Kind.Class then
        highlight_name = utils.hl_exist_or("@lsp.type.class.python", "@type.python")
    elseif kind == Kind.Constant then
        highlight_name = "@constant.python"
    else
        highlight_name = config.fallback_highlight
    end

    local highlights = {
        {
            highlight_name,
            range = { 0, #label },
        },
    }

    return {
        text = label,
        highlights = highlights,
    }
end

return M
