local utils = require("colorful-menu.utils")
local Kind = require("colorful-menu").Kind
local config = require("colorful-menu").config

local M = {}

---@param completion_item lsp.CompletionItem
---@param ls string
---@return CMHighlights
function M.gopls(completion_item, ls)
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
        local text = string.format("%s%s%s", label, M.get_bank(label, detail), detail)
        local source = string.format("import %s", text)
        return utils.highlight_range(source, ls, 7, 7 + #text)
        --
    elseif (kind == Kind.Constant or kind == Kind.Variable) and detail then
        local text
        if config.ls.gopls.add_colon_before_type then
            text = string.format("%s:%s%s", label, M.get_bank(label, detail), detail)
        else
            text = string.format("%s%s%s", label, M.get_bank(label, detail), detail)
        end
        local var_part = text:sub(name_offset)
        local source = string.format("var %s", var_part)
        local item = utils.highlight_range(source, ls, 4, 4 + #var_part)
        return utils.adjust_range(item, name_offset, text)
        --
    elseif kind == Kind.Struct then
        detail = " struct{}"
        local text = string.format("%s%s%s", label, M.get_bank(label, detail), detail)
        local source = string.format("type %s struct {}", text:sub(name_offset))
        local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return utils.adjust_range(item, name_offset, text)
        --
    elseif kind == Kind.Interface then
        detail = "interface{}"
        local text = string.format("%s%s%s", label, M.get_bank(label, detail), detail)
        local source = string.format("type %s interface {}", text:sub(name_offset))
        local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
        return utils.adjust_range(item, name_offset, text)
        --
    elseif kind == Kind.Field and detail then
        local text
        if config.ls.gopls.add_colon_before_type then
            text = string.format("%s:%s%s", label, M.get_bank(label, detail), detail)
        else
            text = string.format("%s%s%s", label, M.get_bank(label, detail), detail)
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
                    text = label .. M.get_bank(label, signature) .. signature
                else
                    local params, returns = M.parseFunctionSignature(signature)
                    text = label .. params .. M.get_bank(label, signature) .. returns
                end
            end

            local source = string.format("func %s {}", text:sub(name_offset))
            local item = utils.highlight_range(source, ls, 5, 5 + #text:sub(name_offset))
            return utils.adjust_range(item, name_offset, text)
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

function M.get_bank(abbr, detail)
    if config.ls.gopls.alignment == false then
        return " "
    end
    local bank = config.max_width - M.utf8len(abbr) - M.utf8len(detail)
    if bank < 0 then
        bank = 0
    end
    return string.format("%" .. bank .. "s", "")
end

function M.utf8len(input)
    local len  = string.len(input)                   --这里获取到的长度为字节数，如示例长度为：21，而我们肉眼看到的长度应该是15（包含空格）
    local left = len                                 --将字节长度赋值给将要使用的变量，作为判断退出while循环的字节长度
    local cnt  = 0                                   --将要返回的字符长度
    local arr  = { 0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc } --用来判断是否满足字节长度的列表
    while left ~= 0 do                               --遍历每一个字符
        --获取字节的ASCII值，这里的 “-” 代表反向对应的索引，-left：input反着第left
        --假设字符串字符input长度是：21，left的值是：21，那string.byte(input, -left)就是第一个字节的ASCII值
        local tmp = string.byte(input, -left) --看上面两行
        local i   = #arr                      --获取判断列表的长度，同时作为字节长度
        while arr[i] do                       --循环判定列表
            if tmp >= arr[i] then             --判定当前 “字符” 的 头“字节” ACSII值符合的范围
                left = left - i               --字符串字节长度 -i，也就是 减去字节长度
                break                         --结束判断
            end
            i = i - 1                         --每次判断失败都说明不符合当前字节长度
        end
        cnt = cnt + 1                         --“字符” 长度+1
    end
    return cnt                                --返回 “字符” 长度
end

function M.parseFunctionSignature(signature)
    -- 匹配参数和返回值的模式
    local paramPattern = "^%((.-)%)"
    local returnPattern = "%)(%s*%b())$"
    local mixedPattern = "^%((.-)%)%s*(.*)$"

    local params, returns

    -- 尝试匹配参数和返回值都在括号内的情况
    local paramMatch = signature:match(paramPattern)
    local returnMatch = signature:match(returnPattern)

    if paramMatch then
        params = "(" .. paramMatch .. ")"
    end

    if returnMatch then
        returns = returnMatch
    end

    -- 如果没有匹配到返回值，尝试匹配参数在括号内，返回值在括号外的情况
    if not returns then
        local mixedParam, mixedReturn = signature:match(mixedPattern)
        if mixedParam then
            params = "(" .. mixedParam .. ")"
        end
        if mixedReturn then
            returns = mixedReturn
        end
    end

    if params == nil then
        params = "()"
    end

    if returns == nil then
        returns = ""
    end

    return params, returns
end

return M
