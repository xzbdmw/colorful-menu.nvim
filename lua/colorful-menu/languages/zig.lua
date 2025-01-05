local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.zls(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.detail
        or (completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail)
    local kind = completion_item.kind

    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    if (kind == Kind.Constant or kind == Kind.Variable or kind == Kind.Struct or kind == Kind.Enum) and detail then
        if detail == "type" then
            local source = string.format("fn(s: %s)", label)
            return utils.highlight_range(source, ls, 6, 6 + #label)
        else
            local text = string.format("%s: %s", label, detail)
            local source = string.format("fn(%s)", text)
            return utils.highlight_range(source, ls, 3, 3 + #text)
        end
        --
    elseif (kind == Kind.Field or kind == Kind.EnumMember) and detail then
        -- const x = struct { name: []const u8 };
        local text = string.format("%s: %s", label, detail)
        local source = string.format("const x = struct { %s }", text)
        return utils.highlight_range(source, ls, 19, 19 + #text)
        --
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        if detail:sub(1, 2) == "fn" then
            local signature = detail:sub(4)
            local text = string.format("%s%s", label, signature)
            local source = string.format("fn %s {}", text)
            local item = utils.highlight_range(source, ls, 3, 3 + #text)
            return item
        end
        --
    else
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
    return {}
end

return M
