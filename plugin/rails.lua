-- lazyrails.nvim – plugin entry point
-- Registers user commands and <leader>r keybindings.
-- Compatible with LazyVim / which-key v3 and plain Neovim setups.
local function is_inertia_project()
  return vim.fn.isdirectory("app/frontend/pages") == 1
end
-- ── which-key group registration ───────────────────────────────────────────
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  wk.add({
    { "<leader>r",  icon = " ", group = "Rails" },
    { "<leader>rn", group = "Navigate" },
  })
end

-- ── User commands ───────────────────────────────────────────────────────────
vim.api.nvim_create_user_command("RailsTestRun", function() require("rails.test").run() end, {})

vim.api.nvim_create_user_command("RailsTestClear", function() require("rails.test").clear() end, {})

vim.api.nvim_create_user_command("RailsGoModel",      function() require("rails.navigations").go_to_model("normal") end, {})
vim.api.nvim_create_user_command("RailsGoController", function() require("rails.navigations").go_to_controller("normal") end, {})
vim.api.nvim_create_user_command("RailsGoView",       function() require("rails.navigations").go_to_view() end, {})
vim.api.nvim_create_user_command("RailsGoTest",       function() require("rails.navigations").go_to_test("normal") end, {})

-- ── Keybindings ─────────────────────────────────────────────────────────────
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
end

local view_desc = is_inertia_project() and "Rails: go to Page" or "Rails: go to View"

-- Test runner
map("<leader>rt", function() require("rails.test").run() end,  "Rails: run test file")
map("<leader>rX", function() require("rails.test").clear() end, "Rails: clear test results")

-- Navigation
map("<leader>rm", function() require("rails.navigations").go_to_model("normal") end,      "Rails: go to Model")
map("<leader>rc", function() require("rails.navigations").go_to_controller("normal") end, "Rails: go to Controller")
map("<leader>rv", function() require("rails.navigations").go_to_view() end,               view_desc)
map("<leader>rs", function() require("rails.navigations").go_to_test("normal") end,       "Rails: go to Spec/Test file")

-- Per-buffer: hide keymaps that don't apply to the current file context
local function get_file_context(path)
  if path:match("app/models/") then return "model"
  elseif path:match("app/controllers/") then return "controller"
  elseif path:match("app/views/") or path:match("app/frontend/pages/") then return "view"
  elseif path:match("spec/") or path:match("test/") then return "test"
  end
end

-- Keys to suppress per context (the one you're already in has no "go to" value)
local hide_per_context = {
  model      = { "<leader>rm", "<leader>rt", "<leader>rX" },
  controller = { "<leader>rc", "<leader>rt", "<leader>rX" },
  view       = { "<leader>rm", "<leader>rv", "<leader>rs", "<leader>rt", "<leader>rX" },
  test       = { "<leader>rs" },
}

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = { "*.rb", "*.html.erb", "*.jsx", "*.tsx" },
  callback = function()
    local path = vim.fn.expand("%:~:.")
    local context = get_file_context(path)
    if not context then return end

    local bufnr = vim.api.nvim_get_current_buf()
    for _, key in ipairs(hide_per_context[context] or {}) do
      vim.keymap.set("n", key, "<nop>", { buffer = bufnr, silent = true })
      if wk_ok then
        wk.add({ { key, buffer = bufnr, hidden = true } })
      end
    end
  end,
})
