return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "leoluz/nvim-dap-go",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "williamboman/mason.nvim",
    },
    config = function()
      local dap = require "dap"
      local ui = require "dapui"

      local function get_arguments()
        return coroutine.create(function(dap_run_co)
          local args = {}
          vim.ui.input({ prompt = "Args: " }, function(input)
            args = vim.split(input or "", " ")
            coroutine.resume(dap_run_co, args)
          end)
        end)
      end

      require("dapui").setup()
      require("dap-go").setup{
          dap_configurations = {
            {
              type = "go",
              name = "Debug Package (C deps)",
              request = "launch",
              program = "${fileDirname}",
              args = get_arguments,
              buildFlags = {},
              outputMode = "remote",
            }
          },
          delve = {
            path = "dlv",
            initialize_timeout_sec = 20,
            build_flags = {},
            port = "${port}",
            cwd = nil,
          },
          tests = {
            verbose = true,
          }
      }
      require("nvim-dap-virtual-text").setup()

      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- Visual Studio keymaps
      vim.keymap.set("n", "<F9>", dap.toggle_breakpoint, { desc = "Breakpoint"})
      vim.keymap.set("n", "<C-F10>", dap.run_to_cursor, { desc = "Run to cursor"})
      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Continue (Start)"})
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Step Into"})
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Step Over"})
      vim.keymap.set("n", "<S-F11>", dap.step_out, { desc = "Step Out"})
      vim.keymap.set("n", "<S-F5>", dap.terminate, { desc = "Terminate Debug"})
      vim.keymap.set("n", "<leader>dv", ui.toggle, { desc = "Debugger UI toggle"})
    end
  }
}
