# 🚚 ts-query-loader

Auto enabling query (module) features of [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## 🤔 Why ?

Since [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
stop developing on `master` branch and rewritten in `main` branch.
It DOES NOT auto-enable query features anymore.

Hence, this plugin provides some of functionalities to:

- Auto-enable all available _queries_ features.
- Configure filtering _query_, _parser_ from auto-enabling.
- Configure changing how _query_ feature being enabled.
- Ensure installing a list of parser.

## 📜 Requirements

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
  `main` branch or its derivation.

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
	"Corn207/ts-query-loader.nvim",
	version = "*", -- Choose latest stable version
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {},
},
```

## ⚙️ Configuration

By default, no configuration is already enough.
Below are several fields for general usage:

```lua
{
	queries = {
		highlights = { -- Name of query
			disabled = false, -- Prevent query from being enable
			disabled_parsers = {}, -- Prevent query with specific parsers
		},
		folds = {
			disabled = false,
			disabled_parsers = {},
		},
		indents = {
			disabled = false,
			disabled_parsers = {},
		},
	},
	ensure_installed = {}, -- Auto-install list of parser names
}
```

> [!NOTE]
> Above table will be recusively merged to internal default option.
> Simply pass the table to `opts = ...` or `require("ts-query-loader").setup(...)`.
>
> The table can be partial, doesn't have to be full like above.

Example of internal default option table:

```lua
{
	queries = {
		highlights = {
			disabled = false,
			disabled_parsers = {},
			skip_ts_check = true, -- Refer to Technicality section
			handler = function() -- Run on found Filetype with matching Query
				vim.treesitter.start()
			end,
		},
		folds = {
			disabled = false,
			disabled_parsers = {},
			skip_ts_check = false,
			handler = function()
				vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
			end,
		},
		indents = {
			disabled = false,
			disabled_parsers = {},
			skip_ts_check = false,
			handler = function()
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		},
	},
	ensure_installed = {},
	load_config_mode = "on_filetype", -- Refer to Technicality section
}
```

## ⚡ User commands

All in a form of subcommand in `TSQueryLoader`:

- `options`:
    - `show`: Show current merged from base and `opts in setup()`.
    - `load_default`: Set default base options.
    - `load`: Set merged base and `opts in setup()`.
- `config`:
    - `show`: Show config table of configured parser, query, filetype.
    - `show_buf`: Show filetype, parser, query for current buffer.
    - `load_default`: Set table to before any query is found supported.
    - `load`: Set table to contain all supported queries for parsers.
- `autocmd`:
    - `create`: Re-create all autocmds based on current config, options.
    - `clear`: Clear all autocmds of this plugin.
    - `get_all`: Show all autocmds set for found filetypes.

## 🛠️ Technicality

**Seem this plugin is over-engineered, convoluted right?**

Well, this solves me of some edge cases involving assign
which _filetype_ will use which _parser_, _query_ and how it runs.
It starts as a small snippet but then it grows as I often mess around treesitter.
Also I don't mine the startup time ~1ms with more tools.

Parsers and queries is provided by [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter).
Each _parser_ has several corresponding _filetype_ and _query_.
You can find them through:

- Installed _parser_ through [vim.api.nvim_get_runtime_file("parser/\*.\*", true)](<https://neovim.io/doc/user/api.html#nvim_get_runtime_file()>)
- Parser's _filetype_ through [vim.treesitter.language.get_filetypes()](<https://neovim.io/doc/user/treesitter.html#vim.treesitter.language.get_filetypes()>)
- Parser's supported query through [vim.treesitter.query.get()](<https://neovim.io/doc/user/treesitter.html#vim.treesitter.query.get()>).
  Same way as `:checkhealth nvim-treesitter`

This plugin mainly use above APIs,
some table filtering,
as recommended on [nvim-treesitter docs](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md#supported-features).

The flow of plugin is somewhat:

- Find all installed _parsers_.
- Auto-install _parsers_ from _ensure_installed_.
- Get all associated _filetypes_.
- Get all supported _queries_.
- Filter with _options_.
- Produce a final _config_ table.
- Every time _FileType_ event is triggered with found _filetype_ above,
  run a _handler_ (just a configured function in _options_) for each matching query.

> [!NOTE]
> Note, the cost of running function to find parser's supported queries is high.
> Around **20ms** for total of 20 parsers with 2 query checks per parser.
>
> Default to skip `highlights` query because so far I found 0 parser
> that doesn't support it.
>
> So I provide `skip_ts_check` field in options to bypass checking.
>
> Furthermore, `load_config_mode` field controls when _query_ is found.
> Greatly decrease startup time, defer to `FileType` event with only opening _filetype_.

## 🎯 Roadmap

- Deeper configuration for each filetype with its own handler, own parser.
