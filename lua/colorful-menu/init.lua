local M = {}
local insertTextFormat = { PlainText = 1, Snippet = 2 }
-- stylua: ignore
M.Kind = { Text = 1, Method = 2, Function = 3, Constructor = 4, Field = 5, Variable = 6, Class = 7, Interface = 8, Module = 9, Property = 10, Unit = 11, Value = 12, Enum = 13, Keyword = 14, Snippet = 15, Color = 16, File = 17, Reference = 18, Folder = 19, EnumMember = 20, Constant = 21, Struct = 22, Event = 23, Operator = 24, TypeParameter = 25 }

---@alias CMHighlightRange {hl_group: string, range: integer[]}
---
---@class CMHighlights
---@field text string
---@field highlights CMHighlightRange[]

---@class ColorfulMenuConfig
M.config = {
    ls = {
        lua_ls = {
            -- Maybe you want to dim arguments a bit.
            arguments_hl = "@comment",
        },
        gopls = {
            -- When true, label for field and variable will format like "foo: Foo"
            -- instead of go's original syntax "foo Foo".
            add_colon_before_type = false,
        },
        ["typescript-language-server"] = {
            extra_info_hl = "@comment",
        },
        ts_ls = {
            extra_info_hl = "@comment",
        },
        vtsls = {
            extra_info_hl = "@comment",
        },
        ["rust-analyzer"] = {
            -- Such as (as Iterator), (use std::io).
            extra_info_hl = "@comment",
        },
        clangd = {
            -- Such as "From <stdio.h>".
            extra_info_hl = "@comment",
        },
        fallback = true,
    },
    fallback_highlight = "@variable",
    max_width = 60,
}

local query_cache = {}
local parser_cache = {}
local parser_cache_size = 0
local MAX_PARSER_CACHE_SIZE = 10000

---@param str string
---@param ls string
---@return CMHighlights
function M.compute_highlights(str, ls)
    local highlights = {}

    local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
    if not lang then
        return {}
    end

    local query, ok
    if query_cache[ls] == nil then
        ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
        if not ok then
            return {}
        end
        query_cache[ls] = query
    else
        query = query_cache[ls]
    end

    local parser
    if parser_cache[str .. "!!" .. ls] == nil then
        ok, parser = pcall(vim.treesitter.get_string_parser, str, lang)
        if not ok then
            return {}
        end
        parser_cache_size = parser_cache_size + 1
        if parser_cache_size > MAX_PARSER_CACHE_SIZE then
            parser_cache_size = 0
            parser_cache = {}
        end
        parser_cache[str .. "!!" .. ls] = parser
    else
        parser = parser_cache[str .. "!!" .. ls]
    end

    if not parser then
        vim.notify(string.format("No Tree-sitter parser found for filetype: %s", lang), vim.log.levels.WARN)
        return highlights
    end

    -- Parse the string
    local tree = parser:parse(true)[1]
    if not tree then
        vim.notify("Failed to parse the string with Tree-sitter.", vim.log.levels.ERROR)
        return {}
    end

    local root = tree:root()

    if not query then
        return {}
    end

    -- Iterate over all captures in the query
    for id, node in query:iter_captures(root, str, 0, -1) do
        local name = "@" .. query.captures[id] .. "." .. lang
        local range = { node:range() }
        local _, nscol, _, necol = range[1], range[2], range[3], range[4]
        table.insert(highlights, {
            hl_group = name,
            range = { nscol, necol },
        })
    end

    return highlights
end

---@diagnostic disable-next-line: undefined-doc-name
---@param entry cmp.Entry
function M.cmp_highlights(entry)
    local client = vim.tbl_get(entry, "source", "source", "client") -- For example `lua_ls` etc
    if client and not client.is_stopped() then
        ---@diagnostic disable-next-line: undefined-field
        return M.highlights(entry:get_completion_item(), client.name)
    end
    return nil
end

---@diagnostic disable-next-line: undefined-doc-name
---@param ctx blink.cmp.DrawItemContext
function M.blink_highlights(ctx)
    ---@diagnostic disable-next-line: undefined-field
    local client = vim.lsp.get_client_by_id(ctx.item.client_id)
    local highlights = {}
    if client and not client.is_stopped() then
        ---@diagnostic disable-next-line: undefined-field
        local highlights_info = M.highlights(ctx.item, client.name)
        if highlights_info ~= nil then
            for _, info in ipairs(highlights_info.highlights or {}) do
                table.insert(highlights, {
                    info.range[1],
                    info.range[2],
                    ---@diagnostic disable-next-line: undefined-field
                    group = ctx.deprecated and "BlinkCmpLabelDeprecated" or info[1],
                })
            end
        else
            return nil
        end
        return { label = highlights_info.text, highlights = highlights }
    end
    return nil
end

---@param completion_item lsp.CompletionItem
---@param ls string?
---@return CMHighlights?
function M.highlights(completion_item, ls)
    if ls == vim.bo.filetype then
        vim.notify(
            "colorful-menu.nvim: Integration with nvim-cmp or blink.cmp has been simplified, and legacy per-filetype options is also deprecated"
                .. " to prefer per-language-server options, please see README",
            vim.log.levels.WARN
        )
        return nil
    end
    if completion_item == nil or ls == nil or ls == "" or vim.b.ts_highlight == false then
        return nil
    end

    local item
    if ls == "gopls" then
        item = M.go_compute_completion_highlights(completion_item, ls)
    elseif ls == "rust-analyzer" then
        item = M.rust_compute_completion_highlights(completion_item, ls)
    elseif ls == "lua_ls" then
        item = M.lua_compute_completion_highlights(completion_item, ls)
    elseif ls == "clangd" then
        item = M.c_compute_completion_highlights(completion_item, ls)
    elseif ls == "typescript-language-server" or ls == "ts_ls" then
        item = M.typescript_language_server_label_for_completion(completion_item, ls)
    elseif ls == "vtsls" then
        item = M.vtsls_compute_completion_highlights(completion_item, ls)
    elseif ls == "intelephense" then
        item = M.php_intelephense_compute_completion_highlights(completion_item, ls)
    else
        -- No languages detected so check if we should highlight with default or not
        if not M.config.ls.fallback then
            return nil
        end
        item = M.default_highlight(completion_item, ls)
    end

    if item then
        M.apply_post_processing(item)
    end

    return item
end

---@param item CMHighlights
---@return CMHighlights?
function M.apply_post_processing(item)
    -- if the user override or fallback logic didn't produce a table, bail
    if type(item) ~= "table" or not item.text then
        return item
    end

    local text = item.text
    local max_width = M.config.max_width

    if max_width and max_width > 0 then
        -- if text length is beyond max_width, truncate
        local display_width = vim.fn.strdisplaywidth(text)
        if display_width > max_width then
            -- We can remove from the end
            -- or do partial truncation using `strcharpart` or `strdisplaywidth` logic.
            local truncated = vim.fn.strcharpart(text, 0, max_width - 1) .. "…"
            item.text = truncated
        end
    end
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.rust_compute_completion_highlights(completion_item, ls)
    local vim_item = M._rust_compute_completion_highlights(completion_item, ls)
    if vim_item.text ~= nil then
        for _, match in ipairs({ "%(use .-%)", "%(as .-%)", "%(alias .-%)" }) do
            local s, e = string.find(vim_item.text, match)
            if s ~= nil and e ~= nil then
                table.insert(vim_item.highlights, {
                    M.config.ls["rust-analyzer"].extra_info_hl,
                    range = { s - 1, e },
                })
            end
        end
    end
    return vim_item
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights?
function M.default_highlight(completion_item, ls)
    local label = completion_item.label
    if label == nil then
        return nil
    end
    return M.highlight_range(label, ls, 0, #label)
end

---@param hl_group string
---@param fallback string
function M.hl_exist_or(hl_group, fallback)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = hl_group })
    if ok and hl ~= nil then
        return hl_group
    else
        return fallback
    end
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M._rust_compute_completion_highlights(completion_item, ls)
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    local function_signature = completion_item.labelDetails and completion_item.labelDetails.description
        or completion_item.detail

    local kind = completion_item.kind
    if not kind then
        return M.highlight_range(completion_item.label, ls, 0, #completion_item.label)
    end

    if kind == M.Kind.Field and detail then
        local name = completion_item.label
        local text = string.format("%s: %s", name, detail)
        local source = string.format("struct S { %s }", text)
        return M.highlight_range(source, ls, 11, 11 + #text)
        --
    elseif
        (kind == M.Kind.Constant or kind == M.Kind.Variable)
        and detail
        and completion_item.insertTextFormat ~= insertTextFormat.Snippet
    then
        local name = completion_item.label
        local text = string.format("%s: %s", name, completion_item.detail or detail)
        local source = string.format("let %s = ();", text)
        return M.highlight_range(source, ls, 4, 4 + #text)
        --
    elseif (kind == M.Kind.EnumMember) and detail then
        return M.highlight_range(detail, ls, 0, #detail)
        --
    elseif (kind == M.Kind.Function or kind == M.Kind.Method) and detail then
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

            return M.highlight_range(source, ls, #prefix + 1, #source - 3)
        else
            -- Check if the detail starts with "macro_rules! "
            if completion_item.detail and vim.startswith(completion_item.detail, "macro") then
                local source = completion_item.label
                return M.highlight_range(source, ls, 0, #source)
            else
                -- simd_swizzle!()
                return {
                    text = completion_item.label,
                    highlights = {
                        {
                            M.config.fallback_highlight,
                            range = { 0, #completion_item.label },
                        },
                    },
                }
            end
        end
        --
    else
        local highlight_name = nil
        if kind == M.Kind.Struct then
            highlight_name = "@type"
            --
        elseif kind == M.Kind.Enum then
            highlight_name = M.hl_exist_or("@lsp.type.enum.rust", "@type")
            --
        elseif kind == M.Kind.EnumMember then
            highlight_name = M.hl_exist_or("@lsp.type.enumMember.rust", "@constant")
            --
        elseif kind == M.Kind.Interface then
            highlight_name = M.hl_exist_or("@lsp.type.interface.rust", "@type")
            --
        elseif kind == M.Kind.Keyword then
            highlight_name = "@keyword"
            --
        elseif kind == M.Kind.Value or kind == M.Kind.Constant then
            highlight_name = "@constant"
            --
        else
            highlight_name = M.config.fallback_highlight
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

-- `left` is inclusive and `right` is exclusive (also zero indexed), to better fit
-- `nvim_buf_set_extmark` semantic, so `M.highlight_range(text, ft, 0, #text)` is the entire range.
--
---@param text string
---@param ls string
---@param left integer
---@param right integer
---@return CMHighlights
function M.highlight_range(text, ls, left, right)
    local highlights = {}
    local full_hl = M.compute_highlights(text, ls)

    for _, hl in ipairs(full_hl) do
        local s, e = hl.range[1], hl.range[2]
        if e < left then
            goto continue
        end
        if s > right or e > right + 1 then
            break
        end

        table.insert(highlights, {
            hl.hl_group,
            range = { hl.range[1] - left, hl.range[2] - left },
            text = text:sub(s + 1, e),
        })
        ::continue::
    end

    return {
        text = text:sub(left + 1, right),
        highlights = highlights,
    }
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.lua_compute_completion_highlights(completion_item, ls)
    local vim_item = M._lua_compute_completion_highlights(completion_item, ls)
    if vim_item.text ~= nil then
        local s, e = string.find(vim_item.text, "%b()")
        if s ~= nil and e ~= nil then
            table.insert(vim_item.highlights, {
                M.config.ls.lua_ls.arguments_hl,
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
        return M.highlight_range(label, ls, 0, #label)
    end
    if kind == M.Kind.Field then
        local text = string.format("%s", label)
        local source = string.format("v.%s", text)
        return M.highlight_range(source, ls, 2, 2 + #text)
    else
        return M.highlight_range(label, ls, 0, #label)
    end
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.typescript_language_server_label_for_completion(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.detail
    local kind = completion_item.kind
    -- Combine label + detail for final display
    local text = detail and (label .. " " .. detail) or label

    if not kind then
        return M.highlight_range(text, ls, 0, #text)
    end

    local highlight_name
    if kind == M.Kind.Class or kind == M.Kind.Interface or kind == M.Kind.Enum then
        highlight_name = "@type"
    elseif kind == M.Kind.Constructor then
        highlight_name = "@type"
    elseif kind == M.Kind.Constant then
        highlight_name = "@constant"
    elseif kind == M.Kind.Function or kind == M.Kind.Method then
        highlight_name = "@function"
    elseif kind == M.Kind.Property or kind == M.Kind.Field then
        highlight_name = "@property"
    elseif kind == M.Kind.Variable then
        highlight_name = "@variable"
    else
        highlight_name = M.config.fallback_highlight
    end

    local highlights = {
        {
            highlight_name,
            range = { 0, #label },
        },
    }

    if detail then
        table.insert(highlights, {
            ls == "typescript-language-server" and M.config.ls["typescript-language-server"].extra_info_hl
                or M.config.ls.ts_ls.extra_info_hl,
            range = { #label + 1, #label + 1 + #detail },
        })
    end

    return {
        text = text,
        highlights = highlights,
    }
end

-- see https://github.com/zed-industries/zed/pull/13043
-- Untested.
---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.vtsls_compute_completion_highlights(completion_item, ls)
    local function one_line(s)
        s = s:gsub("    ", "")
        s = s:gsub("\n", " ")
        return s
    end

    local label = completion_item.label

    local kind = completion_item.kind
    if not kind then
        return M.highlight_range(label, ls, 0, #label)
    end

    local highlight_name
    if kind == M.Kind.Class or kind == M.Kind.Interface or kind == M.Kind.Enum then
        highlight_name = "@type"
    elseif kind == M.Kind.Constructor then
        highlight_name = "@type"
    elseif kind == M.Kind.Constant then
        highlight_name = "@constant"
    elseif kind == M.Kind.Function or kind == M.Kind.Method then
        highlight_name = "@function"
    elseif kind == M.Kind.Property or kind == M.Kind.Field then
        highlight_name = "@property"
    elseif kind == M.Kind.Variable then
        highlight_name = "@variable"
    else
        highlight_name = M.config.fallback_highlight
    end

    local description = completion_item.labelDetails and completion_item.labelDetails.description
    local detail = completion_item.detail

    local highlights = {
        {
            highlight_name,
            range = { 0, #label },
        },
    }
    local text = label
    if description then
        text = label .. " " .. one_line(description)
        table.insert(highlights, {
            M.config.ls.vtsls.extra_info_hl,
            range = { #label + 1, #text - 1 },
        })
    elseif detail then
        text = label .. " " .. one_line(detail)
        table.insert(highlights, {
            M.config.ls.vtsls.extra_info_hl,
            range = { #label + 1, #text - 1 },
        })
    end

    return {
        text = text,
        highlights = highlights,
    }
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.c_compute_completion_highlights(completion_item, ls)
    local vim_item = M._c_compute_completion_highlights(completion_item, ls)
    if vim_item.text ~= nil then
        vim_item.text = vim_item.text:gsub(";", " ")
        local document = completion_item.documentation
        if document and document.value and vim.startswith(document.value, "From ") then
            local len = #vim_item.text
            vim_item.text = string.gsub(vim_item.text .. "  " .. document.value, "\n", " ")
            table.insert(vim_item.highlights, {
                M.config.ls.clangd.extra_info_hl,
                range = { len + 2, #vim_item.text },
            })
        end
    end
    return vim_item
end

-- Add this in your module, alongside the other compute functions
---
---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M._c_compute_completion_highlights(completion_item, ls)
    local label = completion_item.label
    local kind = completion_item.kind
    local detail = completion_item.detail
    local labelDetails = completion_item.labelDetails

    -- If no kind, just fallback to highlighting the cleaned-up label
    if not kind then
        return M.highlight_range(label, ls, 0, #label)
    end

    -- Fields with detail => "detail label" => highlight in "struct S { ... }"
    if (kind == M.Kind.Field) and detail then
        local text = string.format("%s %s", detail, label)
        local source = string.format("struct S { %s }", text)
        -- offset 11 is after "struct S { "
        return M.highlight_range(source, ls, 11, 11 + #text)

        -- Constants or Variables with detail => "detail label", highlight entire text
    elseif (kind == M.Kind.Constant or kind == M.Kind.Variable) and detail then
        local text = string.format("%s;%s", label, detail)
        -- void foo() {&x;std::unique_ptr<Foo>}
        --             |         |
        --          @variable    |-- @type
        -- later factor to `x std::unique_ptr<Foo>`.
        local source = string.format("void foo(){ &%s }", text)
        return M.highlight_range(source, ls, 13, 13 + #text)

        -- Functions or Methods with detail => "detail label", might find '('
    elseif (kind == M.Kind.Function or kind == M.Kind.Method) and detail then
        local signature = ""
        if labelDetails and labelDetails.detail then
            signature = labelDetails.detail
        end
        local text = string.format("void %s%s;%s", label, signature, detail)
        return M.highlight_range(text, ls, 5, #text)
        --
    else
        local highlight_name = nil
        if kind == M.Kind.Struct or kind == M.Kind.Interface then
            highlight_name = "@type"
        elseif kind == M.Kind.Class then
            highlight_name = M.hl_exist_or("@lsp.type.class", "@variant")
        elseif kind == M.Kind.EnumMember then
            highlight_name = M.hl_exist_or("@lsp.type.enumMember", "@variant")
        elseif kind == M.Kind.Enum then
            highlight_name = M.hl_exist_or("@lsp.type.enum", "@type")
        elseif kind == M.Kind.Keyword then
            highlight_name = "@keyword"
        elseif kind == M.Kind.Value or kind == M.Kind.Constant then
            highlight_name = "@constant"
        else
            highlight_name = M.config.fallback_highlight
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

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.go_compute_completion_highlights(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    local kind = completion_item.kind

    if not kind then
        return M.highlight_range(label, ls, 0, #label)
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

    if kind == M.Kind.Module and detail then
        local text = string.format("%s %s", label, detail)
        local source = string.format("import %s", text)
        return M.highlight_range(source, ls, 7, 7 + #text)
        --
    elseif (kind == M.Kind.Constant or kind == M.Kind.Variable) and detail then
        local text
        if M.config.ls.gopls.add_colon_before_type then
            text = string.format("%s: %s", label, detail)
        else
            text = string.format("%s %s", label, detail)
        end
        local var_part = text:sub(name_offset)
        local source = string.format("var %s", var_part)
        local item = M.highlight_range(source, ls, 4, 4 + #var_part)
        return M.adjust_range(item, name_offset, text)
        --
    elseif kind == M.Kind.Struct then
        local text = string.format("%s", label)
        local source = string.format("type %s struct {}", text:sub(name_offset))
        local item = M.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return M.adjust_range(item, name_offset, text)
        --
    elseif kind == M.Kind.Interface then
        local text = string.format("%s", label)
        local source = string.format("type %s interface {}", text:sub(name_offset))
        local item = M.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return M.adjust_range(item, name_offset, text)
        --
    elseif kind == M.Kind.Field and detail then
        local text
        if M.config.ls.gopls.add_colon_before_type then
            text = string.format("%s: %s", label, detail)
        else
            text = string.format("%s %s", label, detail)
        end
        local source = string.format("type T struct { %s }", text:sub(name_offset))
        local item = M.highlight_range(source, ls, 16, 16 + #text:sub(name_offset))
        return M.adjust_range(item, name_offset, text)
        --
    elseif (kind == M.Kind.Function or kind == M.Kind.Method) and detail then
        if detail:sub(1, 4) == "func" then
            local signature = detail:sub(5)
            local text = string.format("%s%s", label, signature)
            local source = string.format("func %s {}", text:sub(name_offset))
            local item = M.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
            return M.adjust_range(item, name_offset, text)
        end
        --
    else
        -- Handle other kinds
        local highlight_name = nil
        if kind == M.Kind.Keyword then
            highlight_name = "@keyword"
        else
            highlight_name = M.config.fallback_highlight
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

---@param item CMHighlights
---@param name_offset integer
---@param label string
---@return CMHighlights
function M.adjust_range(item, name_offset, label)
    if name_offset == 0 then
        return item
    end
    name_offset = name_offset - 1
    for _, highlight in ipairs(item.highlights) do
        highlight.range[1] = highlight.range[1] + name_offset
        highlight.range[2] = highlight.range[2] + name_offset
    end
    item.text = label:sub(1, name_offset) .. item.text
    table.insert(item.highlights, {
        "@variable",
        range = { 0, name_offset },
    })
    return item
end

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.php_intelephense_compute_completion_highlights(completion_item, ls)
    local label = completion_item.label
    local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
    local kind = completion_item.kind

    if (kind == M.Kind.Function or kind == M.Kind.Method) and detail and #detail > 0 then
        local signature = detail:sub(#label + 1)
        local text = string.format("%s <?php fn %s {}", label, signature)
        local item = M.highlight_range(text, ls, 6 + #label, #text - 2)
        return M.adjust_range(item, #label + 1, label)
        --
    elseif kind == M.Kind.EnumMember and detail and #detail > 0 then
        local text = string.format("%s <?php %s;", label, detail)
        local item = M.highlight_range(text, ls, #label + 6, #text - 1)
        return M.adjust_range(item, #label + 1, label)
        --
    elseif (kind == M.Kind.Property or kind == M.Kind.Variable) and detail and #detail > 0 then
        detail = string.gsub(detail, ".*\\(.)", "%1")
        local text = string.format("%s <?php fn(): %s;", label, detail)
        local item = M.highlight_range(text, ls, #label + 12, #text - 1)
        return M.adjust_range(item, #label + 1, label)
        --
    elseif kind == M.Kind.Constant and detail and #detail > 0 then
        local text = string.format("%s <?php %s;", label, detail)
        local item = M.highlight_range(text, ls, #label + 6, #text - 1)
        return M.adjust_range(item, #label + 1, label)
        --
    else
        -- Handle other kinds
        local highlight_name = nil
        if kind == M.Kind.Keyword then
            highlight_name = "@keyword"
        else
            highlight_name = M.config.fallback_highlight
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

---@param opts ColorfulMenuConfig
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
