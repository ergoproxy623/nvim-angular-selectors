local Source = {}
local config = require("cmp.config")
local a = require("plenary.async")
local l = require("angular-selectors.local")
local ts = vim.treesitter
local tsu = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")

local scan = require("plenary.scandir")
local rootDir = scan.scan_dir(".", {
	hidden = true,
	add_dirs = true,
	depth = 1,
	respect_gitignore = true,
	search_pattern = function(entry)
		local subEntry = entry:sub(3) -- remove ./
		return subEntry:match(".git$") or subEntry:match("package.json") -- if project contains .git folder or package.json its gonna work
	end,
})

local function mrgtbls(t1, t2)
	for _, v in ipairs(t2) do
		table.insert(t1, v)
	end
	return t1
end

function Source:setup()
	require("cmp").register_source(self.source_name, Source)
end

function Source:new()
	self.source_name = "angular-selectors"
	self.isRemote = "^https?://"
	self.items = {}
	self.ids = {}

	-- reading user config
	self.user_config = config.get_source_config(self.source_name) or {}
	self.option = self.user_config.option or {}
	self.file_extensions = self.option.file_extensions or {}
	self.style_sheets = self.option.style_sheets or {}
	self.enable_on = self.option.enable_on or {}

	-- Get the current working directory
	local current_directory = vim.fn.getcwd()

	-- Check if the current directory contains a .git folder
	local git_folder_exists = vim.fn.isdirectory(current_directory .. "/.git")

	-- if git_folder_exists == 1 then
	if vim.tbl_count(rootDir) ~= 0 then
		self.style_sheets = mrgtbls(self.style_sheets, {}) -- merge lings together

		-- read all local files on start
		a.run(function()
			l.read_local_files(self.file_extensions, function(classes, ids)
				for _, id in ipairs(ids) do
					table.insert(self.ids, id)
				end
			end)
		end)
	end

	return self
end

function Source:complete(_, callback)
	print("complete")
	if vim.tbl_count(rootDir) ~= 0 then
		self.items = {}
		self.ids = {}

		-- read all local files on start
		a.run(function()
			l.read_local_files(self.file_extensions, function(classes, ids)
				for _, id in ipairs(ids) do
					table.insert(self.ids, id)
				end
			end)
		end)

        if self.current_selector == "element" then
				callback({ items = self.ids, isComplete = false })
		end
	end
end

function Source:is_available()
	if not next(self.user_config) then
		return false
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local parser = parsers.get_parser(bufnr)
    if parser then
      local lang = parser:lang()

      if lang == "html" or lang == "svelte" or lang == "vue" or lang == "angular" then
        self.current_selector = "element"
		return true	
	  end
    end 
	
end

return Source:new()
