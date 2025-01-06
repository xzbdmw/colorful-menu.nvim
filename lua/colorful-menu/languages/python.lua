local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.basedpyright(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind
    local path = vim.tbl_get(completion_item, "labelDetails", "description")

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

    -- Blink has a concept of grid layout while nvim-cmp doesn't,
    -- so we need to emulate what is done via
    -- `columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } }` in blink.
    -- Only when user does not set label_description, or using nvim-cmp,
    -- will we add the extra path information behind.
    local has_label_desscription = false
    local success, columns = pcall(function()
        return require("blink.cmp.config").completion.menu.draw.columns
    end)
    if success and path then
        for _, column in ipairs(columns or {}) do
            for _, other_component_name in ipairs(column) do
                if other_component_name == "label_description" then
                    has_label_desscription = true
                end
            end
        end
    end

    if not has_label_desscription and path then
        local extra_info_hl = config.ls[ls].extra_info_hl
        table.insert(highlights, {
            extra_info_hl,
            range = { #label + 1, #label + 2 + #path },
        })
        return {
            text = label .. " " .. path,
            highlights = highlights,
        }
    end

    return {
        text = label,
        highlights = highlights,
    }
end

return M
