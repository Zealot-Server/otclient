ClientUpdate = {}

local unpackValues = table.unpack or unpack
local downloadPage = 'https://www.zealot.website/?subtopic=downloadclient'
local progressWindow
local downloadOperation
local updatePrompt

local function versionParts(value)
  if type(value) ~= 'string' then return nil end
  local major, minor, patch = value:match('^(%d+)%.(%d+)%.(%d+)$')
  if not major then return nil end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function isNewer(candidate, current)
  local nextVersion, installed = versionParts(candidate), versionParts(current)
  if not nextVersion or not installed then return false end
  for i = 1, 3 do
    if nextVersion[i] ~= installed[i] then
      return nextVersion[i] > installed[i]
    end
  end
  return false
end

local function platformPackage(data)
  if type(data) ~= 'table' or type(data.packages) ~= 'table' then return nil end
  local osName = g_app.getOs()
  local arch = g_app.getBuildArch():lower()
  local system, processor
  if osName == 'mac' then
    system = 'macos'
    if arch == 'arm' or arch == 'arm64' then
      processor = 'arm64'
    elseif arch == 'x64' then
      processor = 'x86_64'
    else
      return nil
    end
  elseif osName == 'windows' or osName == 'linux' then
    if arch ~= 'x64' then return nil end
    system, processor = osName, 'x86_64'
  else
    return nil
  end
  local group = data.packages[system]
  return type(group) == 'table' and group[processor] or nil
end

local function closeProgress()
  if progressWindow then
    progressWindow:destroy()
    progressWindow = nil
  end
end

local function fail(message)
  closeProgress()
  displayErrorBox(tr('Update failed'), message .. '\n' .. tr('You can download the client from the website.'))
end

local function applyArchive(downloadPath, expectedSha256)
  if not progressWindow then return end
  progressWindow.status:setText(tr('Verifying download...'))
  local archiveVirtual = '/downloads/' .. downloadPath
  if g_resources.fileSha256(archiveVirtual):lower() ~= expectedSha256 then
    return fail(tr('The downloaded package failed its SHA-256 check.'))
  end

  local osName = g_app.getOs()
  local archiveName = osName == 'linux' and 'zealot-client.tar.gz' or 'zealot-client.zip'
  local helperName = osName == 'mac' and 'apply-macos.sh' or
    (osName == 'linux' and 'apply-linux.sh' or 'apply-windows.ps1')
  local readOk, source = pcall(g_resources.readFileContents, '/modules/client_update/' .. helperName)
  local relativeArchive = 'updates/' .. archiveName
  local relativeHelper = 'updates/' .. helperName
  if not readOk or source == '' or not g_resources.writeDownloadedFile(downloadPath, relativeArchive, false) or
      not g_resources.writeFileContents(relativeHelper, source) then
    return fail(tr('Could not prepare the update. Check available disk space and permissions.'))
  end

  local base = g_resources.getWriteDir():gsub('[/\\]+$', '') .. '/updates/'
  local args = { base .. helperName, tostring(g_platform.getProcessId()),
    base .. archiveName, g_resources.getWorkDir(), expectedSha256 }
  local program
  if osName == 'windows' then
    program = 'powershell'
    args = { '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', unpackValues(args) }
  else
    program = '/bin/sh'
  end
  progressWindow.status:setText(tr('Installing update and restarting...'))
  if not g_platform.spawnProcess(program, args) then
    return fail(tr('Could not start the update installer.'))
  end
  g_app.exit()
end

function ClientUpdate.init() end

function ClientUpdate.terminate()
  ClientUpdate.cancel()
  if updatePrompt then
    updatePrompt:destroy()
    updatePrompt = nil
  end
end

function ClientUpdate.cancel()
  if downloadOperation then
    HTTP.cancel(downloadOperation)
    downloadOperation = nil
  end
  closeProgress()
end

function ClientUpdate.install(package)
  if progressWindow then return end
  if type(package) ~= 'table' or type(package.url) ~= 'string' or
      type(package.sha256) ~= 'string' or not package.sha256:match('^[a-fA-F0-9]+$') or
      #package.sha256 ~= 64 or
      not package.url:match('^https://github%.com/Zealot%-Server/otclient/releases/download/') then
    return fail(tr('Invalid update package details.'))
  end

  progressWindow = g_ui.displayUI('progress')
  progressWindow:show()
  progressWindow:raise()
  progressWindow:focus()
  progressWindow.progress:setPercent(0)
  downloadOperation = HTTP.download(package.url, 'zealot-release-package',
    function(path, checksum, err)
      downloadOperation = nil
      if not progressWindow then return end
      if err or not path then
        return fail(tr('Download failed. Please try again or use the website.'))
      end
      applyArchive(path, package.sha256:lower())
    end,
    function(percent)
      if progressWindow then
        progressWindow.status:setText(tr('Downloading update...'))
        progressWindow.progress:setPercent(percent)
      end
    end)
end

function ClientUpdate.check()
  if not g_platform.isDesktop() or not Services.clientUpdate then return end
  HTTP.getJSON(Services.clientUpdate, function(data, err)
    if err or type(data) ~= 'table' or not isNewer(data.version, g_app.getVersion()) then return end
    local package = platformPackage(data)
    if not package then return end
    local message = tr('Zealot Client %s is available. Your version is %s.\nChoose how to update.',
      data.version, g_app.getVersion())
    updatePrompt = displayGeneralBox(tr('Client update available'), message, {
      { text = tr('Download from website'), callback = function()
          updatePrompt:destroy()
          updatePrompt = nil
          g_platform.openUrl(downloadPage)
        end },
      { text = tr('Update automatically'), callback = function()
          updatePrompt:destroy()
          updatePrompt = nil
          ClientUpdate.install(package)
        end }
    }, nil, function()
      updatePrompt:destroy()
      updatePrompt = nil
    end)
  end, 10)
end
