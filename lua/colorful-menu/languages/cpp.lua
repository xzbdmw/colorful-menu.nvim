local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.clangd(completion_item, ls)
    local vim_item = M._clangd(completion_item, ls)
    if vim_item.text ~= nil then
        vim_item.text = vim_item.text:gsub(";", " ")
        local document = completion_item.documentation
        if document and document.value and vim.startswith(document.value, "From ") then
            local len = #vim_item.text
            vim_item.text = string.gsub(vim_item.text .. "  " .. document.value, "\n", " ")
            table.insert(vim_item.highlights, {
                config.ls.clangd.extra_info_hl,
                range = { len + 2, #vim_item.text },
            })
        end
    end
    return vim_item
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M._clangd(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind
    local detail = completion_item.detail
    local labelDetails = completion_item.labelDetails

    -- If no kind, just fallback to highlighting the cleaned-up label
    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    -- Constants or Variables with detail => "detail label", highlight entire text
    if (kind == Kind.Constant or kind == Kind.Variable or kind == Kind.Field) and detail then
        local text = string.format("%s;%s", label, detail)
        -- void foo() {&x;std::unique_ptr<Foo>}
        --             |         |
        --          @variable    |-- @type
        -- later factor to `x std::unique_ptr<Foo>`.
        local source = string.format("void foo(){ &%s }", text)
        return utils.highlight_range(source, ls, 13, 13 + #text)

        -- Functions or Methods with detail => "detail label", might find '('
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        local signature = ""
        if labelDetails and labelDetails.detail then
            signature = labelDetails.detail
        end
        local text = string.format("void %s%s;%s", label, signature, detail)
        return utils.highlight_range(text, ls, 5, #text)
        --
    else
        local highlight_name = nil
        if kind == Kind.Struct or kind == Kind.Interface then
            highlight_name = "@type"
        elseif kind == Kind.Class then
            highlight_name = utils.hl_exist_or("@lsp.type.class", "@variant")
        elseif kind == Kind.EnumMember then
            highlight_name = utils.hl_exist_or("@lsp.type.enumMember", "@variant")
        elseif kind == Kind.Enum then
            highlight_name = utils.hl_exist_or("@lsp.type.enum", "@type")
        elseif kind == Kind.Keyword then
            highlight_name = "@keyword"
        elseif kind == Kind.Value or kind == Kind.Constant then
            highlight_name = "@constant"
        else
            highlight_name = config.fallback_highlight
        end

        -- If we found a special highlight name, highlight the portion before '('
        if highlight_name then
            local paren_index = string.find(label, "%(", 1, true)
            local end_index = paren_index and (paren_index - 1) or #label

            return {
                text = label,
                highlights = {
                    {
                        highlight_name,
                        range = { 0, end_index },
                    },
                },
            }
        end
    end

    return {
        text = label,
        highlights = {},
    }
end

return M
