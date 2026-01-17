local bufstacker = require("buffer-stacker")
local actions = require("telescope.actions")
local state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local entry_display = require("telescope.pickers.entry_display")
local themes = require("telescope.themes")

local M = {}

-- Formats a line in the buffer picker.
-- This function is assigned to the 'display' key in the table retunred by make_entry.
local function make_display(entry)
	local display = entry.value
	local bufnr = entry.bufnr

	local display_bufname = display.filename
	if display_bufname == "" then
		display_bufname = "[No Name]"
	end

	-- local display_bufpath = vim.fn.fnamemodify(display.filepath, ":.")

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = 20 },
			{ width = 4 },
			{ remaining = true },
		},
	})

	return displayer({
		{ display_bufname, "TelescopeResultsName" },
		{ bufnr, "TelescopeResultsNumber" },
		{ display.filepath, "TelescopeResultsPath" },
	})
end

local function make_entry(bufnr, sort_by_path)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	local filename = vim.fn.fnamemodify(filepath, ":t")

	return {
		value = {
			bufnr = bufnr,
			filename = filename,
			filepath = filepath,
		},
		display = make_display,
		ordinal = sort_by_path and filepath or filename, -- Used for fuzzy search
		bufnr = bufnr,
	}
end

---Telescope picker for the buffers, which is exposed as the user command BufstackerTelescope.
function M.bufpicker(opts)
	opts = opts or {}

	-- I don't know how exactly Telescope's builtins convert an { opts.theme = "ivy" } into the "get_ivy" function.
	-- There's an "apply_cwd_only_aliases(opts)" function local to telescope.builtins.__internal, but there's more
	-- happening besides that. Since I have not figured it out, I manually handle the conversion
	if opts.theme then
		local theme_fn = themes["get_" .. opts.theme]
		if theme_fn then
			-- Merge user's opts with theme defaults
			opts = theme_fn(opts)
		end
	end

	-- Sets up entries to be made for the picker. It does this by:
	-- 1. Retrieves the list of buffers in stack order, with current's previous on top, current on bottom.
	-- 2. Removes current buffer if that option is set.
	-- 3. Sets the entry_maker.
	local custom_finder = finders.new_dynamic({
		fn = function()
			local list = bufstacker.flatten_links()

			if opts.ignore_current_buffer then
				local current = vim.api.nvim_get_current_buf()
				local filtered_list = {}

				for _, buf in ipairs(list) do
					if buf ~= current then
						table.insert(filtered_list, buf)
					end
				end

				return filtered_list
			end

			return list
		end,

		entry_maker = function(bufnr)
			return make_entry(bufnr, opts.sort_by_path)
		end,
	})

	pickers
		.new(opts, {
			prompt_title = "Buffers",

			finder = custom_finder,

			-- Needed for fuzzy search.
			sorter = sorters.get_generic_fuzzy_sorter({
				case_mode = "ignore_case",
			}),

			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = state.get_selected_entry()
					actions.close(prompt_bufnr)
					-- Switch the buffer
					if selection then
						vim.api.nvim_set_current_buf(selection.bufnr)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
