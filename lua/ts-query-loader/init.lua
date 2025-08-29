---@class PluginMain
---@field opts Options? Passed by _setup()_, to be merged with _options_.
---@field config Config? Used for autocmd logics.
local M = {
	opts = nil,
	config = nil,
}

local autocmd_group_name = "TSQueryLoader"

---User command dictionary
---@alias SubCmds {[string]: function|SubCmds }
---@type SubCmds|function
M.usercmds = {
	options = {
		show = function()
			vim.notify(vim.inspect(M.opts), vim.log.levels.INFO)
		end,
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
		create = M.create_config,
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
		end,
	})
end

---Merge *opts* to current options.
---@param opts Options
M.merge_opts = function(opts)
	if (type(opts) == "table" and not vim.tbl_isempty(opts)) then
		M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	end
end

---Install parsers
---@param parsers string[]? If nil, install parsers in *opts.ensure_installed*.
M.install_parsers = function(parsers)
	if (parsers == nil) then
		if (#M.opts.ensure_installed == 0) then
			return
		end
	elseif (#parsers == 0) then
		return
	end

	if (vim.fn.executable("tree-sitter") == 0) then
		vim.notify("tree-sitter CLI is not installed.", vim.log.levels.WARN)
		return
	end

	if (parsers == nil) then
		require("nvim-treesitter").install(M.opts.ensure_installed)
	else
		require("nvim-treesitter").install(parsers)
	end
end

---Create config from installed parsers and options
M.create_config = function()
	local lib = require("ts-query-loader.config")
	M.config = lib.new()

	local installed_parsers = lib.get_installed_parsers()

	for _, parser in ipairs(installed_parsers) do
		local ps_config = lib.parser_config.new()
		ps_config.filetypes = vim.treesitter.language.get_filetypes(parser)
		M.config.parsers[parser] = ps_config
	end

	for name, option in pairs(M.opts.queries) do
		M.config.handlers[name] = option.handler
	end

	if (M.opts.load_config_mode == "startup") then
		M.set_all_parser_configs_queries()
	end
end

---Set each parser config with its supported queries
M.set_all_parser_configs_queries = function()
	local lib = require("ts-query-loader.config")

	for parser, config in pairs(M.config.parsers) do
		local queries = lib.get_supported_queries(parser, M.opts)
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

	local queries = lib.get_supported_queries(parser, M.opts)
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

	if (M.opts.load_config_mode == "on_filetype") then
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
			end,
		})
	elseif (M.opts.load_config_mode == "startup") then
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
			end,
		})
	end
end

---Plugin's entry point
M.setup = function(opts)
	M.opts = require("ts-query-loader.options").new()
	M.merge_opts(opts)

	vim.schedule_wrap(M.install_parsers)()
	M.create_config()
	M.create_autocmds()

	M.create_usercmds()
end

return M
