# 🚚 ts-query-loader

Auto enabling query (module) features [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

## 🤔 Why ?

Since [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
stop developing on `master` branch and rewritten in `main` branch.
It removes abilities for user to configure
and auto-enable some of its _module_ (now called _query_) features.

Hence, this plugin provides some of functionalities to:

- Auto-enable all available _queries_ features.
- Disable some _queries_ from auto-enabling.
- Blacklist some _parsers_ from using which _query_.
- Customize handler (a function) of which _query_ will be run when opening buffer.

## 📜 Requirements

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
  `main` branch or its derivation.

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
	"Corn207/ts-query-loader.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {},
},
```

## ⚙️ Configuration

Work out-of-the-box, but this is enough for general usage:

```lua
{
	queries = {
		highlights = { -- Name of query
			disabled = false, -- For all parser
			disabled_parsers = {}, -- For each parser name
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
}
```

Any options that passed to `setup()` or through `opts = {...}`
will be merged (`vim.tbl_deep_extend`) with this default options:

```lua
{
	queries = {
		highlights = {
			disabled = false,
			disabled_parsers = {},
			skip_ts_check = true, -- Mention in Technicality
			handler = function(parser) -- Will run in FileType event
				vim.treesitter.start(nil, parser)
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
}
```

## 🛠️ Technicality

Each _parser_ has several corresponding _filetype_ and _query_.
You can find:

- Installed _parser_ through [vim.api.nvim_get_runtime_file("parser/\*.\*", true)](<https://neovim.io/doc/user/api.html#nvim_get_runtime_file()>)
- Parser's _filetype_ through [vim.treesitter.language.get_filetypes()](<https://neovim.io/doc/user/treesitter.html#vim.treesitter.language.get_filetypes()>)
- Parser's supported query through [vim.treesitter.query.get()](<https://neovim.io/doc/user/treesitter.html#vim.treesitter.query.get()>).
  Same way as `:checkhealth nvim-treesitter`

This plugin mainly use above APIs,
some table filtering,
documented _how to enable_ query on [nvim-treesitter docs](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md#supported-features)

Note, the cost of running function to find parser's supported query is high.

> [!NOTE]
> Around **20ms** for total of 20 parsers with 2 query checks per parser.
>
> Default to skip `highlights` query because so far I found 0 parser
> that doesn't support it.

So I provide a field in options `skip_ts_check` to bypass it and consider it is supported.

The flow of plugin is somewhat:

- Find all installed parser.
- Get all associated filetype.
- Get all supported query.
- Filter with options.
- Produce a final _config_ table.
- Every time `FileType` event is triggered with found filetype above,
  run a handler (just a configured function in options) for each query.

## 🎯 Roadmap

- Deeper configuration for each filetype with its own handler, own parser.
- Lazily updating final _config_ table when opening missing filetype.
  To lower running startup time.
