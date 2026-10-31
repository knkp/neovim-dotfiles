-- Live code Kabelsalat (https://kabel.salat.dev) from a Neovim buffer.
--
-- Launches the Kabelsalat web REPL in a browser via Puppeteer (js/launch.js) and keeps the
-- REPL editor in sync with a Neovim buffer: edits are mirrored live, and saving re-evaluates.

local M = {}

local MESSAGES = {
  CONTENT = "KS_CONTENT:",
  UPDATE = "KS_UPDATE",
  STOP = "KS_STOP",
  TOGGLE = "KS_TOGGLE",
  QUIT = "KS_QUIT",
  READY = "KS_READY",
  ERROR = "KS_ERROR:",
}

local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

local config = {
  url = "https://kabel.salat.dev/",
  browser_exec_path = nil,
  user_data_dir = nil,
  headless = false,
  -- Directory containing the puppeteer package; nil searches the runtimepath (e.g. strudel.nvim's node_modules)
  node_path = nil,
  -- Mirror buffer edits into the REPL editor as you type
  sync_on_change = true,
  -- Re-evaluate the patch whenever the synced buffer is written
  update_on_save = true,
}

local job_id = nil
local synced_buf = nil
local augroup = vim.api.nvim_create_augroup("Kabelsalat", { clear = true })

local function send(message)
  if not job_id then
    vim.notify("No active Kabelsalat session, run :KabelsalatLaunch", vim.log.levels.WARN)
    return false
  end
  vim.fn.chansend(job_id, message .. "\n")
  return true
end

local function send_buffer_content()
  if not synced_buf or not vim.api.nvim_buf_is_valid(synced_buf) then
    return
  end
  local content = table.concat(vim.api.nvim_buf_get_lines(synced_buf, 0, -1, false), "\n")
  send(MESSAGES.CONTENT .. vim.base64.encode(content))
end

local function find_node_path()
  if config.node_path then
    return vim.fn.expand(config.node_path)
  end
  local candidates = { plugin_root }
  vim.list_extend(candidates, vim.api.nvim_list_runtime_paths())
  for _, dir in ipairs(candidates) do
    local modules = dir .. "/node_modules"
    if vim.fn.isdirectory(modules .. "/puppeteer") == 1 then
      return modules
    end
  end
  return nil
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  local commands = {
    KabelsalatLaunch = M.launch,
    KabelsalatQuit = M.quit,
    KabelsalatUpdate = M.update,
    KabelsalatStop = M.stop,
    KabelsalatToggle = M.toggle,
  }
  for name, fn in pairs(commands) do
    vim.api.nvim_create_user_command(name, function()
      fn()
    end, {})
  end
  vim.api.nvim_create_user_command("KabelsalatSetBuffer", function(args)
    M.set_buffer(tonumber(args.args))
  end, { nargs = "?" })
end

function M.is_launched()
  return job_id ~= nil
end

function M.launch()
  if job_id then
    vim.notify("Kabelsalat is already running, run :KabelsalatQuit to quit.", vim.log.levels.ERROR)
    return
  end

  local node_path = find_node_path()
  if not node_path then
    vim.notify("Kabelsalat needs puppeteer: install strudel.nvim or set node_path", vim.log.levels.ERROR)
    return
  end

  local cmd = { "node", plugin_root .. "/js/launch.js", "--url=" .. config.url }
  if config.browser_exec_path then
    table.insert(cmd, "--browser-exec-path=" .. config.browser_exec_path)
  end
  if config.user_data_dir then
    table.insert(cmd, "--user-data-dir=" .. vim.fn.expand(config.user_data_dir))
  end
  if config.headless then
    table.insert(cmd, "--headless")
  end

  -- Bind the buffer that was current at launch time
  local launch_buf = vim.api.nvim_get_current_buf()

  job_id = vim.fn.jobstart(cmd, {
    env = { NODE_PATH = node_path },
    stdout_buffered = false,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line == MESSAGES.READY then
          vim.schedule(function()
            vim.notify("Kabelsalat is ready", vim.log.levels.INFO)
            M.set_buffer(launch_buf)
          end)
        elseif vim.startswith(line, MESSAGES.ERROR) then
          local message = vim.base64.decode(line:sub(#MESSAGES.ERROR + 1))
          if message ~= "" then
            vim.schedule(function()
              vim.notify("Kabelsalat Error: " .. message, vim.log.levels.ERROR)
            end)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            vim.notify("Kabelsalat Process Error: " .. line, vim.log.levels.ERROR)
          end)
        end
      end
    end,
    on_exit = function(_, code)
      job_id = nil
      synced_buf = nil
      vim.api.nvim_clear_autocmds({ group = augroup })
      vim.schedule(function()
        if code == 0 then
          vim.notify("Kabelsalat session closed", vim.log.levels.INFO)
        else
          vim.notify("Kabelsalat process exited with code " .. code, vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if job_id <= 0 then
    job_id = nil
    vim.notify("Failed to start Kabelsalat (is node installed?)", vim.log.levels.ERROR)
  end
end

function M.set_buffer(bufnr)
  if not job_id then
    vim.notify("No active Kabelsalat session", vim.log.levels.WARN)
    return
  end
  bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer number for :KabelsalatSetBuffer", vim.log.levels.ERROR)
    return
  end

  synced_buf = bufnr
  vim.api.nvim_clear_autocmds({ group = augroup })

  if config.sync_on_change then
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = augroup,
      buffer = bufnr,
      callback = send_buffer_content,
    })
  end
  if config.update_on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = augroup,
      buffer = bufnr,
      callback = M.update,
    })
  end
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      synced_buf = nil
      vim.api.nvim_clear_autocmds({ group = augroup })
    end,
  })

  send_buffer_content()
  local name = vim.api.nvim_buf_get_name(bufnr)
  vim.notify("Kabelsalat is now syncing " .. (name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("buffer " .. bufnr)))
end

-- Push the latest buffer content, then evaluate it
function M.update()
  send_buffer_content()
  send(MESSAGES.UPDATE)
end

function M.stop()
  send(MESSAGES.STOP)
end

function M.toggle()
  send_buffer_content()
  send(MESSAGES.TOGGLE)
end

function M.quit()
  send(MESSAGES.QUIT)
end

return M
