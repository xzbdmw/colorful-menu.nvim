local M = {}

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
---@return CMHighlights?
function M.default_highlight(completion_item, ls)
    local label = completion_item.label
    if label == nil then
        return nil
    end
    return M.highlight_range(label, ls, 0, #label)
end

return M
