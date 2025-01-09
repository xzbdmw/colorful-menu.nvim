local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.basedpyright(completion_item, ls)
    local path = vim.tbl_get(completion_item, "labelDetails", "description")
    return require("colorful-menu.languages.default").default_highlight(
        completion_item,
        path,
        config.ls[ls].extra_info_hl
    )
end

return M
