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
    if config.ls.gopls.align_type_to_right == false then
        return " "
    end
    return utils.align_spaces_bell(abbr, detail)
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.gopls(completion_item, ls)
    if config.ls.gopls.align_type_to_right then
        -- This makes no sense then.
        config.ls.gopls.add_colon_before_type = false
    end

    local label = completion_item.label
    local kind = completion_item.kind
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    if detail then
        -- In unimported one, we remove useless information
        -- assign.Analyzer var from("golang.org/x/tools/go/analysis/passes/assign")
        -- =>
        -- assign.Analyzer "golang.org/x/tools/go/analysis/passes/assign"
        local path = detail:match(".*%(from(.*)%)")
        if path then
            local highlight_name = utils.hl_by_kind(kind)
            local spaces = align_spaces(label, path)
            local text = label .. align_spaces(label, path) .. path
            return {
                text = text,
                highlights = {
                    {
                        highlight_name,
                        range = { 0, #label },
                    },
                    {
                        "@string",
                        range = { #label + #spaces, #text },
                    },
                },
            }
        end
    end

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
        if kind == Kind.Constant then
            if #item.highlights >= 1 then
                item.highlights[1][1] = utils.hl_exist_or("@constant", "@variable", "go")
            end
        end
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
        local signature = vim.trim(detail)
        if detail:sub(1, 4) == "func" then
            signature = detail:sub(5)
        end

        local text = string.format("%s%s", label, signature)
        if signature ~= "()" then
            local params, returns = parse_signature(signature)
            text = label .. params .. align_spaces(label, params .. returns) .. returns
        end

        local source = string.format("func %s {}", text:sub(name_offset))
        local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return utils.adjust_range(item, name_offset, text)
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
end

return M
