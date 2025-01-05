local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.lua_ls(completion_item, ls)
    local vim_item = M._lua_compute_completion_highlights(completion_item, ls)
    if vim_item.text ~= nil then
        local s, e = string.find(vim_item.text, "%b()")
        if s ~= nil and e ~= nil then
            table.insert(vim_item.highlights, {
                config.ls.lua_ls.arguments_hl,
                range = { s - 1, e },
            })
        end
    end
    return vim_item
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M._lua_compute_completion_highlights(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind

    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end
    if kind == Kind.Field then
        local text = string.format("%s", label)
        local source = string.format("v.%s", text)
        return utils.highlight_range(source, ls, 2, 2 + #text)
    else
        return utils.highlight_range(label, ls, 0, #label)
    end
end

return M
