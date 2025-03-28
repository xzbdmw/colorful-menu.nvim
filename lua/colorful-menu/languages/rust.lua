local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local insertTextFormat = require("colorful-menu").insertTextFormat
local config = require("colorful-menu").config

local M = {}

local function align_spaces(abbr, detail)
    if config.ls["rust-analyzer"].align_type_to_right == false then
        return " "
    end
    return utils.align_spaces_bell(abbr, detail)
end

local cashed_self_hl = nil
---@return CMHighlightRange[]
local function iter_chain()
    if cashed_self_hl == nil then
        local source = "fn iter(){}"
        local hl = utils.highlight_range(source, "rust-analyzer", 3, #source - 2)
        cashed_self_hl = hl.highlights
    end
    return cashed_self_hl
end

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
        local text = string.format("%s:%s%s", name, align_spaces(name .. " ", detail), detail)
        local source = string.format("struct S { %s }", text)
        local hl = utils.highlight_range(source, ls, 11, 11 + #text)
        if config.ls["rust-analyzer"].align_type_to_right == false then
            return hl
        end
        hl.text = hl.text:sub(1, #name) .. " " .. hl.text:sub(#name + 2, #text)
        return hl
        --
    elseif
        (kind == Kind.Constant or kind == Kind.Variable)
        and detail
        and completion_item.insertTextFormat ~= insertTextFormat.Snippet
    then
        local name = completion_item.label
        local text = string.format(
            "%s:%s%s",
            name,
            align_spaces(name .. " ", completion_item.detail),
            completion_item.detail or detail
        )
        local source = string.format("let %s = ();", text)
        local hl = utils.highlight_range(source, ls, 4, 4 + #text)
        if config.ls["rust-analyzer"].align_type_to_right == false then
            return hl
        end
        hl.text = hl.text:sub(1, #name) .. " " .. hl.text:sub(#name + 2, #text)
        return hl
        --
    elseif (kind == Kind.EnumMember) and detail then
        local source = string.format("enum S { %s }", detail)
        return utils.highlight_range(source, ls, 9, 9 + #detail)
        --
    elseif (kind == Kind.Function or kind == Kind.Method) and detail then
        local pattern = "%((.-)%)"
        local label = completion_item.label

        local ignored = nil
        if label:match("^iter%(%)%..+") ~= nil then
            ignored = "iter()."
            label = completion_item.label:sub(string.len(ignored) + 1)
        end
        if label:match("^self%..+") ~= nil then
            ignored = "self."
            label = completion_item.label:sub(string.len(ignored) + 1)
        end
        local function adjust(hl)
            if ignored == "self." then
                utils.adjust_range(hl, string.len(ignored) + 1, ignored)
            elseif ignored == "iter()." then
                utils.adjust_range(hl, string.len(ignored) + 1, ignored, nil, iter_chain())
            end
        end

        local result = string.match(label, pattern)
        if not result then
            label = label .. "()"
        end
        local regex_pattern = "%b()"
        local prefix, suffix = string.match(function_signature or "", "^(.*fn)(.*)$")
        if prefix ~= nil and suffix ~= nil then
            local start_pos = string.find(suffix, "(", nil, true)
            if start_pos then
                suffix = suffix:sub(start_pos, #suffix)
            end

            if
                config.ls["rust-analyzer"].preserve_type_when_truncate
                and config.ls["rust-analyzer"].align_type_to_right
            then
                local params, type = string.match(suffix, "(%b()) %-> (.*)")
                if params == nil and type == nil then
                    params = suffix
                    type = ""
                end
                local call, num_subs = string.gsub(label, regex_pattern, params, 1)
                if num_subs == 0 then
                    call = completion_item.label
                end
                local source = string.format(
                    "%s %s->%s%s{}",
                    prefix,
                    call,
                    align_spaces(call .. "  ", ignored ~= nil and type .. ignored or type),
                    type or ""
                )
                local hl = utils.highlight_range(source, ls, #prefix + 1, #source - 2)
                hl.text = hl.text:sub(1, #call) .. "  " .. hl.text:sub(#call + 3)
                if ignored ~= nil then
                    adjust(hl)
                end
                return hl
            else
                local call, num_subs = string.gsub(label, regex_pattern, suffix, 1)
                if num_subs == 0 then
                    call = label
                end
                local source = string.format("%s %s {}", prefix, call)
                local hl = utils.highlight_range(source, ls, #prefix + 1, #source - 3)
                if ignored ~= nil then
                    adjust(hl)
                end
                return hl
            end
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
        elseif kind == Kind.Enum then
            highlight_name = utils.hl_exist_or("@lsp.type.enum", "@type", "rust")
        elseif kind == Kind.EnumMember then
            highlight_name = utils.hl_exist_or("@lsp.type.enumMember", "@constant", "rust")
        elseif kind == Kind.Interface then
            highlight_name = utils.hl_exist_or("@lsp.type.interface", "@type", "rust")
        elseif kind == Kind.Keyword then
            highlight_name = "@keyword"
        elseif kind == Kind.Value or kind == Kind.Constant then
            highlight_name = "@constant"
        else
            highlight_name = config.fallback_highlight
        end

        if detail then
            detail = vim.trim(detail)
            if vim.startswith(detail, "(") then
                local space = align_spaces(completion_item.label, detail)
                return {
                    text = completion_item.label .. space .. detail,
                    highlights = {
                        {
                            highlight_name,
                            range = { 0, #completion_item.label },
                        },
                        {
                            config.ls["rust-analyzer"].extra_info_hl,
                            range = { #completion_item.label + #space, #completion_item.label + #space + #detail },
                        },
                    },
                }
            end
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
                    config.ls["rust-analyzer"].extra_info_hl,
                    range = { s - 1, e },
                })
            end
        end
    end
    return vim_item
end

return M
