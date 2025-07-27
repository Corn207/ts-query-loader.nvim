local M = {
	opts = require("autoload-module-treesitter.options").default,
	config = require("autoload-module-treesitter.config").default,
}

-- ---@param query string
-- ---@param parser string
-- local is_query_supported = function(query, parser)
-- 	local ok, err = pcall(vim.treesitter.query.get, parser, query)
-- 	return err and ok
-- end
--
-- ---@param filetypes string[]
-- ---@param query string
-- ---@param parser string
-- ---@param options Options
-- local filter_filetypes = function(filetypes, query, parser, options)
-- 	local ret = {}
--
-- 	if (options.whitelist[query].all or
-- 			vim.list_contains(options.whitelist[query].parsers, parser)) or
-- 		not (options.blacklist.folds.all or
-- 			vim.list_contains(options.blacklist[query].parsers, parser)) and
-- 		is_query_supported(query, parser) then
-- 		ret = vim.tbl_filter(function(filetype)
-- 			return (vim.list_contains(options.whitelist.all.filetypes, filetype) or
-- 					vim.list_contains(options.whitelist[query].filetypes, filetype)) or
-- 				not (vim.list_contains(options.blacklist.all.filetypes, filetype) or
-- 					vim.list_contains(options.blacklist[query].filetypes, filetype))
-- 		end, filetypes)
-- 	end
--
-- 	return ret
-- end
--
-- ---@param options Options
-- ---@return Config
-- M.get_config = function(options)
-- 	local parser_filepaths = vim.api.nvim_get_runtime_file("parser/*.*", true)
--
-- 	---@type string[]
-- 	local installed_parsers = {}
-- 	for _, filepath in ipairs(parser_filepaths) do
-- 		local parser = string.match(filepath, ".*[/\\]([^/\\]+)%.%w+$")
--
-- 		if not (vim.list_contains(installed_parsers, parser)) then
-- 			table.insert(installed_parsers, parser)
-- 		end
-- 	end
--
-- 	if M.opts.debugging then
-- 		vim.notify("Total: " .. #installed_parsers .. "\n" ..
-- 			vim.inspect(installed_parsers), vim.log.levels.DEBUG)
-- 	end
-- 	local ft_count = 0
--
-- 	local config = require("autoload-module-treesitter.config")
--
-- 	if not options.whitelist.all.all and
-- 		options.blacklist.all.all then
-- 		return config
-- 	end
--
-- 	for _, parser in ipairs(installed_parsers) do
-- 		local filetypes = vim.treesitter.language.get_filetypes(parser)
--
-- 		if M.opts.debugging then
-- 			vim.notify("Total: " .. #filetypes .. "\n" ..
-- 				parser .. "\n" ..
-- 				vim.inspect(filetypes), vim.log.levels.DEBUG)
-- 			ft_count = ft_count + #filetypes
-- 		end
--
-- 		if not vim.list_contains(options.whitelist.all.parsers, parser) and
-- 			vim.list_contains(options.blacklist.all.parsers, parser) then
-- 			goto continue
-- 		end
--
-- 		---Highlights query
-- 		vim.list_extend(config.highlights, filetypes)
--
-- 		---Folds query
-- 		local folds = filter_filetypes(filetypes, "folds", parser, options)
-- 		if not vim.tbl_isempty(folds) then
-- 			vim.list_extend(config.folds, folds)
-- 		end
--
-- 		---Indents query
-- 		local indents = filter_filetypes(filetypes, "indents", parser, options)
-- 		if not vim.tbl_isempty(indents) then
-- 			vim.list_extend(config.indents, indents)
-- 		end
--
-- 		::continue::
-- 	end
--
-- 	if M.opts.debugging then
-- 		vim.notify("Total ft: " .. ft_count, vim.log.levels.DEBUG)
-- 	end
--
-- 	return config
-- end
--
-- -- ---Create autocmds
-- -- ---@param module_config Config
-- -- M.create_autocmds = function(module_config)
-- -- 	local group_id = vim.api.nvim_create_augroup("EnableTSModules", { clear = true })
-- --
-- -- 	if not (vim.tbl_isempty(module_config.highlights)) then
-- -- 		vim.api.nvim_create_autocmd("FileType", {
-- -- 			pattern = module_config.highlights,
-- -- 			group = group_id,
-- -- 			callback = function()
-- -- 				vim.treesitter.start()
-- -- 			end
-- -- 		})
-- -- 	end
-- --
-- -- 	if not (vim.tbl_isempty(module_config.folds)) then
-- -- 		vim.api.nvim_create_autocmd("FileType", {
-- -- 			pattern = module_config.folds,
-- -- 			group = group_id,
-- -- 			callback = function()
-- -- 				vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- -- 			end
-- -- 		})
-- -- 	end
-- --
-- -- 	if not (vim.tbl_isempty(module_config.indents)) then
-- -- 		vim.api.nvim_create_autocmd("FileType", {
-- -- 			pattern = module_config.indents,
-- -- 			group = group_id,
-- -- 			callback = function()
-- -- 				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
-- -- 			end
-- -- 		})
-- -- 	end
-- --
-- -- 	if M.opts.debugging then
-- -- 		vim.notify(vim.inspect(vim.api.nvim_get_autocmds({ group = group_id })), vim.log.levels.DEBUG)
-- -- 	end
-- -- end
--
-- M.notify_debug = function(obj)
-- 	vim.notify(vim.inspect(obj), vim.log.levels.INFO)
-- end
--
-- ---@alias FiletypeQueries { [string]: string[] }
--

---Create autocmds
---@param config Config
M.create_autocmds = function(config)
	local group_id = vim.api.nvim_create_augroup("EnableTSModules", { clear = true })

	for ft_name, ft_config_for in pairs(config.filetypes) do
		local autocmd_id = vim.api.nvim_create_autocmd("FileType", {
			pattern = ft_name,
			group = group_id,
			callback = function(args)
				local filetype = args.match

				---@type Config
				local plugin_config = require("autoload-module-treesitter").config
				local ft_config = plugin_config.filetypes[filetype]
				if ft_config.callback ~= nil then
					ft_config.callback()
				else
					for _, query in ipairs(ft_config.queries) do
						plugin_config.handlers[query](ft_config.parser)
					end
				end
			end
		})

		if M.opts.debugging then
			vim.notify("Autocmd " .. autocmd_id .. "\n" ..
				vim.inspect(ft_config_for), vim.log.levels.DEBUG)
		end
	end
end

---Plugin's entry point
M.setup = function(opts)
	if not vim.tbl_isempty(opts) then
		M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	end

	local config_module = require("autoload-module-treesitter.config")
	M.config = config_module.create_config(M.opts)

	if M.opts.debugging then
		vim.notify(vim.inspect(M.config), vim.log.levels.DEBUG)
	end

	M.create_autocmds(M.config)
end

return M
