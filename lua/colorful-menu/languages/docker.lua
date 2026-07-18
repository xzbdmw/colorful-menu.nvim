local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind

local M = {}

---@param completion_item lsp.CompletionItem
---@return CMHighlights
function M.dockerls(completion_item)
    local item = require("colorful-menu.languages.default").default_highlight(completion_item, nil, "dockerfile")
    local kind = completion_item.kind
    if kind == Kind.Reference or kind == Kind.File or kind == Kind.Folder then
        item.highlights[1][1] = utils.hl_exist_or("@string.special.path", "@string", "dockerfile")
    end
    return item
end

return M
