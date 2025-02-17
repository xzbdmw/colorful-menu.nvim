local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

local function align_spaces(abbr, detail)
    if config.ls.clangd.align_type_to_right == false then
        return ""
    end
    return utils.align_spaces_bell(abbr, detail)
end

local function path_align_spaces(abbr, detail)
    if config.ls.clangd.align_type_to_right == false then
        return "  "
    end
    return utils.align_spaces_bell(abbr, detail)
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
local function _clangd(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind
    local detail = completion_item.detail
    local labelDetails = completion_item.labelDetails

    -- If no kind, just fallback to highlighting the cleaned-up label
    if not kind then
        return utils.highlight_range(label, ls, 0, #label)
    end

    -- Constants or Variables with detail => "detail label", highlight entire text
    if (kind == Kind.Constant or kind == Kind.Variable) and detail then
        local text = string.format("%s;%s%s", label, align_spaces(label .. " ", detail), detail)
        -- void foo() {int x;std::unique_ptr<Foo> x;}
        --             |         |
        --          @variable    |-- @type
        -- later factor to `x std::unique_ptr<Foo>`.
        local source = string.format("void foo(){ int %s x;}", text)
        return utils.highlight_range(source, ls, 16, 16 + #text)

        -- Functions or Methods with detail => "detail label", might find '('
    elseif kind == Kind.Field and detail then
        local text = string.format("%s;%s%s", label, align_spaces(label .. " ", detail), detail)
        -- void foo() {f->x;std::unique_ptr<Foo> x;}
        --                |         |
        --                @field    |-- @type
        -- later factor to `x std::unique_ptr<Foo>`.
        local source = string.format("void foo(){ f->%s x;}", text)
        return utils.highlight_range(source, ls, 15, 15 + #text)
        --
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        local signature = ""
        if labelDetails and labelDetails.detail then
            signature = labelDetails.detail
        end
        local text = string.format(
            "void %s%s;%s%s x;",
            label,
            signature,
            align_spaces(label .. signature .. ";", detail),
            detail
        )
        return utils.highlight_range(text, ls, 5, #text - 3)
        --
    else
        local highlight_name = nil
        local lang = vim.bo.filetype == "c" and "c" or "cpp"
        if kind == Kind.Struct or kind == Kind.Interface then
            highlight_name = "@type"
        elseif kind == Kind.Class then
            highlight_name = utils.hl_exist_or("@lsp.type.class", "@variant", lang)
        elseif kind == Kind.EnumMember then
            highlight_name = utils.hl_exist_or("@lsp.type.enumMember", "@variant", lang)
        elseif kind == Kind.Enum then
            highlight_name = utils.hl_exist_or("@lsp.type.enum", "@type", lang)
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
                        range = { vim.startswith(label, "•") and 3 or 0, end_index },
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

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.clangd(completion_item, ls)
    local vim_item = _clangd(completion_item, ls)
    local max_width = require("colorful-menu.utils").max_width()
    if vim_item.text ~= nil then
        if vim.startswith(vim_item.text, "•") then
            table.insert(vim_item.highlights, 1, {
                config.ls.clangd.import_dot_hl,
                range = { 0, 3 },
            })
        end
        vim_item.text = vim_item.text:gsub(";", " ")
        -- If it is already overflow, just return.
        if max_width and max_width > 0 then
            local display_width = vim.fn.strdisplaywidth(vim_item.text)
            if display_width >= max_width then
                return vim_item
            end
        end

        -- Append path.
        local document = completion_item.documentation
        if document and document.value and vim.startswith(document.value, "From ") then
            local len = #vim_item.text
            local include_path = vim.trim(vim.split(document.value, "\n")[1]):sub(6, #document.value)
            if include_path:sub(1, 1) == "`" and include_path:sub(#include_path, #include_path) == "`" then
                include_path = include_path:sub(2, #include_path - 1)
            end
            local spaces = path_align_spaces(vim_item.text, include_path)
            vim_item.text = string.gsub(vim_item.text .. spaces .. include_path, "\n", " ")
            table.insert(vim_item.highlights, {
                config.ls.clangd.extra_info_hl,
                range = { len + #spaces, #vim_item.text },
            })
        end
    end
    return vim_item
end

return M
