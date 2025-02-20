# README

## colorful-menu.nvim
<p align="center">
<img width="749" alt="image" src="https://github.com/user-attachments/assets/9fcb9725-5385-4ce3-afe5-74c0e57d9893" />
</p>

Out of box, this plugin reconstructs completion item and applies treesitter highlight queries to
produce richly colorized completion items with variable-size highlight ranges.

Has built-in support for
- [**rust-analyzer (Rust)**](#rust-analyzer)
- [**gopls (Go)**](#gopls)
- [**typescript-language-server/vtsls (TypeScript)**](#typescript-language-server)
- [**lua-ls (Lua)**](#lua_ls)
- [**clangd (C/CPP)**](#clangd)
- [**intelephense (PHP)**](#intelephense)
- [**zls (Zig)**](#zls)
- [**roslyn (C#)**](#roslyn)
- [**basedpyright/pylance/pyright (Python)**](#basedpyright)
- [**dartls (Dart)**](#dartls)

For other languages, it defaults to use highlight group of item's kind.
(feel free to open feature request for more languages)

Currently supports **nvim-cmp** and **blink.cmp**.

## Installation

With **lazy.nvim**:

```lua
return {
    "xzbdmw/colorful-menu.nvim",
    config = function()
        -- You don't need to set these options.
        require("colorful-menu").setup({
            ls = {
                lua_ls = {
                    -- Maybe you want to dim arguments a bit.
                    arguments_hl = "@comment",
                },
                gopls = {
                    -- By default, we render variable/function's type in the right most side,
                    -- to make them not to crowd together with the original label.

                    -- when true:
                    -- foo             *Foo
                    -- ast         "go/ast"

                    -- when false:
                    -- foo *Foo
                    -- ast "go/ast"
                    align_type_to_right = true,
                    -- When true, label for field and variable will format like "foo: Foo"
                    -- instead of go's original syntax "foo Foo". If align_type_to_right is
                    -- true, this option has no effect.
                    add_colon_before_type = false,
                    -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
                    preserve_type_when_truncate = true,
                },
                -- for lsp_config or typescript-tools
                ts_ls = {
                    -- false means do not include any extra info,
                    -- see https://github.com/xzbdmw/colorful-menu.nvim/issues/42
                    extra_info_hl = "@comment",
                },
                vtsls = {
                    -- false means do not include any extra info,
                    -- see https://github.com/xzbdmw/colorful-menu.nvim/issues/42
                    extra_info_hl = "@comment",
                },
                ["rust-analyzer"] = {
                    -- Such as (as Iterator), (use std::io).
                    extra_info_hl = "@comment",
                    -- Similar to the same setting of gopls.
                    align_type_to_right = true,
                    -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
                    preserve_type_when_truncate = true,
                },
                clangd = {
                    -- Such as "From <stdio.h>".
                    extra_info_hl = "@comment",
                    -- Similar to the same setting of gopls.
                    align_type_to_right = true,
                    -- the hl group of leading dot of "•std::filesystem::permissions(..)"
                    import_dot_hl = "@comment",
                    -- See https://github.com/xzbdmw/colorful-menu.nvim/pull/36
                    preserve_type_when_truncate = true,
                },
                zls = {
                    -- Similar to the same setting of gopls.
                    align_type_to_right = true,
                },
                roslyn = {
                    extra_info_hl = "@comment",
                },
                dartls = {
                    extra_info_hl = "@comment",
                },
                -- The same applies to pyright/pylance
                basedpyright = {
                    -- It is usually import path such as "os"
                    extra_info_hl = "@comment",
                },

                -- If true, try to highlight "not supported" languages.
                fallback = true,
            },
            -- If the built-in logic fails to find a suitable highlight group,
            -- this highlight is applied to the label.
            fallback_highlight = "@variable",
            -- If provided, the plugin truncates the final displayed text to
            -- this width (measured in display cells). Any highlights that extend
            -- beyond the truncation point are ignored. When set to a float
            -- between 0 and 1, it'll be treated as percentage of the width of
            -- the window: math.floor(max_width * vim.api.nvim_win_get_width(0))
            -- Default 60.
            max_width = 60,
        })
    end,
}
```

## use it in nvim-cmp:

```lua
require("cmp").setup({
    formatting = {
        format = function(entry, vim_item)
            local highlights_info = require("colorful-menu").cmp_highlights(entry)

            -- highlight_info is nil means we are missing the ts parser, it's
            -- better to fallback to use default `vim_item.abbr`. What this plugin
            -- offers is two fields: `vim_item.abbr_hl_group` and `vim_item.abbr`.
            if highlights_info ~= nil then
                vim_item.abbr_hl_group = highlights_info.highlights
                vim_item.abbr = highlights_info.text
            end

            return vim_item
        end,
    },
})
```
## use it in blink.cmp:

```lua
config = function()
    require("blink.cmp").setup({
        completion = {
            menu = {
                draw = {
                    -- We don't need label_description now because label and label_description are already
                    -- combined together in label by colorful-menu.nvim.
                    columns = { { "kind_icon" }, { "label", gap = 1 } },
                    components = {
                        label = {
                            text = function(ctx)
                                return require("colorful-menu").blink_components_text(ctx)
                            end,
                            highlight = function(ctx)
                                return require("colorful-menu").blink_components_highlight(ctx)
                            end,
                        },
                    },
                },
            },
        },
    })
end
```
If you want to customize a bit more in those options, here is a more granular control approach:

<details>
<summary>Click to see</summary>

```lua
config = function()
    require("blink.cmp").setup({
        completion = {
            menu = {
                draw = {
                    -- We don't need label_description now because label and label_description are already
                    -- combined together in label by colorful-menu.nvim.
                    columns = { { "kind_icon" }, { "label", gap = 1 } },
                    components = {
                        label = {
                            width = { fill = true, max = 60 },
                            text = function(ctx)
                                local highlights_info = require("colorful-menu").blink_highlights(ctx)
                                if highlights_info ~= nil then
                                    -- Or you want to add more item to label
                                    return highlights_info.label
                                else
                                    return ctx.label
                                end
                            end,
                            highlight = function(ctx)
                                local highlights = {}
                                local highlights_info = require("colorful-menu").blink_highlights(ctx)
                                if highlights_info ~= nil then
                                    highlights = highlights_info.highlights
                                end
                                for _, idx in ipairs(ctx.label_matched_indices) do
                                    table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
                                end
                                -- Do something else
                                return highlights
                            end,
                        },
                    },
                },
            },
        },
    })
end
```
</details>

## Custom configuration with `lspkind.nvim`

You can configure your completion engine (below is for `nvim-cmp` with both `colorful-menu.nvim` and `lspkind.nvim` to get completion menu like those in Screen section.
<details>
<summary>Click to see</summary>

```lua
formatting = {
  fields = { "kind", "abbr", "menu" },

  format = function(entry, vim_item)
    local kind = require("lspkind").cmp_format({
        mode = "symbol_text",
    })(entry, vim.deepcopy(vim_item))
    local highlights_info = require("colorful-menu").cmp_highlights(entry)

    -- highlight_info is nil means we are missing the ts parser, it's
    -- better to fallback to use default `vim_item.abbr`. What this plugin
    -- offers is two fields: `vim_item.abbr_hl_group` and `vim_item.abbr`.
    if highlights_info ~= nil then
        vim_item.abbr_hl_group = highlights_info.highlights
        vim_item.abbr = highlights_info.text
    end
    local strings = vim.split(kind.kind, "%s", { trimempty = true })
    vim_item.kind = " " .. (strings[1] or "") .. " "
    vim_item.menu = ""

    return vim_item
  end,
}
```
</details>

## Screen

> **💡 Note:** You may want to set `CmpItemAbbrMatch` or `BlinkCmpLabelMatch` to only have **bold style** (without `fg`) to achieve a similar effect as the images below.

# gopls
## before:
<img width="633" alt="image" src="https://github.com/user-attachments/assets/94ed9b8d-1c81-41b3-b406-2e2340909483" />

## after:
<img width="908" alt="image" src="https://github.com/user-attachments/assets/12f98543-8794-4128-9e6c-f3b66606ff75" />

# rust-analyzer
## before:
<img width="669" alt="image" src="https://github.com/user-attachments/assets/1c053055-48c7-4b2f-b228-daa77f740eef" />

## after:
<img width="732" alt="image" src="https://github.com/user-attachments/assets/d98744e2-a6e3-4eef-9241-f76199816a8d" />

# clangd
## before：
<img width="605" alt="image" src="https://github.com/user-attachments/assets/be41f824-1ba3-48e8-baad-274efb298a92" />

## after:
<img width="713" alt="image" src="https://github.com/user-attachments/assets/0f68176f-d311-4e86-b848-592106a649ca" />

# lua_ls
## before:
<img width="608" alt="image" src="https://github.com/user-attachments/assets/f8610a41-af17-458e-852d-f86c90e9860d" />

## after:
<img width="688" alt="image" src="https://github.com/user-attachments/assets/08e20d76-d57e-4953-92e2-87de8e862a04" />

# typescript-language-server
## before:
<img width="383" alt="image" src="https://github.com/user-attachments/assets/a787d034-6b33-4ecb-8512-bfb8e2dfa7b3" />

## after:
<img width="914" alt="image" src="https://github.com/user-attachments/assets/ae62c90f-ef34-4ca5-9dc5-408dbd1313bd" />

# intelephense
Thanks to [@pnx](https://github.com/pnx)
## before:
![image](https://github.com/user-attachments/assets/5c26d88e-d37c-46aa-a8fd-22e44aa16c05)

## after:
![image](https://github.com/user-attachments/assets/4dc7e943-3552-4a75-933d-10bf553d258c)

# zls
## before:
<img width="516" alt="image" src="https://github.com/user-attachments/assets/83dbc705-60a7-4406-b1da-7419ab43e23d" />

## after:
<img width="741" alt="image" src="https://github.com/user-attachments/assets/26eaa3a3-8512-4996-9558-051150c72f3a" />

# roslyn
Thanks to [@seblj](https://github.com/seblj)
## before:
![image](https://github.com/user-attachments/assets/1b309b78-e75d-404d-ab23-e19f7b8f0e4e)

## after:
![image](https://github.com/user-attachments/assets/60bdf5ad-86e9-410b-a390-e1e8e08d1377)

# basedpyright
## before:
<img width="756" alt="image" src="https://github.com/user-attachments/assets/9e422231-93ca-4746-b438-ba223d16d8db" />

## after:
<img width="825" alt="image" src="https://github.com/user-attachments/assets/4e19119d-a064-41da-b987-0a8ef9d0faad" />

# dartls
## before:
<img width="566" alt="image" src="https://github.com/user-attachments/assets/53f81c16-6b9f-4449-925f-6b2d92bb8a78" />

## after:
<img width="915" alt="image" src="https://github.com/user-attachments/assets/e1c65794-44c5-4e70-b7eb-a639dac6a56c" />



## Contributing

Feel free to open issues or submit pull requests if you encounter any bugs or have feature requests.

## License

MIT License.

## Credit
[Zed](https://github.com/zed-industries/zed) for the initial idea of colorize.

@David van Munster for the [pr](https://github.com/hrsh7th/nvim-cmp/pull/1972) which make this plugin possible.

JetBrains for its right-aligned type layout
