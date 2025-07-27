local M = {}

---@param config Config
M.create_autocmds = function(config)
	local group_id = vim.api.nvim_create_augroup("EnableTSModules", { clear = true })

	for ft_name, _ in pairs(config.filetypes) do
		vim.api.nvim_create_autocmd("FileType", {
			pattern = ft_name,
			group = group_id,
			callback = function(args)
				local filetype = args.match

				---@type Config
				local plugin_config = require("ts-query-loader").config
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
	end
end

M.create_usercmds = function()
	vim.api.nvim_create_user_command("TSQueryLoader", function(args)
		local sub_cmds = {
			showconfig = function()
				local module = require("ts-query-loader")
				vim.notify(vim.inspect(module.config), vim.log.levels.INFO)
			end,

			showopts = function()
				local module = require("ts-query-loader")
				vim.notify(vim.inspect(module.opts), vim.log.levels.INFO)
			end,
		}

		sub_cmds[args.fargs[1]]()
	end, {
		nargs = 1,
	})
end

---Plugin's entry point
M.setup = function(opts)
	local opts_module = require("ts-query-loader.options")
	local default_opts = opts_module.new()
	M.opts = opts_module.merge(default_opts, opts)

	local config_module = require("ts-query-loader.config")
	M.config = config_module.create_config(M.opts)

	M.create_autocmds(M.config)
	M.create_usercmds()
end

return M
