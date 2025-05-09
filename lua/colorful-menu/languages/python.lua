local config = require("colorful-menu").config
local Kind = require("colorful-menu").Kind

local M = {}

---@param completion_item lsp.CompletionItem
---@return CMHighlights
local function pylsp(completion_item)
    local path = vim.tbl_get(completion_item, "labelDetails", "description")
    local hls = require("colorful-menu.languages.default").default_highlight(
        completion_item,
        path,
        "python",
        config.ls.pylsp.extra_info_hl
    )
    if hls.text ~= nil and (completion_item.kind == Kind.Function or completion_item.kind == Kind.Method) then
        local s, e = string.find(hls.text, "%b()")
        if s ~= nil and e ~= nil then
            table.insert(hls.highlights, {
                config.ls.pylsp.arguments_hl,
                range = { s - 1, e },
            })
        end
    end
    return hls
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.py(completion_item, ls)
    if ls == "pylsp" then
        return pylsp(completion_item)
    else
        local path = vim.tbl_get(completion_item, "labelDetails", "description")
        return require("colorful-menu.languages.default").default_highlight(
            completion_item,
            path,
            "python",
            config.ls.basedpyright.extra_info_hl
        )
    end
end

return M
