-- lazyrails.nvim – plugin entry point
-- Registers user commands and <leader>r keybindings.
-- Compatible with LazyVim / which-key v3 and plain Neovim setups.

-- ── which-key group registration ───────────────────────────────────────────
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  wk.add({
    { "<leader>r",  icon = " ", group = "Rails" },
    { "<leader>rn", group = "Navigate" },
  })
end

-- ── User commands ───────────────────────────────────────────────────────────
vim.api.nvim_create_user_command("RailsTestRun", function(attr)
  require("rails.test").run(attr.args ~= "" and attr.args or nil)
end, {
  nargs = "?",
  complete = function() return { "Line" } end,
})

vim.api.nvim_create_user_command("RailsTestClear",  function() require("rails.test").clear() end, {})
vim.api.nvim_create_user_command("RailsTestTerminal", function() require("rails.test").attach_terminal() end, {})

vim.api.nvim_create_user_command("RailsCoverageShow",  function() require("rails.coverage").show() end, {})
vim.api.nvim_create_user_command("RailsCoverageClear", function() require("rails.coverage").clear() end, {})

vim.api.nvim_create_user_command("RailsGoModel",      function() require("rails.navigations").go_to_model("normal") end, {})
vim.api.nvim_create_user_command("RailsGoController", function() require("rails.navigations").go_to_controller("normal") end, {})
vim.api.nvim_create_user_command("RailsGoView",       function() require("rails.navigations").go_to_view() end, {})
vim.api.nvim_create_user_command("RailsGoTest",       function() require("rails.navigations").go_to_test("normal") end, {})

-- ── Keybindings ─────────────────────────────────────────────────────────────
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
end

-- Test runner
map("<leader>rt", function() require("rails.test").run() end,        "Rails: run test file")
map("<leader>rl", function() require("rails.test").run("Line") end,  "Rails: run test at line")
map("<leader>rX", function() require("rails.test").clear() end,      "Rails: clear test results")
map("<leader>r`", function() require("rails.test").attach_terminal() end, "Rails: toggle test terminal")

-- Coverage
map("<leader>rC", function() require("rails.coverage").show() end,   "Rails: show coverage")

-- Navigation  (skip if already on the target file)
map("<leader>rm", function() require("rails.navigations").go_to_model("normal") end,      "Rails: go to Model")
map("<leader>rc", function() require("rails.navigations").go_to_controller("normal") end, "Rails: go to Controller")
map("<leader>rv", function() require("rails.navigations").go_to_view() end,               "Rails: go to View")
map("<leader>rs", function() require("rails.navigations").go_to_test("normal") end,       "Rails: go to Spec/Test file")
