---@class OptionLib
local M = {}

---@return Options
M.new = function()
	---@class QueryOption
	---@field disabled boolean
	---@field disabled_parsers string[]
	---@field skip_ts_check boolean
	---@field handler function

	---@class Options
	---@field queries { [string]: QueryOption }
	---@field ensure_installed string[]
	---@field load_config_mode "on_filetype"|"startup"
	---@field debugging boolean
	local default = {
		queries = {
			highlights = {
				disabled = false,
				disabled_parsers = {},
				skip_ts_check = true,
				handler = function()
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
		load_config_mode = "on_filetype",
		debugging = false,
	}

	return default
end

return M
