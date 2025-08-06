---@class ConfigLib
local M = {}

---@return Config
M.new = function()
	---@alias ParserConfigs {[string]: ParserConfig}
	---@alias Handlers {[string]: function}

	---@class Config
	---@field parsers ParserConfigs
	---@field handlers Handlers Dictionary with key as _query name_, value as _function_.
	local default = {
		parsers = {},
		handlers = {},
	}
	return default
end

M.parser_config = {
	---@class ParserConfig
	---@field filetypes string[]
	---@field queries string[]?
	---@return ParserConfig
	new = function()
		local default = {
			filetypes = {},
			queries = nil,
		}
		return default
	end,
}

---Get installed parsers from rtp
---@return string[]
M.get_installed_parsers = function()
	local parser_filepaths = vim.api.nvim_get_runtime_file("parser/*.*", true)

	local installed_parsers = {}
	for _, filepath in ipairs(parser_filepaths) do
		local parser = string.match(filepath, ".*[/\\]([^/\\]+)%.%w+$")

		if not (vim.list_contains(installed_parsers, parser)) then
			table.insert(installed_parsers, parser)
		end
	end

	return installed_parsers
end

---Check if query is supported in parser
---@param query string
---@param parser string
M.is_query_supported = function(query, parser)
	local ok, err = pcall(vim.treesitter.query.get, parser, query)
	return err and ok
end

---Get supported queries from specific parser name and filtered by options
---@param parser string
---@param options Options
---@return string[]?
M.get_supported_queries = function(parser, options)
	local supported_queries = {}

	for query_name, query_option in pairs(options.queries) do
		local is_disabled = query_option.disabled or
			vim.list_contains(query_option.disabled_parsers, parser) or
			not (query_option.skip_ts_check or M.is_query_supported(query_name, parser))
		if not is_disabled then
			table.insert(supported_queries, query_name)
		end
	end

	if (#supported_queries == 0) then
		return nil
	end

	return supported_queries
end

return M
