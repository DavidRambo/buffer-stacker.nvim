local M = {}

-- Bufstack represents the open buffers as a circular linked list, which is implemented as a hash map.
local links = {}
-- The currently open buffer is tracked by a separate variable.
local current_bufnr = nil

-- Flat to ignore autocmd when navigating with the next and previous commands.
local navigating = false

local function is_valid_buf(bufnr)
	return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
end

---Removes a node from the cycle without removing it from the links table.
---
---@param bufnr number - buffer number of a buffer that is assumed to exist
local function splice(bufnr)
	local node = links[bufnr]
	local prev_node = links[node.prev]
	local next_node = links[node.next]

	prev_node.next = node.next
	next_node.prev = node.prev
end

---Place target buffer's number into the linked list after the reference buffer number.
---... <-> ref_prev <-> ref <-> ref_next <-> ...
---becomes
---... <-> ref_prev <-> ref <-> target <-> ref_next <-> ...
---
---@param target number - number of the buffer being inserted into the linked list
---@param reference number - number of the buffer behind which the target is inserted
local function insert_after(target, reference)
	local ref_node = links[reference]
	local target_node = links[target]

	local ref_next_nr = ref_node.next -- bufnr for reference's next node in cycle
	local ref_next_node = links[ref_next_nr] -- get that node using its bufnr as key in hash map

	target_node.prev = reference
	target_node.next = ref_next_nr

	ref_next_node.prev = target
	ref_node.next = target
end

---Inserts the bufnr into the list such that the old current buffer is previous to it. The bufnr becomes the new current
---buffer. Triggered by an autocmd set on "BufEnter" in `lua/plugin/bufstak.lua`.
---
---@param bufnr number - the buffer number being entered by neovim.
function M.visit(bufnr)
	if navigating then
		return
	end

	if not is_valid_buf(bufnr) then
		return
	end

	-- Initialize the linked list if nil.
	if not current_bufnr or not links[current_bufnr] then
		current_bufnr = bufnr
		links[bufnr] = { next = bufnr, prev = bufnr }
		return
	end

	-- Do nothing if already in current buffer.
	if current_bufnr == bufnr then
		return
	end

	-- If the buffer was already opened (i.e. in the list), then remove it.
	if links[bufnr] then
		splice(bufnr)
	else
		-- Otherwise initialize a node for the new buffer.
		links[bufnr] = { next = bufnr, prev = bufnr }
	end

	-- Insert the visited buffer into the next position relative to the to-be-old current buffer.
	-- This way, upon updating the current buffer number to the visited one, moving to the previous buffer will return to
	-- the buffer just seen.
	insert_after(bufnr, current_bufnr)

	current_bufnr = bufnr
end

function M.next()
	if not current_bufnr then
		return
	end

	local next_buf = links[current_bufnr].next
	if next_buf == current_bufnr then
		-- Only one buffer open.
		return
	end

	navigating = true
	current_bufnr = next_buf
	vim.api.nvim_set_current_buf(next_buf)
	navigating = false
end

function M.prev()
	if not current_bufnr then
		return
	end

	local prev_buf = links[current_bufnr].prev
	if prev_buf == current_bufnr then
		-- Only one buffer open.
		return
	end

	navigating = true
	current_bufnr = prev_buf
	vim.api.nvim_set_current_buf(prev_buf)
	navigating = false
end

function M.list()
	if not current_bufnr then
		print("Bufstack is empty.")
		return
	end

	local ptr_bufnr = links[current_bufnr].prev
	while ptr_bufnr ~= current_bufnr do
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ptr_bufnr), ":.")
		print(string.format("  %d - %s", ptr_bufnr, name))

		ptr_bufnr = links[ptr_bufnr].prev
	end

	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ptr_bufnr), ":.")
	print(string.format("  %d - %s (Current)", ptr_bufnr, name))
end

function M.remove(bufnr)
	if not links[bufnr] then
		return
	end

	if current_bufnr == bufnr then
		current_bufnr = links[bufnr].next
	end

	splice(bufnr)

	links[bufnr] = nil
end

---Returns a table of buffer numbers ordered from the current buffer's prev through next, ending with current.
function M.flatten_links()
	if not current_bufnr or not links[current_bufnr] then
		return {}
	end

	local list = {}
	local ptr_bufnr = current_bufnr

	repeat
		if not links[ptr_bufnr] then
			break
		end
		ptr_bufnr = links[ptr_bufnr].prev
		table.insert(list, ptr_bufnr)
	until ptr_bufnr == current_bufnr

	return list
end

return M
