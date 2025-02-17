local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

local function align_spaces(abbr, detail)
    if config.ls.zls.align_type_to_right == false then
        return " "
    end
    return utils.align_spaces(abbr, detail)
end
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
            local text = string.format("%s:%s%s", label, align_spaces(label, detail .. " "), detail)
            local source = string.format("fn(%s)", text)
            local hl = utils.highlight_range(source, ls, 3, 3 + #text)
            for _, highlight in ipairs(hl.highlights) do
                if vim.startswith(highlight[1], "@variable.parameter") then
                    highlight[1] = highlight[1]:gsub("%.parameter", "")
                end
            end
            if config.ls.zls.align_type_to_right == false then
                return hl
            end
            hl.text = hl.text:sub(1, #label) .. " " .. hl.text:sub(#label + 2, #text)
            return hl
        end
        --
    elseif (kind == Kind.Field or kind == Kind.EnumMember) and detail then
        -- For some reason `const x = struct { name: *Foo }` can't get the type color for Foo.
        -- Here is the trick:
        -- xfn(foo:     *Foo)
        -- x            *Foo
        local source = string.format("%sfn(foo:%s%s)", label, align_spaces(label, detail), detail)
        local items = utils.highlight_range(
            source:sub(#label + 1),
            ls,
            config.ls.zls.align_type_to_right and 7 or 6,
            #source:sub(#label + 1) - 1
        )
        return utils.adjust_range(
            items,
            #label + 1,
            source,
            utils.hl_exist_or("@lsp.type.property", "@variable.member", "zig")
        )
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        if detail:sub(1, 2) == "fn" then
            local ret_type = vim.tbl_get(completion_item, "labelDetails", "description")
            local params = vim.tbl_get(completion_item, "labelDetails", "detail")
            local text, source
            if ret_type ~= nil and params ~= nil and config.ls.zls.align_type_to_right then
                text = string.format("%s%s%s%s", label, params, align_spaces(label .. params, ret_type), ret_type)
                source = string.format("fn %s {}", text)
            else
                local signature = detail:sub(4)
                text = string.format("%s%s", label, signature)
                source = string.format("fn %s {}", text)
            end
            return utils.highlight_range(source, ls, 3, 3 + #text)
        elseif detail:sub(1, 1) == "@" then
            return utils.highlight_range(detail, ls, 0, #detail)
        else
            return {
                text = completion_item.label,
                highlights = {
                    {
                        "@function",
                        range = { 0, #completion_item.label },
                    },
                },
            }
        end
        --
    else
        local highlight_name = nil
        if kind == Kind.Keyword then
            highlight_name = "@keyword"
        elseif kind == Kind.Field then
            highlight_name = utils.hl_exist_or("@lsp.type.property", "@variable.member", "zig")
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
