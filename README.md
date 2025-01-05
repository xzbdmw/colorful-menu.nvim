# README

## colorful-menu.nvim
<p align="center">
  <img width="566" alt="image" src="https://github.com/user-attachments/assets/0b129a4a-19c6-4840-b672-2c8b58994724" />
</p>

Out of box, this plugin reconsturct completion_item and applies Treesitter highlight queries to 
produce richly colorized completion items with variable-size highlight ranges, somehow similar
to lspkind.nvim.

**Highly beta**.

run `nvim  -u ~/.config/nvim/repro.lua ~/.config/nvim/repro.lua` as a minimal reproduce template
see [repro.lua](https://github.com/xzbdmw/colorful-menu.nvim/blob/master/repro.lua)

Has built-in supports for **rust-analyzer(rust)**, **gopls(go)**, **typescript-language-server/vtsls**, **lua-ls**, **clangd(C)**, **intelephense(php)**, for any other language, default to directly
apply treesitter highlight to label (feel free to open feature request for more languages).

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
                    auguments_hl = "@comment",
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

                -- If true, try to highlight "not supported" languages.
                fallback = true,
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

## call it in cmp:

```lua
formatting = {
    format = function(entry, vim_item)
        local highlights_info = require("colorful-menu").cmp_highlights(entry)

        -- if highlight_info==nil, which means missing ts parser, let's fallback to use default `vim_item.abbr`.
        -- What this plugin offers is two fields: `vim_item.abbr_hl_group` and `vim_item.abbr`.
        if highlights_info ~= nil then
            vim_item.abbr_hl_group = highlights_info.highlights
            vim_item.abbr = highlights_info.text
        end

        return vim_item
    end,
}
```
## Or call it on blink.cmp

```lua
config = function()
    require("blink.cmp").setup({
        completion = {
            menu = {
                draw = {
                    -- We don't need label_description now because label and label_description are already
                    -- conbined together in label by colorful-menu.nvim.
                    columns = { { "kind_icon" }, { "label", gap = 1 } },
                    components = {
                        label = {
                            width = { fill = true, max = 60 },
                            text = function(ctx)
                                local highlights_info = require("colorful-menu").blink_highlights(ctx)
                                if highlights_info ~= nil then
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
                                return highlights
                            end,
                        },
                    },
                },
            },
        },
    })
end,
```

## Screen

# gopls
## before:
<img width="814" alt="image" src="https://github.com/user-attachments/assets/30614c61-32d9-4d64-8742-58dd443de6ae" />

## after:
<img width="857" alt="image" src="https://github.com/user-attachments/assets/91dead66-87d7-4606-8738-a8b45871e63a" />



<details>
  <summary>Click to see video</summary>
https://github.com/user-attachments/assets/fe72a70b-28ec-460f-9b77-12c95bf74e2e
</details>

# rust-analyzer
## before:
<img width="669" alt="image" src="https://github.com/user-attachments/assets/1c053055-48c7-4b2f-b228-daa77f740eef" />

## after:
<img width="722" alt="image" src="https://github.com/user-attachments/assets/d196db15-163a-496f-a8d4-dc1798b59543" />

<details>
  <summary>Click to see video</summary>
https://github.com/user-attachments/assets/94cb79f0-b93f-4749-99b7-15eae3764f0f
</details>

# clangd
## before：
<img width="605" alt="image" src="https://github.com/user-attachments/assets/be41f824-1ba3-48e8-baad-274efb298a92" />

## after:
<img width="840" alt="image" src="https://github.com/user-attachments/assets/43959f9a-7355-4695-9566-231f7627b6c6" />

<details>
  <summary>Click to see video</summary>
https://github.com/user-attachments/assets/725ea273-b598-4947-b189-f642fa51cf9b
</details>

# lua_ls
## before:
<img width="608" alt="image" src="https://github.com/user-attachments/assets/f8610a41-af17-458e-852d-f86c90e9860d" />

## after:
<img width="688" alt="image" src="https://github.com/user-attachments/assets/08e20d76-d57e-4953-92e2-87de8e862a04" />

<details>
  <summary>Click to see video</summary>
https://github.com/user-attachments/assets/725ea273-b598-4947-b189-f642fa51cf9b)](https://github.com/user-attachments/assets/1e5b1587-4374-49c3-88e7-1e8ed37b3210
</details>

# typescript-language-server
## before:
<img width="383" alt="image" src="https://github.com/user-attachments/assets/a787d034-6b33-4ecb-8512-bfb8e2dfa7b3" />

## after:
<img width="914" alt="image" src="https://github.com/user-attachments/assets/ae62c90f-ef34-4ca5-9dc5-408dbd1313bd" />
<details>
  <summary>Click to see video</summary>
https://github.com/user-attachments/assets/07509e0c-8c7a-4895-8096-73343f85c583
</details>

# intelephense(PHP) Thanks to [@pnx](https://github.com/pnx)
## before:
![image](https://github.com/user-attachments/assets/5c26d88e-d37c-46aa-a8fd-22e44aa16c05)

## after:
![image](https://github.com/user-attachments/assets/4dc7e943-3552-4a75-933d-10bf553d258c)



## Contributing

Feel free to open issues or submit pull requests if you encounter any bugs or have feature requests.  

## License

MIT License.  

## Credit
[Zed](https://github.com/zed-industries/zed) for the initial idea of colorize.

@David van Munster for the [pr](https://github.com/hrsh7th/nvim-cmp/pull/1972) which make this plugin possible.

