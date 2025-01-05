local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.intelephense(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    local kind = completion_item.kind

    if (kind == Kind.Function or kind == Kind.Method) and detail and #detail > 0 then
        local signature = detail:sub(#label + 1)
        local text = string.format("%s <?php fn %s {}", label, signature)
        local item = utils.highlight_range(text, ls, 6 + #label, #text - 2)
        return utils.adjust_range(item, #label + 1, label)
        --
    elseif kind == Kind.EnumMember and detail and #detail > 0 then
        local text = string.format("%s <?php %s;", label, detail)
        local item = utils.highlight_range(text, ls, #label + 6, #text - 1)
        return utils.adjust_range(item, #label + 1, label)
        --
    elseif (kind == Kind.Property or kind == Kind.Variable) and detail and #detail > 0 then
        detail = string.gsub(detail, ".*\\(.)", "%1")
        local text = string.format("%s <?php fn(): %s;", label, detail)
        local item = utils.highlight_range(text, ls, #label + 12, #text - 1)
        return utils.adjust_range(item, #label + 1, label)
        --
    elseif kind == Kind.Constant and detail and #detail > 0 then
        local text = string.format("%s <?php %s;", label, detail)
        local item = utils.highlight_range(text, ls, #label + 6, #text - 1)
        return utils.adjust_range(item, #label + 1, label)
        --
    else
        -- Handle other kinds
        local highlight_name = nil
        if kind == Kind.Keyword then
            highlight_name = "@keyword"
        else
            highlight_name = config.fallback_highlight
        end

        return {
            text = completion_item.label,
            highlights = {
                {
                    highlight_name,
                    range = { 0, #completion_item.label },
                },
            },
        }
    end
end

return M
