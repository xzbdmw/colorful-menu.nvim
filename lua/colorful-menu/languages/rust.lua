local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local insertTextFormat = require("colorful-menu").insertTextFormat
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
local function _rust_analyzer(completion_item, ls)
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    local function_signature = completion_item.labelDetails and completion_item.labelDetails.description
        or completion_item.detail

    local kind = completion_item.kind
    if not kind then
        return utils.highlight_range(completion_item.label, ls, 0, #completion_item.label)
    end

    if kind == Kind.Field and detail then
        local name = completion_item.label
        local text = string.format("%s: %s", name, detail)
        local source = string.format("struct S { %s }", text)
        return utils.highlight_range(source, ls, 11, 11 + #text)
        --
    elseif
        (kind == Kind.Constant or kind == Kind.Variable)
        and detail
        and completion_item.insertTextFormat ~= insertTextFormat.Snippet
    then
        local name = completion_item.label
        local text = string.format("%s: %s", name, completion_item.detail or detail)
        local source = string.format("let %s = ();", text)
        return utils.highlight_range(source, ls, 4, 4 + #text)
        --
    elseif (kind == Kind.EnumMember) and detail then
        return utils.highlight_range(detail, ls, 0, #detail)
        --
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        local pattern = "%((.-)%)"
        local result = string.match(completion_item.label, pattern)
        local label = completion_item.label
        if not result then
            label = completion_item.label .. "()"
        end
        local regex_pattern = "%b()"
        local prefix, suffix = string.match(function_signature or "", "^(.*fn)(.*)$")
        if prefix ~= nil and suffix ~= nil then
            local start_pos = string.find(suffix, "(", nil, true)
            if start_pos then
                suffix = suffix:sub(start_pos, #suffix)
            end
            -- Replace the regex pattern in completion.label with the suffix
            local text, num_subs = string.gsub(label, regex_pattern, suffix, 1)
            -- If no substitution occurred, use the original label
            if num_subs == 0 then
                text = label
            end

            -- Construct the fake source string as in Rust
            local source = string.format("%s %s {}", prefix, text)

            return utils.highlight_range(source, ls, #prefix + 1, #source - 3)
        else
            -- Check if the detail starts with "macro_rules! "
            if completion_item.detail and vim.startswith(completion_item.detail, "macro") then
                local source = completion_item.label
                return utils.highlight_range(source, ls, 0, #source)
            else
                -- simd_swizzle!()
                return {
                    text = completion_item.label,
                    highlights = {
                        {
                            config.fallback_highlight,
                            range = { 0, #completion_item.label },
                        },
                    },
                }
            end
        end
        --
    else
        local highlight_name = nil
        if kind == Kind.Struct then
            highlight_name = "@type"
            --
        elseif kind == Kind.Enum then
            highlight_name = utils.hl_exist_or("@lsp.type.enum.rust", "@type")
            --
        elseif kind == Kind.EnumMember then
            highlight_name = utils.hl_exist_or("@lsp.type.enumMember.rust", "@constant")
            --
        elseif kind == Kind.Interface then
            highlight_name = utils.hl_exist_or("@lsp.type.interface.rust", "@type")
            --
        elseif kind == Kind.Keyword then
            highlight_name = "@keyword"
            --
        elseif kind == Kind.Value or kind == Kind.Constant then
            highlight_name = "@constant"
            --
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

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.rust_analyzer(completion_item, ls)
    local vim_item = _rust_analyzer(completion_item, ls)
    if vim_item.text ~= nil then
        for _, match in ipairs({ "%(use .-%)", "%(as .-%)", "%(alias .-%)" }) do
            local s, e = string.find(vim_item.text, match)
            if s ~= nil and e ~= nil then
                table.insert(vim_item.highlights, {
                    config.ls.rust_analyzer.extra_info_hl,
                    range = { s - 1, e },
                })
            end
        end
    end
    return vim_item
end

return M
