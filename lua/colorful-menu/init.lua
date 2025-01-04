local M = {}
local insertTextFormat = { PlainText = 1, Snippet = 2 }
-- stylua: ignore
M.Kind = { Text = 1, Method = 2, Function = 3, Constructor = 4, Field = 5, Variable = 6, Class = 7, Interface = 8, Module = 9, Property = 10, Unit = 11, Value = 12, Enum = 13, Keyword = 14, Snippet = 15, Color = 16, File = 17, Reference = 18, Folder = 19, EnumMember = 20, Constant = 21, Struct = 22, Event = 23, Operator = 24, TypeParameter = 25 }

local default_config = {
	ft = {
		lua = {
			-- Maybe you want to dim arguments a bit.
			auguments_hl = "@comment",
		},
		typescript = {
			-- Or "vtsls", their information is different, so we
			-- need to know in advance.
			ls = "typescript-language-server",
			extra_info_hl = "@comment",
		},
		rust = {
			-- such as (as Iterator), (use std::io).
			extra_info_hl = "@comment",
			overrides = {
				-- [3] = function(completion_item) end, -- 3 = Function, for all the kinds, see https://github.com/xzbdmw/colorful-menu.nvim/blob/56871ac630383d4135b7b123e5dc2dafb22e76f7/lua/colorful-menu/init.lua#L4
			},
		},
		c = {
			-- such as "From <stdio.h>"
			extra_info_hl = "@comment",
			overrides = {
				-- [6] = function(completion_item) end, -- 6 = Variable
			},
		},
		fallback = true,
	},
	fallback_highlight = "@variable",
	max_width = 60,
}

M.config = vim.tbl_deep_extend("force", {}, default_config)

local query_cache = {}
local parser_cache = {}

function M.compute_highlights(str, filetype)
	local highlights = {}

	local query, ok
	if query_cache[filetype] == nil then
		ok, query = pcall(vim.treesitter.query.get, filetype, "highlights")
		if not ok then
			return {}
		end
		query_cache[filetype] = query
	else
		query = query_cache[filetype]
	end

	local parser
	if parser_cache[str .. "!!" .. filetype] == nil then
		ok, parser = pcall(vim.treesitter.get_string_parser, str, filetype)
		if not ok then
			return {}
		end
		parser_cache[str .. "!!" .. filetype] = parser
	else
		parser = parser_cache[str .. "!!" .. filetype]
	end

	if not parser then
		vim.notify(string.format("No Tree-sitter parser found for ft: %s", filetype), vim.log.levels.WARN)
		return highlights
	end

	-- Parse the string
	local tree = parser:parse(true)[1]
	if not tree then
		vim.notify("Failed to parse the string with Tree-sitter.", vim.log.levels.ERROR)
		return {}
	end

	-- Get the root node of the syntax tree
	local root = tree:root()
	-- Iterate over all captures in the query
	for id, node in query:iter_captures(root, str, 0, -1) do
		local name = "@" .. query.captures[id] .. "." .. filetype
		local range = { node:range() }
		local _, nscol, _, necol = range[1], range[2], range[3], range[4]
		-- Insert the highlight information into the highlights table
		table.insert(highlights, {
			hl_group = name,
			range = { nscol, necol },
		})
	end

	return highlights
end

function M.highlights(completion_item, ft)
	if ft == nil or ft == "" then
		return nil
	end
	local kind = completion_item.kind
	local ft_config = M.config.ft[ft] or {}

	-- If there's an overrides table and a matching kind override, call it
	local overrides = ft_config.overrides or {}
	if kind and overrides[kind] then
		local override_func = overrides[kind]
		local result = override_func(completion_item)
		return M.apply_post_processing(result)
	end

	local item
	if ft == "go" then
		item = M.go_compute_completion_highlights(completion_item, ft)
	elseif ft == "rust" then
		item = M.rust_compute_completion_highlights(completion_item, ft)
	elseif ft == "lua" then
		item = M.lua_compute_completion_highlights(completion_item, ft)
	elseif ft == "c" then
		item = M.c_compute_completion_highlights(completion_item, ft)
	elseif ft == "typescript" then
		if M.config.ft.typescript.ls == "typescript-language-server" then
			item = M.typescript_language_server_label_for_completion(completion_item, ft)
		elseif M.config.ft.typescript.ls == "vtsls" then
			item = M.vtsls_compute_completion_highlights(completion_item, ft)
		else
			vim.notify("unknown language server name for typescript", vim.log.levels.WARN)
			return
		end
	else
		-- No languages detected so check if we should highlight with default or not
		if not M.config.ft.fallback then
			return nil
		end

		item = M.default_highlight(completion_item, ft)
	end

	M.apply_post_processing(item)
	return item
end

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

function M.rust_compute_completion_highlights(completion_item, ft)
	local vim_item = M._rust_compute_completion_highlights(completion_item, ft)
	if vim_item.text ~= nil then
		for _, match in ipairs({ "%(use .-%)", "%(as .-%)", "%(alias .-%)" }) do
			local s, e = string.find(vim_item.text, match)
			if s ~= nil and e ~= nil then
				table.insert(vim_item.highlights, {
					M.config.ft.rust.extra_info_hl,
					range = { s - 1, e },
				})
			end
		end
	end
	return vim_item
end

function M.default_highlight(completion_item, ft)
	local label = completion_item.label
	if label == nil then
		return ""
	end
	return M.highlight_range(label, ft, 0, #label - 1)
end

function M._rust_compute_completion_highlights(completion_item, ft)
	local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
	local function_signature = completion_item.labelDetails and completion_item.labelDetails.description
		or completion_item.detail

	local kind = completion_item.kind
	if not kind then
		return M.highlight_range(completion_item.label, ft, 0, #completion_item.label - 1)
	end

	if kind == M.Kind.Field and detail then
		local name = completion_item.label
		local text = string.format("%s: %s", name, detail)
		local source = string.format("struct S { %s }", text)
		return M.highlight_range(source, ft, 11, 11 + #text)
	elseif
		(kind == M.Kind.Constant or kind == M.Kind.Variable)
		and detail
		and completion_item.insertTextFormat ~= insertTextFormat.Snippet
	then
		local name = completion_item.label
		local text = string.format("%s: %s", name, completion_item.detail or detail)
		local source = string.format("let %s = ();", text)
		return M.highlight_range(source, ft, 4, 4 + #text)
	elseif (kind == M.Kind.Function or kind == M.Kind.Method) and detail then
		local pattern = "%((.-)%)"
		local result = string.match(completion_item.label, pattern)
		local label = completion_item.label
		if not result then
			label = completion_item.label .. "()"
		end
		local regex_pattern = "%b()"
		local prefix, suffix = string.match(function_signature, "^(.*fn)(.*)$")
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

			return M.highlight_range(source, ft, #prefix + 1, #source - 4)
		else
			-- Check if the detail starts with "macro_rules! "
			if completion_item.detail and vim.startswith(completion_item.detail, "macro_rules") then
				local source = completion_item.label
				return M.highlight_range(source, ft, 0, #source - 1)
			end
		end
	else
		-- Handle other kinds
		local highlight_name = nil
		if kind == M.Kind.Struct or kind == M.Kind.Interface or kind == M.Kind.Enum then
			highlight_name = "@type"
		elseif kind == M.Kind.EnumMember then
			highlight_name = "@variant"
		elseif kind == M.Kind.Keyword then
			highlight_name = "@keyword"
		elseif kind == M.Kind.Value or kind == M.Kind.Constant then
			highlight_name = "@constant"
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
	-- unreachable
	return {}
end

function M.highlight_range(text, ft, left, right)
	local highlights = {}
	local full_hl = M.compute_highlights(text, ft)

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
		text = text:sub(left + 1, right + 1),
		highlights = highlights,
	}
end

function M.lua_compute_completion_highlights(completion_item, ft)
	local vim_item = M._lua_compute_completion_highlights(completion_item, ft)
	if vim_item.text ~= nil then
		local s, e = string.find(vim_item.text, "%b()")
		if s ~= nil and e ~= nil then
			table.insert(vim_item.highlights, {
				M.config.ft.lua.auguments_hl,
				range = { s - 1, e },
			})
		end
	end
	return vim_item
end

function M._lua_compute_completion_highlights(completion_item, ft)
	local label = completion_item.label
	local kind = completion_item.kind

	if not kind then
		return M.highlight_range(label, ft, 0, #label - 1)
	end
	if kind == M.Kind.Field then
		local text = string.format("%s", label)
		local source = string.format("v.%s", text)
		return M.highlight_range(source, ft, 2, 2 + #text)
	elseif kind == M.Kind.Text then
		local text = string.format("%s", label)
		local source = string.format('"%s"', text)
		return M.highlight_range(source, ft, 1, #source - 2)
	else
		return M.highlight_range(label, ft, 0, #label - 1)
	end
end

function M.typescript_language_server_label_for_completion(item, language)
	local label = item.label
	local detail = item.detail
	local kind = item.kind
	-- Combine label + detail for final display
	local text = detail and (label .. " " .. detail) or label

	if not kind then
		return M.highlight_range(text, language, 0, #text - 1)
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
			M.config.ft.typescript.extra_info_hl,
			range = { #label + 1, #label + 1 + #detail },
		})
	end

	return {
		text = text,
		highlights = highlights,
	}
end

-- see https://github.com/zed-industries/zed/pull/13043
-- Untestd.
function M.vtsls_compute_completion_highlights(completion_item, language)
	local function one_line(s)
		s = s:gsub("    ", "")
		s = s:gsub("\n", " ")
		return s
	end

	local label = completion_item.label
	local len = #label

	local kind = completion_item.kind
	if not kind then
		return M.highlight_range(label, language, 0, #label - 1)
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

	local text = label
	if description then
		text = label .. " " .. one_line(description)
	elseif detail then
		text = label .. " " .. one_line(detail)
	end

	return {
		text = text,
		highlights = {
			{
				highlight_name,
				range = { 0, len },
			},
		},
	}
end

function M.c_compute_completion_highlights(completion_item, ft)
	local vim_item = M._c_compute_completion_highlights(completion_item, ft)
	if vim_item.text ~= nil then
		local document = completion_item.documentation
		if document and document.value and vim.startswith(document.value, "From ") then
			local len = #vim_item.text
			vim_item.text = vim_item.text .. "  " .. document.value
			table.insert(vim_item.highlights, {
				M.config.ft.c.extra_info_hl,
				range = { len + 2, #vim_item.text },
			})
		end
	end
	return vim_item
end

-- Add this in your module, alongside the other compute functions
function M._c_compute_completion_highlights(completion_item, ft)
	-- Remove leading "•" if present
	local raw_label = completion_item.label
	local label = raw_label:gsub("^•", "")
	label = vim.trim(label)

	local kind = completion_item.kind
	local detail = completion_item.detail
	local labelDetails = completion_item.labelDetails

	-- If no kind, just fallback to highlighting the cleaned-up label
	if not kind then
		return M.highlight_range(label, ft, 0, #label - 1)
	end

	-- Fields with detail => "detail label" => highlight in "struct S { ... }"
	if (kind == M.Kind.Field) and detail and #detail > 0 then
		local text = string.format("%s %s", detail, label)
		local source = string.format("struct S { %s }", text)
		-- offset 11 is after "struct S { "
		return M.highlight_range(source, ft, 11, 11 + #text)

		-- Constants or Variables with detail => "detail label", highlight entire text
	elseif (kind == M.Kind.Constant or kind == M.Kind.Variable) and detail and #detail > 0 then
		local text = string.format("%s %s", detail, label)
		return M.highlight_range(text, ft, 0, #text - 1)

		-- Functions or Methods with detail => "detail label", might find '('
	elseif (kind == M.Kind.Function or kind == M.Kind.Method) and detail and #detail > 0 then
		local text = string.format("%s %s%s", detail, label, labelDetails.detail or "")
		return M.highlight_range(text, ft, 0, #text - 1)
		--
	else
		local highlight_name = nil
		if kind == M.Kind.Struct or kind == M.Kind.Interface or kind == M.Kind.Class or kind == M.Kind.Enum then
			highlight_name = "@type"
		elseif kind == M.Kind.EnumMember then
			highlight_name = "@variant"
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

function M.go_compute_completion_highlights(completion_item, ft)
	local label = completion_item.label
	local detail = completion_item.labelDetails and completion_item.labelDetails.detail or completion_item.detail
	local kind = completion_item.kind

	if not kind then
		return M.highlight_range(label, ft, 0, #label - 1)
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
		return M.highlight_range(source, ft, 7, 7 + #text)
		--
	elseif (kind == M.Kind.Constant or kind == M.Kind.Variable) and detail then
		local text = string.format("%s %s", label, detail)
		local var_part = text:sub(name_offset)
		local source = string.format("var %s %s", var_part, detail)
		local item = M.highlight_range(source, ft, 4, 4 + #var_part)
		return M.adjust_range(item, name_offset, text)
		--
	elseif kind == M.Kind.Struct then
		local text = string.format("%s", label)
		local source = string.format("type %s struct {}", text:sub(name_offset))
		local item = M.highlight_range(source, ft, 5, 5 + #text:sub(name_offset))
		return M.adjust_range(item, name_offset, text)
		--
	elseif kind == M.Kind.Interface then
		local text = string.format("%s", label)
		local source = string.format("type %s interface {}", text:sub(name_offset))
		local item = M.highlight_range(source, ft, 5, 5 + #text:sub(name_offset))
		return M.adjust_range(item, name_offset, text)
		--
	elseif kind == M.Kind.Field and detail then
		local text = string.format("%s %s", label, detail)
		local source = string.format("type T struct { %s }", text:sub(name_offset))
		local item = M.highlight_range(source, ft, 16, 16 + #text:sub(name_offset))
		return M.adjust_range(item, name_offset, text)
		--
	elseif (kind == M.Kind.Function or kind == M.Kind.Method) and detail then
		if detail:sub(1, 4) == "func" then
			local signature = detail:sub(5)
			local text = string.format("%s%s", label, signature)
			local source = string.format("func %s {}", text:sub(name_offset))
			local item = M.highlight_range(source, ft, 5, 5 + #text:sub(name_offset))
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

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	-- Ensure M.config.overrides is a table
	if type(M.config.overrides) ~= "table" then
		M.config.overrides = {}
	end
end

return M
