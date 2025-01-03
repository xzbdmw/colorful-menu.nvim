# README

## colorful-menu.nvim

Out of box, this plugin reconsturct completion_item and applies Treesitter highlight queries to 
produce richly colorized completion items with variable-size highlight ranges, somehow similar
to lspkind.nvim.
to lspkind.nvim. It supports per-filetype, per-lspkind configuration overrides.

**Highly beta**.

run `nvim  -u ~/.config/nvim/repro.lua ~/.config/nvim/repro.lua` as a minimal reproduce template
see [repro.lua](https://github.com/xzbdmw/colorful-menu.nvim/blob/master/repro.lua)



Has built-in supports for rust, go, typescript, lua, c, for any other language, default to direcctly
apply treesitter highlight to label.

Currently only supports nvim-cmp, but can be extended easily.

## Installation

With **lazy.nvim**:

```lua
return {
    "xzbdmw/colorful-menu.nvim",
    config = function()
        -- You don't need to set these options.
        require("colorful-menu").setup({
            lua = {
                -- Maybe you want to dim arguments a bit.
                auguments_hl = "@comment",
            },
            typescript = {
                -- Or "vtsls", their information is different, so we
                -- need to know in advance.
                ls = "typescript-language-server",
            },
            rust = {
                -- such as (as Iterator), (use std::io).
                extra_info_hl = "@comment",
            },
            c = {
                -- such as "From <stdio.h>"
                extra_info_hl = "@comment",
            },
            -- If the built-in logic fails to find a suitable highlight group,
            -- this highlight is applied to the label.
            fallback_highlight = "@variable",
            -- If provided, the plugin truncates the final displayed text to
            -- this width (measured in display cells). Any highlights that extend
            -- beyond the truncation point are ignored. Default 60.
            max_width = 60,
        })
    end,
}
```

Now call it in cmp:

```lua
formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
        local completion_item = entry:get_completion_item()
        local highlights_info =
            require("colorful-menu").highlights(completion_item, vim.bo.filetype)

		-- error, such as missing parser, fallback to use raw label.
        if highlights_info == nil then
            vim_item.abbr = completion_item.label
        else
            vim_item.abbr_hl_group = highlights_info.highlights
            vim_item.abbr = highlights_info.text
        end

        local kind = require("lspkind").cmp_format({
            mode = "symbol_text",
        })(entry, vim_item)
        local strings = vim.split(kind.kind, "%s", { trimempty = true })
        vim_item.kind = " " .. (strings[1] or "") .. " "
        vim_item.menu = ""

        return vim_item
    end,
}
```

## Screen

# Go


https://github.com/user-attachments/assets/fe72a70b-28ec-460f-9b77-12c95bf74e2e

# Rust



https://github.com/user-attachments/assets/94cb79f0-b93f-4749-99b7-15eae3764f0f


# C



https://github.com/user-attachments/assets/725ea273-b598-4947-b189-f642fa51cf9b




# Lua


https://github.com/user-attachments/assets/1e5b1587-4374-49c3-88e7-1e8ed37b3210

# Typescript


https://github.com/user-attachments/assets/07509e0c-8c7a-4895-8096-73343f85c583



## Contributing

Feel free to open issues or submit pull requests if you encounter any bugs or have feature requests.  

## License

MIT License.  

## Credit
[Zed](https://github.com/zed-industries/zed) for the initial idea of colorize.

@David van Munster for the [pr](https://github.com/hrsh7th/nvim-cmp/pull/1972) which make this plugin possible.

