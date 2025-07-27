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
	local default = {
		queries = {
			highlights = {
				disabled = false,
				disabled_parsers = {},
				skip_ts_check = true,
				handler = function(parser)
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

	return default
end

---@param base Options Options base table
---@param opts Options Options table to be merged with
---@return Options
M.merge = function(base, opts)
	if opts ~= nil and not vim.tbl_isempty(opts) then
		return vim.tbl_deep_extend("force", base, opts)
	end

	return base
end

return M
