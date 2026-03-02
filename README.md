# lazyrails.nvim

Neovim plugin for Ruby on Rails – focused on **navigation** and **test running**,
designed for [LazyVim](https://www.lazyvim.org/) with sensible `<leader>r` keybindings.

Inspired by (and partially derived from) [ror.nvim](https://github.com/weizheheng/ror.nvim) by Wei Zhe.
Credits are retained in the MIT License.

---

## Features

### Navigation helpers
Jump from any Rails file to its counterpart.  
When multiple candidates exist a **Telescope picker** opens automatically.

| From | To | Key |
|---|---|---|
| model / controller / view | **model** | `<leader>rm` |
| model / view / test | **controller** | `<leader>rc` |
| model / controller | **view** | `<leader>rv` |
| model / controller | **test / spec** | `<leader>rs` |

Supports both **minitest** (`test/`) and **RSpec** (`spec/`) projects.

<img width="314" height="231" alt="image" src="https://github.com/user-attachments/assets/0ceb7525-6b5b-4a16-96cc-761ae96e8963" />


### Test runner
Run specs/tests without leaving the editor.  
Results (pass ✅ / fail ❌) are shown inline in the buffer as virtual text and diagnostics.

| Action | Key |
|---|---|
| Run **whole** test file | `<leader>rt` |
| Clear test results | `<leader>rX` |

RSpec requires no extra setup.  
Minitest requires [`minitest-json-reporter`](https://rubygems.org/gems/minitest-json-reporter) and **minitest 5.x** (minitest 6+ is not yet compatible with Rails 8):

```ruby
# Gemfile
gem "minitest", "~> 5.25"

group :test do
  gem "minitest-json-reporter"
end
```

> **Note:** Rails 8 ships with minitest 6 by default, which has a breaking API change that also affects `rails test` itself. Pinning to `~> 5.25` restores compatibility.

---

## Installation

### lazy.nvim (recommended)

```lua
{
  "kalebhenrique/lazyrails.nvim",
  ft = { "ruby", "eruby" },
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  opts = {}, -- see Configuration section below
}
```

### Configuration (optional)

```lua
require("lazyrails").setup({
  test = {
    pass_icon = "✅",
    fail_icon = "❌",
    notification = { timeout = false },
  },
})
```

### Optional dependencies

- [nvim-notify](https://github.com/rcarriga/nvim-notify) – beautiful test result notifications
- [dressing.nvim](https://github.com/stevearc/dressing.nvim) – nicer `vim.ui.select` / `vim.ui.input` appearance
- [which-key.nvim](https://github.com/folke/which-key.nvim) – group label shown automatically under `<leader>r`

---

## Keybinding reference

| Key | Command | Description |
|---|---|---|
| `<leader>rm` | `RailsGoModel` | Go to model |
| `<leader>rc` | `RailsGoController` | Go to controller |
| `<leader>rv` | `RailsGoView` | Go to view |
| `<leader>rs` | `RailsGoTest` | Go to test / spec file |
| `<leader>rt` | `RailsTestRun` | Run test file |
| `<leader>rX` | `RailsTestClear` | Clear test results |

All keys live under the **`Rails`** group visible in which-key.

