local config = require("colorful-menu").config
local Kind = require("colorful-menu").Kind

local M = {}

---@param completion_item lsp.CompletionItem
---@param use_detail_fallback boolean?
---@return string?
local function extra_info(completion_item, use_detail_fallback)
    local description = vim.tbl_get(completion_item, "labelDetails", "description")
    if description ~= nil then
        return description
    end

    -- `ty` may return the type in `detail` when label details are unavailable.
    if use_detail_fallback then
        return completion_item.detail
    end
end

---@param completion_item lsp.CompletionItem
---@return CMHighlights
local function pylsp(completion_item)
    local hls = require("colorful-menu.languages.default").default_highlight(
        completion_item,
        extra_info(completion_item),
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
        return require("colorful-menu.languages.default").default_highlight(
            completion_item,
            extra_info(completion_item, ls == "ty"),
            "python",
            config.ls.basedpyright.extra_info_hl
        )
    end
end

return M
