---@class ConfigLib
local M = {}

---@return Config
M.new = function()
	---@alias ParserConfigs {[string]: ParserConfig}
	---@alias Handlers {[string]: function}

	---@class Config
	---@field parsers ParserConfigs
	---@field handlers Handlers
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

---Get FiletypeConfig or ParserConfig based on filetype
---@param filetype string
---@param config Config
---@return {name:string, config:ParserConfig}|?
M.get_parser_config_by_ft = function(filetype, config)
	for ps_name, ps_config in pairs(config.parsers) do
		if (vim.list_contains(ps_config.filetypes, filetype)) then
			return {
				name = ps_name,
				config = ps_config,
			}
		end
	end

	return nil
end

---Populate queries for specific parser name in config
---@param parser string
---@param config Config
---@param options Options
---@return boolean
M.populate_queries_by_parser_name = function(parser, config, options)
	local queries = M.get_supported_queries(parser, options)
	if (queries == nil) then
		config.parsers[parser] = nil
		return false
	end

	config.parsers[parser].queries = queries
	return true
end

---Populate queries for all parser configs
---@param config Config
---@param options Options
M.populate_queries = function(config, options)
	for ps_name, ps_config in pairs(config.parsers) do
		local queries = M.get_supported_queries(ps_name, options)
		if queries == nil then
			config.parsers[ps_name] = nil
		else
			ps_config.queries = queries
		end
	end
end

---Create config with options
---@param options Options
---@return Config
M.create_config = function(options)
	local config = M.new()

	---Populate parser configs without queries
	for _, parser in pairs(M.get_installed_parsers()) do
		local parser_config = M.parser_config.new()
		parser_config.filetypes = vim.treesitter.language.get_filetypes(parser)
		config.parsers[parser] = parser_config
	end

	---Populate query handlers
	for name, option in pairs(options.queries) do
		config.handlers[name] = option.handler
	end

	if (options.load_config_mode == "startup") then
		---Populate queries for parser configs
	end

	return config
end

return M
