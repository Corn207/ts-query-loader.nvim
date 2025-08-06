---@class PluginMain
---@field opts Options? Passed by _setup()_, to be merged with _options_.
---@field options Options? Base options.
---@field config Config? Used for autocmd logics.
local M = {
	opts = nil,
	options = nil,
	config = nil,
}

local autocmd_group_name = "TSQueryLoader"

---User command dictionary
---@alias SubCmds {[string]: function|SubCmds }
---@type SubCmds|function
M.usercmds = {
	options = {
		show = function()
			vim.notify(vim.inspect(M.options), vim.log.levels.INFO)
		end,
		load_default = M.set_options_default,
		load = M.set_options_with_opts,
	},
	config = {
		show = function()
			vim.notify(vim.inspect(M.config), vim.log.levels.INFO)
		end,
		show_buf = function()
			local filetype = vim.bo.filetype
			local parser = M.get_parser_config_by_ft(filetype)
			if (parser == nil) then
				vim.notify("No treesitter parser configured for this buffer.", vim.log.levels.INFO)
				return
			end

			local lines = { "# Current" .. "\n" ..
			"Filetype: " .. vim.bo.filetype .. "\n" ..
			"Parser  : " .. parser.name .. "\n\n" ..
			"# Enabled queries" }
			vim.list_extend(lines, parser.config.queries)
			table.insert(lines, "\n" .. "# Filetypes of parser")
			vim.list_extend(lines, parser.config.filetypes)

			local msg = table.concat(lines, "\n")
			vim.notify(msg, vim.log.levels.INFO)
		end,
		load_default = M.set_config_default,
		load = M.set_all_parser_configs_queries,
	},
	autocmd = {
		create = M.create_autocmds,
		clear = function()
			vim.api.nvim_create_augroup(autocmd_group_name, { clear = true })
		end,
		get_all = function()
			local autocmds = vim.api.nvim_get_autocmds({ group = autocmd_group_name })
			vim.notify(vim.inspect(autocmds), vim.log.levels.INFO)
		end,
	},
}

M.create_usercmds = function()
	vim.api.nvim_create_user_command("TSQueryLoader", function(args)
		local callback = M.usercmds
		for i = 1, #args.fargs, 1 do
			callback = callback[args.fargs[i]]

			if (callback == nil) then
				return
			end
		end

		if (type(callback) == "function") then
			callback()
		end
	end, {
		nargs = "+",
		complete = function(_, cmdline, _)
			local cmds = M.usercmds
			vim.iter(string.gmatch(cmdline, "[%w_]+")):skip(1):each(function(word)
				cmds = M.usercmds[word]

				if (cmds == nil) then
					return
				end
			end)

			if (type(cmds) == "table") then
				local keys = vim.tbl_keys(cmds)
				return keys
			end
		end
	})
end

M.set_options_default = function()
	local lib = require("ts-query-loader.options")
	M.options = lib.new()
end

M.set_options_with_opts = function()
	local lib = require("ts-query-loader.options")
	M.options = lib.merge(M.options, M.opts)
end

---Run ensured installed parser from _options_
---@param parsers string[]? List of parsers
---@return string[]? #List of will be installed parser name
M.ensure_install_parser = function(parsers)
	if (#M.options.ensure_installed == 0) then
		return nil
	end

	local installed
	if (parsers == nil) then
		local lib = require("ts-query-loader.config")
		installed = lib.get_installed_parsers()
	else
		installed = parsers
	end

	local missing = vim.tbl_filter(
		function(parser)
			return not vim.list_contains(installed, parser)
		end,
		M.options.ensure_installed)
	if (#missing == 0) then
		return nil
	end

	local available = require("nvim-treesitter").get_available()
	local correct = {}
	local incorrect = {}

	for _, value in ipairs(missing) do
		if (vim.list_contains(available, value)) then
			table.insert(correct, value)
		else
			table.insert(incorrect, value)
		end
	end

	if (#incorrect > 0) then
		table.insert(incorrect, 1, "# Incorrect 'ensure_installed'")
		local msg = table.concat(incorrect, "\n")
		vim.notify(msg, vim.log.levels.WARN)
	end

	if (#correct > 0) then
		require("nvim-treesitter").install(correct)
		return correct
	end

	return nil
end

M.set_config_default = function()
	local lib = require("ts-query-loader.config")
	M.config = lib.new()

	local installed_parsers = lib.get_installed_parsers()
	local newly_installed_parsers = M.ensure_install_parser(installed_parsers)
	if (newly_installed_parsers ~= nil) then
		vim.list_extend(installed_parsers, newly_installed_parsers)
	end

	for _, parser in ipairs(installed_parsers) do
		local config = lib.parser_config.new()
		config.filetypes = vim.treesitter.language.get_filetypes(parser)
		M.config.parsers[parser] = config
	end

	for name, option in pairs(M.options.queries) do
		M.config.handlers[name] = option.handler
	end

	if (M.options.load_config_mode == "startup") then
		M.set_all_parser_configs_queries()
	end
end

---Set each parser config with its supported queries
M.set_all_parser_configs_queries = function()
	local lib = require("ts-query-loader.config")

	for parser, config in pairs(M.config.parsers) do
		local queries = lib.get_supported_queries(parser, M.options)
		if (queries == nil) then
			M.config.parsers[parser] = nil
		else
			config.queries = queries
		end
	end
end

---Set a parser config with its supported queries
M.set_parser_config_queries = function(parser)
	local lib = require("ts-query-loader.config")

	local queries = lib.get_supported_queries(parser, M.options)
	if (queries == nil) then
		M.config.parsers[parser] = nil
		return false
	else
		M.config.parsers[parser].queries = queries
		return true
	end
end

---Get parser config by filetype
---@param filetype string
---@return {name:string, config:ParserConfig}|?
M.get_parser_config_by_ft = function(filetype)
	for ps_name, ps_config in pairs(M.config.parsers) do
		if (vim.list_contains(ps_config.filetypes, filetype)) then
			return {
				name = ps_name,
				config = ps_config,
			}
		end
	end

	return nil
end

M.create_autocmds = function()
	local group_id = vim.api.nvim_create_augroup(autocmd_group_name, { clear = true })

	local patterns = vim.iter(pairs(M.config.parsers))
		:fold({}, function(acc, _, v)
			vim.list_extend(acc, v.filetypes)
			return acc
		end)
	if (#patterns == 0) then
		return
	end

	if (M.options.load_config_mode == "on_filetype") then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = patterns,
			group = group_id,
			callback = function(args)
				local filetype = args.match

				---@type PluginMain
				local plugin = require("ts-query-loader")

				local parser = plugin.get_parser_config_by_ft(filetype)
				if (parser ~= nil) then
					if (parser.config.queries == nil) then
						local is_populated = plugin.set_parser_config_queries(parser.name)
						if not (is_populated) then
							return
						end
					end

					for _, query in ipairs(parser.config.queries) do
						plugin.config.handlers[query]()
					end
				end
			end
		})
	elseif (M.options.load_config_mode == "startup") then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = patterns,
			group = group_id,
			callback = function(args)
				local filetype = args.match

				---@type PluginMain
				local plugin = require("ts-query-loader")

				local parser = plugin.get_parser_config_by_ft(filetype)
				if (parser ~= nil) then
					for _, query in ipairs(parser.config.queries) do
						plugin.config.handlers[query]()
					end
				end
			end
		})
	end
end

---Plugin's entry point
M.setup = function(opts)
	M.opts = opts
	M.create_usercmds()

	M.set_options_default()
	M.set_options_with_opts()
	M.set_config_default()
	M.create_autocmds()
end

return M
