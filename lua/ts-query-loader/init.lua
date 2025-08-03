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
		load_default = function()
			local lib = require("ts-query-loader.options")
			M.options = lib.new()
		end,
		load = function()
			local lib = require("ts-query-loader.options")
			M.options = lib.merge(M.options, M.opts)
		end,
	},
	config = {
		show = function()
			vim.notify(vim.inspect(M.config), vim.log.levels.INFO)
		end,
		show_buf = function()
			local lib = require("ts-query-loader.config")
			local filetype = vim.bo.filetype
			local parser = lib.get_parser_config_by_ft(filetype, M.config)
			if (parser == nil) then
				vim.notify("No treesitter parser configured for this buffer.", vim.log.levels.INFO)
				return
			end

			local queries = vim.iter(ipairs(parser.config.queries))
				:fold("", function(acc, _, item)
					acc = acc .. "\n" .. item
					return acc
				end)
			local parser_ft = vim.iter(ipairs(parser.config.filetypes))
				:fold("", function(acc, _, item)
					acc = acc .. "\n" .. item
					return acc
				end)
			local msg = "Filetype: " .. vim.bo.filetype .. "\n" ..
				"Parser: " .. parser.name .. "\n\n" ..
				"# Queries" ..
				queries .. "\n\n" ..
				"# Parser's filetype" ..
				parser_ft

			vim.notify(msg, vim.log.levels.INFO)
		end,
		load_default = function()
			local lib = require("ts-query-loader.config")
			M.config = lib.create_config(M.options)
		end,
		load = function()
			local lib = require("ts-query-loader.config")
			lib.populate_queries(M.config, M.options)
		end,
	},
	autocmd = {
		create = function()
			M.create_autocmds(M.config, M.options)
		end,
		clear = function()
			vim.api.nvim_create_augroup(autocmd_group_name, { clear = true })
		end,
		get_all = function()
			local autocmds = vim.api.nvim_get_autocmds({ group = autocmd_group_name })
			vim.notify(vim.inspect(autocmds), vim.log.levels.INFO)
		end,
	},
}

---@param config Config
M.create_autocmds = function(config, options)
	local group_id = vim.api.nvim_create_augroup(autocmd_group_name, { clear = true })

	local patterns = vim.iter(pairs(config.parsers))
		:fold({}, function(acc, _, v)
			vim.list_extend(acc, v.filetypes)
			return acc
		end)
	if (#patterns == 0) then
		return
	end

	if (options.load_config_mode == "on_filetype") then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = patterns,
			group = group_id,
			callback = function(args)
				local filetype = args.match

				---@type PluginMain
				local plugin = require("ts-query-loader")
				local config_lib = require("ts-query-loader.config")

				local parser = config_lib.get_parser_config_by_ft(filetype, plugin.config)
				if (parser ~= nil) then
					if (parser.config.queries == nil) then
						local is_populated = config_lib.populate_queries_by_parser_name(parser.name, plugin.config,
							plugin.options)
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
	elseif (options.load_config_mode == "startup") then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = patterns,
			group = group_id,
			callback = function(args)
				local filetype = args.match

				---@type PluginMain
				local plugin = require("ts-query-loader")
				local config_lib = require("ts-query-loader.config")

				local parser = config_lib.get_parser_config_by_ft(filetype, plugin.config)
				if (parser ~= nil) then
					for _, query in ipairs(parser.config.queries) do
						plugin.config.handlers[query]()
					end
				end
			end
		})
	end
end

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

---Plugin's entry point
M.setup = function(opts)
	M.opts = opts
	M.create_usercmds()

	M.usercmds["options"]["load_default"]()
	M.usercmds["options"]["load"]()

	M.usercmds["config"]["load_default"]()
	M.usercmds["autocmd"]["create"]()
end

return M
