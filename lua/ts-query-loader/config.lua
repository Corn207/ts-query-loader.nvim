local M = {}

---@return Config
M.new = function()
	---@alias FileTypeConfigs {[string]: FiletypeConfig}
	---@alias Handlers {[string]: function}

	---@class Config
	---@field filetypes FileTypeConfigs
	---@field handlers Handlers
	local default = {
		filetypes = {},
		handlers = {},
	}
	return default
end

M.filetype_config = {
	---@return FiletypeConfig
	new = function(self)
		local o = {
			parser = "",
			queries = {},
		}
		setmetatable(o, { __index = self.default })
		return o
	end,

	---@class FiletypeConfig
	---@field parser string
	---@field queries string[]
	---@field callback function?
	default = {
		callback = nil,
	},
}

---@param query string
---@param parser string
local is_query_supported = function(query, parser)
	local ok, err = pcall(vim.treesitter.query.get, parser, query)
	return err and ok
end

---@param filetypes string[]
---@param parser string
---@param config Config
---@param options Options
M.add_filetype_configs = function(config, filetypes, parser, options)
	local enabled_queries = {}
	for query_name, query_option in pairs(options.queries) do
		local is_disabled = query_option.disabled or
			vim.tbl_contains(query_option.disabled_parsers, parser) or
			not (query_option.skip_ts_check or is_query_supported(query_name, parser))
		if not is_disabled then
			table.insert(enabled_queries, query_name)
		end
	end

	for _, filetype in ipairs(filetypes) do
		local filetype_config = M.filetype_config:new()
		filetype_config.parser = parser
		filetype_config.queries = enabled_queries

		config.filetypes[filetype] = filetype_config
	end
end

---Create config with options
---@param options Options
---@return Config
M.create_config = function(options)
	local parser_filepaths = vim.api.nvim_get_runtime_file("parser/*.*", true)

	---@type string[]
	local installed_parsers = {}
	for _, filepath in ipairs(parser_filepaths) do
		local parser = string.match(filepath, ".*[/\\]([^/\\]+)%.%w+$")

		if not (vim.list_contains(installed_parsers, parser)) then
			table.insert(installed_parsers, parser)
		end
	end

	---@type Config
	local config = M.new()
	for name, option in pairs(options.queries) do
		config.handlers[name] = option.handler
	end

	for _, parser in ipairs(installed_parsers) do
		local filetypes = vim.treesitter.language.get_filetypes(parser)

		M.add_filetype_configs(config, filetypes, parser, options)
	end

	return config
end

return M
