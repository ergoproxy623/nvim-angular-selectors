local M = {}
local cmp = require("cmp")
local u = require("angular-selectors.utils.init")
local a = require("plenary.async")
local j = require("plenary.job")
local ts = vim.treesitter
local selectors = {}
local unique_selectors = {}

local qs = [[
	(export_statement
		(decorator)@decorator)
]]

---@async
M.read_local_files = a.wrap(function(file_extensions, cb)
	local files = {}
	local fa = { "^*.component.ts$" }

	-- WARNING need to check for performance in larger projects
	for _, extension in ipairs(file_extensions) do
		table.insert(fa, "-e")
		table.insert(fa, extension)
	end
	table.insert(fa, "--exclude")
	table.insert(fa, "node_modules")
	j:new({
		command = "fd",
		args = fa,
		on_stdout = function(_, data)
			table.insert(files, data)
		end,
	}):sync()

	if #files == 0 then
		return
	else
		for _, file in ipairs(files) do
			---@type string
			local file_name = u.get_file_name(file, "[^/]+$")
			if file_name then
				
				if  file_name:match("^.+(%..+)$") == '.ts' then
					local fd = io.open(file, "r")
					local data = fd:read("*a")
					fd:close()

					selectors = {}
					unique_selectors = {}

					local parser = ts.get_string_parser(data, "typescript")
					local tree = parser:parse()[1]
					local root = tree:root()
					local query = ts.query.parse("typescript", qs)

					for _, matches, _ in query:iter_matches(root, data, 0, 0, {}) do
						for _, node in pairs(matches) do
							if node:type() == "decorator" then
								local id_name = ts.get_node_text(node, data):gsub("%s+", "")
								id_name =  string.match(id_name, "selector:(.-),")
								if id_name then
								  id_name = id_name:gsub('"','')
								  id_name = id_name:gsub("'",'')
									table.insert(unique_selectors, id_name)
								end
							end
						end
					end


					local unique_selectors_list = u.unique_list(unique_selectors)
					for _, id in ipairs(unique_selectors_list) do
						table.insert(selectors, {
							label = id,
							kind = cmp.lsp.CompletionItemKind.Snippet,
							menu = file_name,
						})
					end

					cb({}, selectors)
				end
			end
		end
	end
end, 2)

return M
