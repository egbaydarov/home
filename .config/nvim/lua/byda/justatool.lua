local M = {}

-- Track if LLM is currently running
local llm_running = false

local cfg = {
  root = vim.fn.expand("~/.config/justatool"),
  current = "CURRENT",
  llm_cmd = "llm",
  refresh_ms = 100,
  system_header = [[<system>
You are a helpful programming assistant. Answer directly and concisely.
Focus on the user's question. Be brief. Don't over-explain unless asked.
</system>]],
}

-- Get all lines from current buffer
local function get_buffer_content()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return table.concat(lines, "\n")
end

-- Get visual selection
local function get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Use visual marks that are set when exiting visual mode
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')

  local start_line = start_pos[1]
  local start_col = start_pos[2]
  local end_line = end_pos[1]
  local end_col = end_pos[2]

  -- Validate positions
  if start_line == 0 or end_line == 0 then
    return ""
  end

  -- Get mode to detect visual line mode
  local mode = vim.fn.visualmode()

  -- For visual line mode or if selection spans multiple lines, get full lines
  if mode == 'V' or mode == '\22' or start_line ~= end_line then
    -- Get complete lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    return table.concat(lines, "\n")
  else
    -- Character-wise selection on single line
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)
    if #lines == 0 then
      return ""
    end
    -- Both marks are 0-indexed, add 1 for substring (1-indexed)
    return string.sub(lines[1], start_col + 1, end_col + 1)
  end
end

-- Run llm command with streaming output
function M.run_llm()
  -- Ignore if LLM is already running
  if llm_running then
    return
  end

  llm_running = true

  local bufnr = vim.api.nvim_get_current_buf()
  local user_prompt = get_buffer_content()

  if user_prompt == "" then
    llm_running = false
    return
  end

  -- Build the full prompt structure
  local full_prompt = cfg.system_header .. "\n\n"

  -- Check if context file exists and append it
  local context_file = cfg.root .. "/" .. cfg.current
  if vim.fn.filereadable(context_file) == 1 then
    local ctx_file = io.open(context_file, "r")
    if ctx_file then
      local context_content = ctx_file:read("*all")
      ctx_file:close()
      full_prompt = full_prompt .. context_content .. "\n"
    end
  end

  -- Add user prompt
  full_prompt = full_prompt .. "<user>\n" .. user_prompt .. "\n</user>\n"

  -- Add separator and open assistant tag
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "<assistant>" })

  -- Add spinner placeholder
  local spinner_line_num = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "⠋ Thinking..." })

  -- Create temporary file for input
  local temp_input = vim.fn.tempname()
  local f = io.open(temp_input, "w")
  if not f then
    return
  end
  f:write(full_prompt)
  f:close()

  -- Build command
  local cmd = string.format("cat %s | %s", vim.fn.shellescape(temp_input), cfg.llm_cmd)

  -- Run command with streaming
  local output_buffer = ""
  local error_buffer = ""
  local timer = vim.loop.new_timer()
  local spinner_timer = vim.loop.new_timer()
  local last_line_num = vim.api.nvim_buf_line_count(bufnr)
  local first_output_received = false

  -- Spinner animation frames
  local spinner_frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
  local spinner_idx = 1

  -- Start spinner animation
  spinner_timer:start(0, 80, vim.schedule_wrap(function()
    if not first_output_received then
      spinner_idx = (spinner_idx % #spinner_frames) + 1
      vim.api.nvim_buf_set_lines(bufnr, spinner_line_num, spinner_line_num + 1, false,
        { spinner_frames[spinner_idx] .. " Thinking..." })
    end
  end))

  vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        -- Stop spinner on first output
        if not first_output_received then
          first_output_received = true
          spinner_timer:stop()
          spinner_timer:close()
          -- Clear the spinner line - content will start on this line
          vim.schedule(function()
            vim.api.nvim_buf_set_lines(bufnr, spinner_line_num, spinner_line_num + 1, false, {""})
            last_line_num = spinner_line_num + 1
          end)
        end

        -- data is an array of lines, where "" represents a newline
        -- Join them with newlines, but handle the last element specially
        for i, line in ipairs(data) do
          if i == 1 and i == #data then
            -- Single element, just append it
            output_buffer = output_buffer .. line
          elseif i == 1 then
            -- First element, no leading newline
            output_buffer = output_buffer .. line
          elseif i == #data and line == "" then
            -- Last element is empty, which means output ended with newline
            output_buffer = output_buffer .. "\n"
          else
            -- Middle elements, prepend newline
            output_buffer = output_buffer .. "\n" .. line
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            error_buffer = error_buffer .. line .. "\n"
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      timer:stop()
      timer:close()

      -- Stop spinner if still running
      if not first_output_received then
        spinner_timer:stop()
        spinner_timer:close()
      end

      vim.schedule(function()
        -- Handle errors
        if exit_code ~= 0 then
          -- Clear spinner and show error
          if not first_output_received then
            vim.api.nvim_buf_set_lines(bufnr, spinner_line_num, spinner_line_num + 1, false, {""})
            last_line_num = spinner_line_num
          end

          -- Show error message
          local error_lines = {"ERROR: Command failed with exit code " .. exit_code}
          if error_buffer ~= "" then
            table.insert(error_lines, "")
            table.insert(error_lines, "Error output:")
            for line in error_buffer:gmatch("[^\n]+") do
              table.insert(error_lines, line)
            end
          end
          vim.api.nvim_buf_set_lines(bufnr, last_line_num, last_line_num, false, error_lines)
        else
          -- Write any remaining output
          if output_buffer ~= "" then
            -- Get current last line
            local current_lines = vim.api.nvim_buf_get_lines(bufnr, last_line_num - 1, -1, false)
            local last_content = current_lines[1] or ""

            -- Combine with buffer
            local combined = last_content .. output_buffer
            local lines = vim.split(combined, "\n", { plain = true })

            -- Replace from last_line_num onwards
            vim.api.nvim_buf_set_lines(bufnr, last_line_num - 1, -1, false, lines)
            output_buffer = ""
          end
        end

        -- Close assistant tag and add new empty user tag for next interaction
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "</assistant>", "", "<user>", "", "</user>" })

        -- Auto-save the CURRENT file after assistant output
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd("write")
        end)

        -- Cleanup temp file
        vim.fn.delete(temp_input)

        -- Mark LLM as no longer running
        llm_running = false
      end)
    end,
  })

  -- Timer to periodically flush output to buffer
  timer:start(0, cfg.refresh_ms, vim.schedule_wrap(function()
    if output_buffer ~= "" then
      -- On first flush after spinner, just write the output starting at spinner line
      -- On subsequent flushes, combine with the last line
      local current_lines = vim.api.nvim_buf_get_lines(bufnr, last_line_num - 1, last_line_num, false)
      local last_content = current_lines[1] or ""

      -- Combine with buffer
      local combined = last_content .. output_buffer
      local lines = vim.split(combined, "\n", { plain = true })

      -- Replace from last_line_num - 1 onwards
      vim.api.nvim_buf_set_lines(bufnr, last_line_num - 1, -1, false, lines)

      -- Update last line number
      last_line_num = vim.api.nvim_buf_line_count(bufnr)
      output_buffer = ""
    end
  end))
end

-- Add visual selection to context file
function M.add_to_context()
  -- Check if visual marks are set
  local bufnr = vim.api.nvim_get_current_buf()
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')

  if start_pos[1] == 0 or end_pos[1] == 0 then
    return
  end

  -- Get visual selection
  local selection = get_visual_selection()

  if selection == "" then
    return
  end

  -- Get current file path
  local filepath = vim.api.nvim_buf_get_name(0)
  local filename
  if filepath == "" then
    filename = "[No Name]"
  else
    filename = vim.fn.fnamemodify(filepath, ":t")  -- Just filename, not full path
  end

  -- Detect language from file extension
  local ext = vim.fn.fnamemodify(filepath, ":e")
  local lang_map = {
    lua = "lua", py = "python", js = "javascript", ts = "typescript",
    c = "c", cpp = "cpp", h = "c", hpp = "cpp", cs = "csharp",
    java = "java", go = "go", rs = "rust", rb = "ruby", php = "php",
    sh = "bash", bash = "bash", zsh = "bash", sql = "sql", html = "html",
    css = "css", json = "json", xml = "xml", yaml = "yaml", toml = "toml",
    md = "markdown", txt = "text",
  }
  local lang = lang_map[ext] or ""

  -- Ensure config directory exists
  vim.fn.mkdir(cfg.root, "p")

  -- Build context file path
  local context_file = cfg.root .. "/" .. cfg.current

  -- Check if file exists, if not create with system header and placeholder
  local file_exists = vim.fn.filereadable(context_file) == 1
  if not file_exists then
    local init_file = io.open(context_file, "w")
    if init_file then
      init_file:write(cfg.system_header .. "\n\n")
      init_file:write("<user>\n\n</user>")
      init_file:close()
    end
  end

  -- Format the context entry with code blocks
  local context_entry
  if lang ~= "" then
    context_entry = string.format(
      "<context>\nFile: %s\n\n```%s\n%s\n```\n</context>\n\n",
      filename,
      lang,
      selection
    )
  else
    context_entry = string.format(
      "<context>\nFile: %s\n\n%s\n</context>\n\n",
      filename,
      selection
    )
  end

  -- Insert context before the LAST <user> tag
  local file = io.open(context_file, "r")
  if file then
    local content = file:read("*all")
    file:close()

    -- Find the LAST <user> tag by finding all occurrences
    local last_user_pos = nil
    local search_pos = 1
    while true do
      local found_pos = content:find("<user>", search_pos, true)
      if not found_pos then
        break
      end
      last_user_pos = found_pos
      search_pos = found_pos + 1
    end

    if last_user_pos then
      local new_content = content:sub(1, last_user_pos - 1) .. context_entry .. content:sub(last_user_pos)
      file = io.open(context_file, "w")
      if file then
        file:write(new_content)
        file:close()
      end
    else
      -- No <user> tag found, just append
      file = io.open(context_file, "a")
      if file then
        file:write(context_entry)
        file:close()
      end
    end
    local line_count = #vim.split(selection, "\n", { plain = true })
    local msg = line_count == 1 and "1 line yanked to LLM context" or string.format("%d lines yanked to LLM context", line_count)
    vim.api.nvim_echo({{msg, "Normal"}}, false, {})

    -- Reload buffer if context file is already open and auto-save
---@diagnostic disable-next-line: redefined-local
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if buf_name == context_file then
          -- Reload the buffer content and save
          vim.api.nvim_buf_call(bufnr, function()
            local view = vim.fn.winsaveview()
            vim.cmd("edit!")
            vim.fn.winrestview(view)
            vim.cmd("write")
          end)
          break
        end
      end
    end
  end
end

-- Define signs once globally (called during setup)
local signs_defined = false
local function define_llm_signs()
  if not signs_defined then
    -- Define Solarized Light color highlights
    vim.cmd("hi LLMSystemColor guifg=#268bd2 ctermfg=33")      -- Solarized Blue
    vim.cmd("hi LLMContextColor guifg=#2aa198 ctermfg=37")     -- Solarized Cyan
    vim.cmd("hi LLMUserColor guifg=#b58900 ctermfg=136")       -- Solarized Yellow
    vim.cmd("hi LLMAssistantColor guifg=#859900 ctermfg=64")   -- Solarized Green

    vim.fn.sign_define("LLMSystem", { text = "󰒓", texthl = "LLMSystemColor" })
    vim.fn.sign_define("LLMContext", { text = "󰈙", texthl = "LLMContextColor" })
    vim.fn.sign_define("LLMUser", { text = "󰀄", texthl = "LLMUserColor" })
    vim.fn.sign_define("LLMAssistant", { text = "󰚩", texthl = "LLMAssistantColor" })
    signs_defined = true
  end
end

-- Setup signs and horizontal lines for CURRENT file
local function setup_llm_view(bufnr)
  local context_file = cfg.root .. "/" .. cfg.current
  local buf_name = vim.api.nvim_buf_get_name(bufnr)

  if buf_name ~= context_file then
    return
  end

  -- Ensure signs are defined
  define_llm_signs()

  -- Clear existing signs for this buffer
  vim.fn.sign_unplace("llm_tags", { buffer = bufnr })

  -- Set up concealment for tags - conceal entire line
  vim.api.nvim_buf_call(bufnr, function()
    vim.opt_local.conceallevel = 3     -- Completely hide concealed text
    vim.opt_local.concealcursor = "nvic" -- Keep concealed even when cursor is on the line

    -- Clear any existing syntax and set up fresh
    vim.cmd("syntax clear")

    -- Conceal the ENTIRE tag lines (including the whole line)
    vim.cmd([[syntax match LLMTagConceal '^\s*<system>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*</system>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*<context>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*</context>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*<user>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*</user>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*<assistant>\s*$' conceal]])
    vim.cmd([[syntax match LLMTagConceal '^\s*</assistant>\s*$' conceal]])
  end)

  -- Use Solarized Light colors for horizontal lines (matching signs)
  vim.cmd("hi LLMSystemLine guifg=#268bd2 ctermfg=33")      -- Solarized Blue
  vim.cmd("hi LLMContextLine guifg=#2aa198 ctermfg=37")     -- Solarized Cyan  
  vim.cmd("hi LLMUserLine guifg=#b58900 ctermfg=136")       -- Solarized Yellow
  vim.cmd("hi LLMAssistantLine guifg=#859900 ctermfg=64")   -- Solarized Green

  -- Clear existing extmarks
  local ns_id = vim.api.nvim_create_namespace("llm_lines")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Calculate line width based on window width
  local line_width = 70  -- Default
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr and vim.api.nvim_win_is_valid(win) then
      local win_width = vim.api.nvim_win_get_width(win)
      -- Account for sign column and a bit of padding
      line_width = win_width - 5
      break
    end
  end

  -- Parse buffer and place signs + horizontal lines with labels
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    local sign_name = nil
    local line_text = nil
    local hl_group = nil

    if line == "<system>" then
      sign_name = "LLMSystem"
      local label = " system "
      line_text = "╭─" .. label .. string.rep("─", math.max(line_width - #label - 2, 5))
      hl_group = "LLMSystemLine"
    elseif line == "</system>" then
      line_text = "╰" .. string.rep("─", line_width - 1)
      hl_group = "LLMSystemLine"
    elseif line == "<context>" then
      sign_name = "LLMContext"
      local label = " context "
      line_text = "┌─" .. label .. string.rep("─", math.max(line_width - #label - 2, 5))
      hl_group = "LLMContextLine"
    elseif line == "</context>" then
      line_text = "└" .. string.rep("─", line_width - 1)
      hl_group = "LLMContextLine"
    elseif line == "<user>" then
      sign_name = "LLMUser"
      local label = " user "
      line_text = "┌─" .. label .. string.rep("─", math.max(line_width - #label - 2, 5))
      hl_group = "LLMUserLine"
    elseif line == "</user>" then
      line_text = "└" .. string.rep("─", line_width - 1)
      hl_group = "LLMUserLine"
    elseif line == "<assistant>" then
      sign_name = "LLMAssistant"
      local label = " assistant "
      line_text = "╔═" .. label .. string.rep("═", math.max(line_width - #label - 2, 5))
      hl_group = "LLMAssistantLine"
    elseif line == "</assistant>" then
      line_text = "╚" .. string.rep("═", line_width - 1)
      hl_group = "LLMAssistantLine"
    end

    -- Place sign if needed
    if sign_name then
      vim.fn.sign_place(0, "llm_tags", sign_name, bufnr, { lnum = i, priority = 10 })
    end

    -- Place horizontal line if needed - overlay it on the tag line
    if line_text then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        virt_text = {{line_text, hl_group}},
        virt_text_pos = "overlay",  -- Replace the line visually
        priority = 1000,
      })
    end
  end
end

-- Stash current conversation with LLM-generated filename
function M.stash()
  local context_file = cfg.root .. "/" .. cfg.current
  if vim.fn.filereadable(context_file) ~= 1 then
    vim.api.nvim_echo({{"No CURRENT file to stash", "WarningMsg"}}, false, {})
    return
  end

  -- Read the current file content
  local file = io.open(context_file, "r")
  if not file then
    vim.api.nvim_echo({{"Failed to read CURRENT file", "ErrorMsg"}}, false, {})
    return
  end
  local content = file:read("*all")
  file:close()

  -- Prepare prompt for LLM to generate filename
  local prompt = [[Generate a short, descriptive filename (2-4 words, snake_case) for this conversation.
Only output the filename without extension. No explanations.

Conversation:
]] .. content:sub(1, 2000) -- Limit to first 2000 chars for context

  vim.api.nvim_echo({{"Generating filename...", "Normal"}}, false, {})

  -- Create temp file with prompt
  local temp_input = vim.fn.tempname()
  local f = io.open(temp_input, "w")
  if not f then
    vim.api.nvim_echo({{"Failed to create temp file", "ErrorMsg"}}, false, {})
    return
  end
  f:write(prompt)
  f:close()

  -- Run LLM to get filename
  local cmd = string.format("cat %s | %s", vim.fn.shellescape(temp_input), cfg.llm_cmd)
  local output = ""

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            output = output .. line
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.fn.delete(temp_input)
      vim.schedule(function()
        if exit_code ~= 0 then
          vim.api.nvim_echo({{"LLM command failed", "ErrorMsg"}}, false, {})
          return
        end

        -- Clean up the filename suggestion
        local filename = output:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n.*", "")
        -- Remove any non-alphanumeric chars except underscore
        filename = filename:gsub("[^a-zA-Z0-9_]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
        -- Limit length
        filename = filename:sub(1, 50)

        if filename == "" then
          filename = "conversation_" .. os.time()
        end

        -- Add extension
        filename = filename .. ".llmchat"

        -- Build new path
        local new_path = cfg.root .. "/" .. filename

        -- Check if file already exists
        if vim.fn.filereadable(new_path) == 1 then
          filename = filename:gsub("%.llmchat$", "_" .. os.time() .. ".llmchat")
          new_path = cfg.root .. "/" .. filename
        end

        -- Rename the file
        local success = vim.fn.rename(context_file, new_path)
        if success == 0 then
          vim.api.nvim_echo({{"Stashed as: " .. filename, "Normal"}}, false, {})
          vim.cmd("qa")
        else
          vim.api.nvim_echo({{"Failed to rename file", "ErrorMsg"}}, false, {})
        end
      end)
    end,
  })
end

-- Setup keymaps
function M.setup(opts)
  opts = opts or {}

  -- Merge config
  if opts.llm_cmd then cfg.llm_cmd = opts.llm_cmd end
  if opts.refresh_ms then cfg.refresh_ms = opts.refresh_ms end
  if opts.system_header then cfg.system_header = opts.system_header end

  -- Ensure context directory exists
  vim.fn.mkdir(cfg.root, "p")

  -- Helper to check if current buffer is CURRENT file
  local function is_current_file()
    local current_buf = vim.api.nvim_buf_get_name(0)
    local context_file = cfg.root .. "/" .. cfg.current
    return current_buf == context_file
  end

  -- Setup autocommand to apply signs and lines to CURRENT file
  vim.api.nvim_create_autocmd({"BufRead", "BufWritePost", "WinResized", "VimResized"}, {
    pattern = "*/justatool/CURRENT",
    callback = function(ev)
      -- Double-check this is our CURRENT file
      local buf_name = vim.api.nvim_buf_get_name(ev.buf)
      local context_file = vim.fn.expand(cfg.root .. "/" .. cfg.current)
      if buf_name == context_file then
        vim.schedule(function()
          setup_llm_view(ev.buf)
        end)
      end
    end,
  })

  -- Create commands (only work in CURRENT file)
  vim.api.nvim_create_user_command("LLMRun", function()
    if not is_current_file() then
      return
    end
    M.run_llm()
  end, {})

  -- Context management commands
  vim.api.nvim_create_user_command("LLMContextView", function()
    local context_file = cfg.root .. "/" .. cfg.current
    if vim.fn.filereadable(context_file) == 1 then
      vim.cmd("edit " .. context_file)
    end
  end, {})

  vim.api.nvim_create_user_command("LLMContextClear", function()
    local context_file = cfg.root .. "/" .. cfg.current
    if vim.fn.filereadable(context_file) == 1 then
      vim.fn.delete(context_file)
    end
  end, {})

  vim.api.nvim_create_user_command("LLMContextNew", function()
    local context_file = cfg.root .. "/" .. cfg.current
    vim.fn.delete(context_file)
    vim.cmd("edit " .. context_file)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split("# Add your context using <leader>/ in visual mode\n# Then write your prompt below and run with <leader>?\n", "\n"))
  end, {})

  vim.api.nvim_create_user_command("LLMStash", function()
    M.stash()
  end, {})
end

return M
