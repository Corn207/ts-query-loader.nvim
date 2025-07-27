-- ---@class Config
-- ---@field highlights string[] Filetype list
-- ---@field folds string[] Filetype list
-- ---@field indents string[] Filetype list
-- local M = {
-- 	highlights = {},
-- 	folds = {},
-- 	indents = {},
-- }
--
-- return M
local M = {}

---@alias FileTypeConfigs {[string]: FiletypeConfig}
---@alias Handlers {[string]: function}

---@class Config
---@field filetypes FileTypeConfigs
---@field handlers Handlers
M.default = {
	filetypes = {},
	handlers = {
		highlights = function(parser)
			vim.treesitter.start(nil, parser)
		end,

		folds = function()
			vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
		end,

		indents = function()
			vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end,
	},
}

M.filetype_config = {
	---Constructor
	---@return FiletypeConfig
	new = function(self, parser, query)
		local o = {
			parser = parser,
			queries = { query }
		}
		setmetatable(o, { __index = self.prototype })
		return o
	end,

	---@class FiletypeConfig
	---@field parser string
	---@field queries string[]
	---@field callback function?
	prototype = {
		parser = "",
		queries = {},
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
---@param query string
---@param parser string
---@param options Options
---@return string[]
local filter_filetypes = function(filetypes, query, parser, options)
	local ret = {}

	local is_whitelisted = options.whitelist[query].all or
		vim.list_contains(options.whitelist[query].parsers, parser)
	if is_whitelisted or
		not (options.blacklist[query].all or
			vim.list_contains(options.blacklist[query].parsers, parser)) then
		ret = vim.tbl_filter(function(filetype)
			is_whitelisted = vim.list_contains(options.whitelist["*"].filetypes, filetype) or
				vim.list_contains(options.whitelist[query].filetypes, filetype)

			return is_whitelisted or
				not (vim.list_contains(options.blacklist["*"].filetypes, filetype) or
					vim.list_contains(options.blacklist[query].filetypes, filetype))
		end, filetypes)

		if not vim.tbl_isempty(ret) and not is_query_supported(query, parser) then
			return {}
		end
	end

	return ret
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

	if M.opts.debugging then
		vim.notify("Total: " .. #installed_parsers .. "\n" ..
			vim.inspect(installed_parsers), vim.log.levels.DEBUG)
	end

	---@type Config
	local config = M.default

	if not options.whitelist["*"].all and
		options.blacklist["*"].all then
		return M.default
	end

	for _, parser in ipairs(installed_parsers) do
		if not vim.list_contains(options.whitelist["*"].parsers, parser) and
			vim.list_contains(options.blacklist["*"].parsers, parser) then
			goto continue
		end

		local parser_config = M.config:new()

		local filetypes = vim.treesitter.language.get_filetypes(parser)

		if M.opts.debugging then
			vim.notify("Total: " .. #filetypes .. "\n" ..
				parser .. "\n" ..
				vim.inspect(filetypes), vim.log.levels.DEBUG)
		end

		---Highlights query
		local highlights = filter_filetypes(filetypes, "highlights", parser, options)
		local ft_configs = vim.tbl_map(function(filetype)
			return M.filetype_config:new(parser)
		end, highlights)


		---Folds query
		local folds = filter_filetypes(filetypes, "folds", parser, options)
		if not vim.tbl_isempty(folds) then
		end

		---Indents query
		local indents = filter_filetypes(filetypes, "indents", parser, options)
		if not vim.tbl_isempty(indents) then
		end

		::continue::
	end

	if M.opts.debugging then
		vim.notify("Total ft: " .. ft_count, vim.log.levels.DEBUG)
	end


	return ft_configs
end









---@param queries string[]
M.run_handlers = function(queries)
	for _, value in ipairs(queries) do
		M.handlers[value]()
	end
end

return M
