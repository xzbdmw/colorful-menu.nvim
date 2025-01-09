local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

local function parse_signature(signature)
    local params, returns = "", ""
    local pm, rm = signature:match("^(%b())%s*(%(?.*%)?)")
    params = pm ~= nil and pm or ""
    returns = rm ~= nil and rm or ""
    return params, returns
end

local function align_spaces(abbr, detail)
    if config.ls.gopls.alignment == false then
        return " "
    end
    local blank = config.max_width - vim.fn.strdisplaywidth(abbr) - vim.fn.strdisplaywidth(detail)
    if blank < 0 then
        blank = 0
    end
    return string.rep(" ", blank)
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.gopls(completion_item, ls)
    if config.ls.gopls.alignment then
        -- This makes no sense then.
        config.ls.gopls.add_colon_before_type = false
    end

    local label = completion_item.label
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    local kind = completion_item.kind

    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    -- Gopls returns nested fields and methods as completions.
    -- To syntax highlight these, combine their final component
    -- with their detail.
    local name_offset = label:reverse():find("%.") or 0
    if name_offset > 0 then
        name_offset = #label - name_offset + 2
    else
        name_offset = 0
    end

    if kind == Kind.Module and detail then
        local text = string.format("%s%s%s", label, align_spaces(label, detail), detail)
        local source = string.format("import %s", text)
        return utils.highlight_range(source, ls, 7, 7 + #text)
        --
    elseif (kind == Kind.Constant or kind == Kind.Variable) and detail then
        local text
        if config.ls.gopls.add_colon_before_type then
            text = string.format("%s:%s%s", label, align_spaces(label, detail), detail)
        else
            text = string.format("%s%s%s", label, align_spaces(label, detail), detail)
        end
        local var_part = text:sub(name_offset)
        local source = string.format("var %s", var_part)
        local item = utils.highlight_range(source, ls, 4, 4 + #var_part)
        return utils.adjust_range(item, name_offset, text)
        --
    elseif kind == Kind.Struct then
        detail = "struct{}"
        local text = string.format("%s%s%s", label, align_spaces(label, detail), detail)
        local source = string.format("type %s struct {}", text:sub(name_offset))
        local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return utils.adjust_range(item, name_offset, text)
        --
    elseif kind == Kind.Interface then
        detail = "interface{}"
        local text = string.format("%s%s%s", label, align_spaces(label, detail), detail)
        local source = string.format("type %s interface {}", text:sub(name_offset))
        local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return utils.adjust_range(item, name_offset, text)
        --
    elseif kind == Kind.Field and detail then
        local text
        if config.ls.gopls.add_colon_before_type then
            text = string.format("%s:%s%s", label, align_spaces(label, detail), detail)
        else
            text = string.format("%s%s%s", label, align_spaces(label, detail), detail)
        end
        local source = string.format("type T struct { %s }", text:sub(name_offset))
        local item = utils.highlight_range(source, ls, 16, 16 + #text:sub(name_offset))
        return utils.adjust_range(item, name_offset, text)
        --
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        if detail:sub(1, 4) == "func" then
            local signature = detail:sub(5)
            local text = string.format("%s%s", label, signature)

            if signature ~= "()" then
                local b, e = string.find(signature, "from")
                if b == 3 and e == 6 then
                    text = label .. align_spaces(label, signature) .. signature
                else
                    local params, returns = parse_signature(signature)
                    text = label .. params .. align_spaces(label, params .. returns) .. returns
                end
            end

            local source = string.format("func %s {}", text:sub(name_offset))
            local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
            return utils.adjust_range(item, name_offset, text)
        else
            return {
                text = label,
                highlights = {
                    {
                        "@function",
                        range = { 0, #label },
                    },
                },
            }
        end
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
    return {}
end

function align_spaces(abbr, detail)
    if config.ls.gopls.alignment == false then
        return " "
    end
    local blank = config.max_width - vim.fn.strdisplaywidth(abbr) - vim.fn.strdisplaywidth(detail)
    if blank < 0 then
        blank = 0
    end
    return string.rep(" ", blank)
end

return M
