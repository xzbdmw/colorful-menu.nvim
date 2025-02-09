local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

local function align_spaces(abbr, detail)
    return utils.align_spaces(abbr, detail)
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.dartls(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    if detail ~= nil and detail:find("Auto") ~= nil then
        detail = detail:gsub("Auto import.*\n\n", "")
        detail = vim.split(detail, "\n")[1]
    end

    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    if (kind == Kind.Constant or kind == Kind.Variable) and detail then
        -- x int
        local text = string.format("%s%s%s", label, align_spaces(label, detail), detail)
        -- var x int x
        local source = string.format("var %s x", text)
        return utils.highlight_range(source, ls, 4, 4 + #text)
        --
    elseif (kind == Kind.Field or kind == Kind.Property) and detail then
        -- Here is the trick same as zls:
        -- xvoid(       *Foo)
        -- x            *Foo
        local source = string.format("%svoid(%s%s)", label, align_spaces(label, detail), detail)
        local items = utils.highlight_range(source:sub(#label + 1), ls, 5, #source:sub(#label + 1) - 1)
        return utils.adjust_range(
            items,
            #label + 1,
            source,
            utils.hl_exist_or("@lsp.type.property", "@variable.member")
        )
        --
    elseif (kind == Kind.Function or kind == Kind.Method or kind == Kind.Constructor) and detail then
        -- elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        -- label: fetchData(..)
        -- detail: (int a, int b) -> Future<String>
        -- fetchData(int a, int b);(Future<String> s)
        local params = string.match(detail or "", "^(%b())")
        local type = string.match(detail or "", "→ (.*)")
        if params ~= nil then
            label = label:gsub("%b()$", "") .. params
        end
        if type ~= nil and kind ~= Kind.Constructor then
            local text = string.format("%s%s;(%s)", label, align_spaces(label, type):sub(3), type)
            local comma_pos = #text - #type - 3
            local ranges = utils.highlight_range(text, ls, 0, #text - 1)
            ranges.text = ranges.text:sub(1, comma_pos) .. "  " .. ranges.text:sub(comma_pos + 3, #ranges.text)
            return ranges
        end
        return utils.highlight_range(label, ls, 0, #label)
        --
    else
        return require("colorful-menu.languages.default").default_highlight(
            completion_item,
            detail,
            config.ls[ls].extra_info_hl
        )
    end
    return {}
end

return M
