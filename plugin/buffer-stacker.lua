local bufstacker = require("buffer-stacker")
local telescope = require("buffer-stacker.telescope")

local augroup = vim.api.nvim_create_augroup("Bufstack", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
	group = augroup,
	callback = function()
		-- We pass the current buffer number to visit
		-- visit() handles the vim.schedule wrapping internally
		bufstacker.visit(vim.api.nvim_get_current_buf())
	end,
	desc = "Reorder or newly insert the visited buffer into the bufstack cycle.",
})

vim.api.nvim_create_autocmd("BufDelete", {
	group = augroup,
	callback = function()
		-- <abuf> is the number of the buffer being deleted
		local bufnr = tonumber(vim.fn.expand("<abuf>"))
		if bufnr then
			bufstacker.remove(bufnr)
		end
	end,
	desc = "Remove buffer from the bufstack cycle on delete.",
})

vim.api.nvim_create_user_command("BufstackerNext", function()
	bufstacker.next()
end, { desc = "Go to next buffer in the buffer stack" })

vim.api.nvim_create_user_command("BufstackerPrev", function()
	bufstacker.prev()
end, { desc = "Go to previous buffer in the buffer stack" })

vim.api.nvim_create_user_command("BufstackerLs", function()
	bufstacker.list()
end, { desc = "List buffers in the stack" })

vim.api.nvim_create_user_command("BufstackerTelescope", function()
	telescope.bufpicker()
end, { desc = "Telescope buffer picker in buffer-stacker's MRU order" })
