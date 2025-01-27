local utils = require("colorful-menu.utils")

local M = {}

---@param completion_item lsp.CompletionItem
---@param detail string?
---@return CMHighlights
function M.default_highlight(completion_item, detail, extra_info_hl)
    extra_info_hl = extra_info_hl or "@comment"
    local label = completion_item.label
    local highlight_name = utils.hl_by_kind(completion_item.kind)

    local highlights = {
        {
            highlight_name,
            range = { 0, #label },
        },
    }

    local text = label
    if detail and string.find(detail, "\n") == nil then
        local spaces = utils.align_spaces(label, detail)
        -- If there are any information, append it
        text = label .. spaces .. detail
        table.insert(highlights, {
            extra_info_hl,
            range = { #label + 1, #text },
        })
    end

    return {
        text = text,
        highlights = highlights,
    }
end

return M
