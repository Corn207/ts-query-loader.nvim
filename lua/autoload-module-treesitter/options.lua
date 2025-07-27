local M = {}

---@class QueryFilter
---@field all boolean Apply to query itself
---@field parsers string[] Parser's names
---@field filetypes string[] Filetype's names

---@class Options
---@field blacklist { [string]: QueryFilter }
---@field whitelist { [string]: QueryFilter }
---@field debugging boolean
M.default = {
	blacklist = {
		["*"] = {
			all = false,
			parsers = {},
			filetypes = {},
		},
		highlights = {
			all = false,
			parsers = {},
			filetypes = {},
		},
		folds = {
			all = false,
			parsers = {},
			filetypes = {},
		},
		indents = {
			all = false,
			parsers = {},
			filetypes = {},
		},
	},

	whitelist = {
		["*"] = {
			all = false,
			parsers = {},
			filetypes = {},
		},
		highlights = {
			all = false,
			parsers = {},
			filetypes = {},
		},
		folds = {
			all = false,
			parsers = {},
			filetypes = {},
		},
		indents = {
			all = false,
			parsers = {},
			filetypes = {},
		},
	},

	debugging = false,
}

return M
