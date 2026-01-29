local M = {}

local cfg = {
  root = vim.fn.expand("~/.config/justatool"),
  current = "CURRENT",
  llm_cmd = "llm",
  out_delim = "----- LLM OUTPUT -----",
  refresh_ms = 100,
  system_header = [[<system>
You are an expert programming assistant. Analyze the provided code context carefully.
Base all responses on the provided context. Be concise and accurate.
When generating code, ensure it's valid and follows best practices.
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
  local start_col = start_pos[2] + 1  -- API is 0-indexed, we need 1-indexed
  local end_line = end_pos[1]
  local end_col = end_pos[2] + 1

  -- Validate positions
  if start_line == 0 or end_line == 0 then
    return ""
  end

  -- Get the lines in the selection
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines == 0 then
    return ""
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, "\n")
end

-- Run llm command with streaming output
function M.run_llm()
  local bufnr = vim.api.nvim_get_current_buf()
  local user_prompt = get_buffer_content()

  if user_prompt == "" then
    vim.notify("Buffer is empty", vim.log.levels.WARN)
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

  -- Add delimiter
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", cfg.out_delim, "" })

  -- Create temporary file for input
  local temp_input = vim.fn.tempname()
  local f = io.open(temp_input, "w")
  if not f then
    vim.notify("Failed to create temp file", vim.log.levels.ERROR)
    return
  end
  f:write(full_prompt)
  f:close()

  -- Build command
  local cmd = string.format("cat %s | %s", vim.fn.shellescape(temp_input), cfg.llm_cmd)

  vim.notify("Running LLM...", vim.log.levels.INFO)

  -- Run command with streaming
  local output_buffer = ""
  -- @diagnostic disable-next-line: undefined-field
  local timer = vim.loop.new_timer()
  local last_line_num = vim.api.nvim_buf_line_count(bufnr)

  vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data, _)
      if data and #data > 0 then
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
            vim.schedule(function()
              vim.notify("LLM stderr: " .. line, vim.log.levels.WARN)
            end)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      timer:stop()
      timer:close()

      vim.schedule(function()
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

        if exit_code == 0 then
          vim.notify("LLM finished successfully", vim.log.levels.INFO)
        else
          vim.notify("LLM failed with exit code: " .. exit_code, vim.log.levels.ERROR)
        end

        -- Cleanup temp file
        vim.fn.delete(temp_input)
      end)
    end,
  })

  -- Timer to periodically flush output to buffer
  timer:start(0, cfg.refresh_ms, vim.schedule_wrap(function()
    if output_buffer ~= "" then
      -- Get current last line
      local current_lines = vim.api.nvim_buf_get_lines(bufnr, last_line_num - 1, -1, false)
      local last_content = current_lines[1] or ""

      -- Combine with buffer
      local combined = last_content .. output_buffer
      local lines = vim.split(combined, "\n", { plain = true })

      -- Replace from last_line_num onwards
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
    vim.notify("No visual selection found. Select text first then try again.", vim.log.levels.WARN)
    return
  end

  -- Get visual selection
  local selection = get_visual_selection()

  if selection == "" then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  -- Get current file path
  local filepath = vim.api.nvim_buf_get_name(0)
  local filename = filepath
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
      init_file:write("<user>\n[Write your prompt here]\n</user>\n")
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

  -- Insert context before the <user> tag
  local file = io.open(context_file, "r")
  if file then
    local content = file:read("*all")
    file:close()
    
    -- Find the <user> tag and insert context before it
    local user_pos = content:find("<user>")
    if user_pos then
      local new_content = content:sub(1, user_pos - 1) .. context_entry .. content:sub(user_pos)
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

    -- Reload buffer if context file is already open
---@diagnostic disable-next-line: redefined-local
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if buf_name == context_file then
          -- Reload the buffer content
          vim.api.nvim_buf_call(bufnr, function()
            local view = vim.fn.winsaveview()
            vim.cmd("edit!")
            vim.fn.winrestview(view)
          end)
          break
        end
      end
    end
  else
    vim.notify("Failed to write to context file: " .. context_file, vim.log.levels.ERROR)
  end
end

-- Test function: creates a test buffer and runs llm
function M.test()
  -- Create new buffer
  vim.cmd("enew")
  local bufnr = vim.api.nvim_get_current_buf()

  -- Set test content
  local test_content = {
    "Write a short haiku about programming.",
  }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)

  vim.notify("Test buffer created. Running LLM in 1 second...", vim.log.levels.INFO)

  -- Wait a bit then run
  vim.defer_fn(function()
    M.run_llm()
  end, 1000)
end

-- Test with custom input
function M.test_custom(prompt)
  vim.cmd("enew")
  local bufnr = vim.api.nvim_get_current_buf()

  local content = prompt or "Say hello in 3 different languages."
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

  vim.notify("Test buffer created. Running LLM...", vim.log.levels.INFO)

  vim.defer_fn(function()
    M.run_llm()
  end, 500)
end

-- Setup keymaps
function M.setup(opts)
  opts = opts or {}

  -- Merge config
  if opts.llm_cmd then cfg.llm_cmd = opts.llm_cmd end
  if opts.refresh_ms then cfg.refresh_ms = opts.refresh_ms end
  if opts.out_delim then cfg.out_delim = opts.out_delim end
  if opts.system_header then cfg.system_header = opts.system_header end

  -- Ensure context directory exists
  vim.fn.mkdir(cfg.root, "p")

  -- Create commands
  vim.api.nvim_create_user_command("LLMRun", M.run_llm, {})
  vim.api.nvim_create_user_command("LLMTest", M.test, {})
  vim.api.nvim_create_user_command("LLMTestCustom", function(args)
    M.test_custom(args.args)
  end, { nargs = "?" })

  -- Context management commands
  vim.api.nvim_create_user_command("LLMContextView", function()
    local context_file = cfg.root .. "/" .. cfg.current
    if vim.fn.filereadable(context_file) == 1 then
      vim.cmd("edit " .. context_file)
    else
      vim.notify("No context file found", vim.log.levels.WARN)
    end
  end, {})

  vim.api.nvim_create_user_command("LLMContextClear", function()
    local context_file = cfg.root .. "/" .. cfg.current
    if vim.fn.filereadable(context_file) == 1 then
      vim.fn.delete(context_file)
      vim.notify("Context file cleared", vim.log.levels.INFO)
    else
      vim.notify("No context file found", vim.log.levels.WARN)
    end
  end, {})
  
  vim.api.nvim_create_user_command("LLMContextNew", function()
    local context_file = cfg.root .. "/" .. cfg.current
    vim.fn.delete(context_file)
    vim.cmd("edit " .. context_file)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split("# Add your context using <leader>/ in visual mode\n# Then write your prompt below and run with <leader>?\n", "\n"))
    vim.notify("New context file created", vim.log.levels.INFO)
  end, {})

  vim.notify("JustATool LLM wrapper loaded", vim.log.levels.INFO)
end

return M
