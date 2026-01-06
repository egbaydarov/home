local function is_dotnet_available()
  return vim.fn.executable("dotnet") == 1
end

local uv = vim.loop

local function scandir_has_dotnet_markers(dir)
  local handle = uv.fs_scandir(dir)
  if not handle then return false end

  local has_cs = false

  while true do
    local name = uv.fs_scandir_next(handle)
    if not name then break end

    -- solution
    if name:match("%.slnx?$") then
      return true
    end

    -- project files
    if name:match("%.csproj$") or name:match("%.fsproj$") then
      return true
    end

    -- C# files (fallback)
    if name:match("%.cs$") then
      has_cs = true
    end
  end

  return has_cs
end

local function dedupe_paths(paths)
  local seen, out = {}, {}
  for _, p in ipairs(paths) do
    if p and p ~= "" then
      -- normalize-ish: absolute path
      local ap = vim.fn.fnamemodify(p, ":p")
      if not seen[ap] then
        seen[ap] = true
        table.insert(out, ap)
      end
    end
  end
  return out
end

local function prioritized_dirs()
  local dirs = {}

  -- 1) CLI args (nvim my_dir OR nvim some/file.cs)
  local argc = vim.fn.argc()
  for i = 0, argc - 1 do
    local arg = vim.fn.argv(i)
    if arg and arg ~= "" then
      local p = vim.fn.fnamemodify(arg, ":p")
      if vim.fn.isdirectory(p) == 1 then
        table.insert(dirs, p)
      else
        -- if it's a file, use its parent directory
        local parent = vim.fn.fnamemodify(p, ":h")
        if vim.fn.isdirectory(parent) == 1 then
          table.insert(dirs, parent)
        end
      end
    end
  end

  -- 2) current buffer dir (helpful after :edit)
  local buf = vim.api.nvim_buf_get_name(0)
  if buf ~= "" then
    table.insert(dirs, vim.fn.fnamemodify(buf, ":p:h"))
  end

  -- 3) cwd (fallback)
  table.insert(dirs, vim.fn.getcwd())

  return dedupe_paths(dirs)
end

-- your existing function (kept as-is)
-- local function is_dotnet_available() ... end

local function is_dotnet_project()
  -- prioritize: CLI dir(s) > buffer dir > cwd
  for _, dir in ipairs(prioritized_dirs()) do
    if scandir_has_dotnet_markers(dir) then
      if is_dotnet_available() then
        return true
      else
        print("no dotnet executable")
        return false
      end
    end
  end
  return false
end

return {
  {
    --dir = "/home/boogie/stuff/repos/easy-dotnet.nvim",
    "egbaydarov/easy-dotnet.nvim",
    cond = is_dotnet_project,
    -- 'nvim-telescope/telescope.nvim' or 'ibhagwan/fzf-lua' or 'folke/snacks.nvim'
    -- are highly recommended for a better experience
    dependencies = { "nvim-lua/plenary.nvim", 'nvim-telescope/telescope.nvim', 'hrsh7th/nvim-cmp' },
    config = function()
      local cmp = require('cmp')
      local dotnet = require("easy-dotnet")
      cmp.register_source("easy-dotnet", dotnet.package_completion_source)
      dotnet.setup({
        lsp = {
          enabled = true, -- Enable builtin roslyn lsp
          roslynator_enabled = true, -- Automatically enable roslynator analyzer
          analyzer_assemblies = {}, -- Any additional roslyn analyzers you might use like SonarAnalyzer.CSharp
          config = {},
        },
        debugger = {
          -- The path to netcoredbg executable
          --example mason path: vim.fs.joinpath(vim.fn.stdpath("data"), "mason/bin/netcoredbg.cmd"),
          bin_path = nil,
          auto_register_dap = true,
          mappings = {
            open_variable_viewer = { lhs = "T", desc = "open variable viewer" },
          },
        },
        ---@type TestRunnerOptions
        test_runner = {
          ---@type "split" | "vsplit" | "float" | "buf"
          viewmode = "split",
          ---@type number|nil
          vsplit_width = nil,
          ---@type string|nil "topleft" | "topright" 
          vsplit_pos = nil,
          enable_buffer_test_execution = true, --Experimental, run tests directly from buffer
          noBuild = true,
            icons = {
              passed = "",
              skipped = "",
              failed = "",
              success = "",
              reload = "",
              test = "",
              sln = "󰘐",
              project = "󰘐",
              dir = "",
              package = "",
            },
          mappings = {
            run_test_from_buffer = { lhs = "<leader>r", desc = "run test from buffer" },
            peek_stack_trace_from_buffer = { lhs = "<leader>p", desc = "peek stack trace from buffer" },
            filter_failed_tests = { lhs = "<leader>fe", desc = "filter failed tests" },
            debug_test = { lhs = "<leader>d", desc = "debug test" },
            go_to_file = { lhs = "g", desc = "go to file" },
            run_all = { lhs = "<leader>R", desc = "run all tests" },
            run = { lhs = "r", desc = "run test" },
            peek_stacktrace = { lhs = "<leader>p", desc = "peek stacktrace of failed test" },
            expand = { lhs = "o", desc = "expand" },
            expand_node = { lhs = "E", desc = "expand node" },
            expand_all = { lhs = "-", desc = "expand all" },
            collapse_all = { lhs = "W", desc = "collapse all" },
            close = { lhs = "q", desc = "close testrunner" },
            refresh_testrunner = { lhs = "<C-r>", desc = "refresh testrunner" }
          },
          --- Optional table of extra args e.g "--blame crash"
          additional_args = {}
        },
        new = {
          project = {
            prefix = "sln" -- "sln" | "none"
          }
        },
        ---@param action "test" | "restore" | "build" | "run"
        terminal = function(path, action, args)
          args = args or ""
          local commands = {
            run = function() return string.format("dotnet run --project %s %s", path, args) end,
            test = function() return string.format("dotnet test %s %s", path, args) end,
            restore = function() return string.format("dotnet restore %s %s", path, args) end,
            build = function() return string.format("dotnet build %s %s", path, args) end,
            watch = function() return string.format("dotnet watch --project %s %s", path, args) end,
          }
          local command = commands[action]()
          if require("easy-dotnet.extensions").isWindows() == true then command = command .. "\r" end
          vim.cmd("vsplit")
          vim.cmd("term " .. command)
        end,
        csproj_mappings = true,
        fsproj_mappings = true,
        auto_bootstrap_namespace = {
            --block_scoped, file_scoped
            type = "block_scoped",
            enabled = true,
            use_clipboard_json = {
              behavior = "prompt", --'auto' | 'prompt' | 'never',
              register = "+", -- which register to check
            },
        },
        server = {
            ---@type nil | "Off" | "Critical" | "Error" | "Warning" | "Information" | "Verbose" | "All"
            log_level = "Off",
        },
        -- choose which picker to use with the plugin
        -- possible values are "telescope" | "fzf" | "snacks" | "basic"
        -- if no picker is specified, the plugin will determine
        -- the available one automatically with this priority:
        -- telescope -> fzf -> snacks ->  basic
        picker = "telescope",
        background_scanning = true,
        notifications = {
          --Set this to false if you have configured lualine to avoid double logging
          handler = function(start_event)
            local spinner = require("easy-dotnet.ui-modules.spinner").new()
            spinner:start_spinner(start_event.job.name)
            ---@param finished_event JobEvent
            return function(finished_event)
              spinner:stop_spinner(finished_event.result.msg, finished_event.result.level)
            end
          end,
        },
        diagnostics = {
          default_severity = "error",
          setqflist = false,
        },
      })

      -- Example command
      vim.api.nvim_create_user_command('Secrets', function()
        dotnet.secrets()
      end, {})

      vim.keymap.set("n", "<F5>", function()
        dotnet.reset()
      end, { desc = ".net reset defaults" })

      vim.keymap.set("n", "<leader>bs", function()
        dotnet.build_default_quickfix()
      end, { desc = ".net build solution" })

      vim.keymap.set("n", "<leader>tv", function()
        dotnet.testrunner()
      end, { desc = ".net tests view" })
      vim.keymap.set("n", "<leader>tb", function()
        dotnet.testrunner_refresh_build()
      end, { desc = ".net refresh & rebuild tests" })

      vim.keymap.set("n", "<leader>n", function()
        vim.cmd("Dotnet")
      end, { desc = "Dotnet view" })
    end
  }
}
