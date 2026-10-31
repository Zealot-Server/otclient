local finished = false
local loginStarted = false
local characterLoginStarted = false
local gameCallbacks
local stage = 'startup'
local originalLoginFailed

local function setStage(nextStage)
    stage = nextStage
    g_logger.info('[zealot-e2e] stage: ' .. nextStage)
end

local function writeResult(status, detail)
    if finished then
        return
    end

    finished = true
    detail = tostring(detail or ''):gsub('[\r\n]+', ' ')
    g_logger.info(string.format('[zealot-e2e] %s: %s', status, detail))
    g_resources.writeFileContentsToWorkDir('zealot-e2e-result.txt', string.format('%s\n%s\n', status, detail))
    scheduleEvent(g_app.exit, 500)
end

local function fail(detail)
    writeResult('FAIL', detail)
end

local function selectCharacter()
    if finished or characterLoginStarted then
        return
    end

    if not G.characters then
        scheduleEvent(selectCharacter, 250)
        return
    end

    setStage('character list received')
    local target = E2E_CREDENTIALS and E2E_CREDENTIALS.character
    for _, character in ipairs(G.characters) do
        if character.name == target then
            characterLoginStarted = true
            setStage('connecting to game world')
            g_settings.set('last-used-character', character.name)
            g_settings.set('last-used-world', character.worldName)
            CharacterList.rebuildCharactersList()
            CharacterList.doLogin()
            return
        end
    end

    fail('configured test character was not returned by the login server')
end

local function beginLogin()
    if finished or loginStarted then
        return
    end

    if not E2E_CREDENTIALS or not E2E_CREDENTIALS.account or not E2E_CREDENTIALS.password or not E2E_CREDENTIALS.character then
        fail('missing test credentials')
        return
    end

    if not EnterGame or not modules.client_assets or not modules.client_assets.ensureClientVersion then
        fail('login or asset installer module is unavailable')
        return
    end

    loginStarted = true
    setStage('installing verified client assets')
    modules.client_assets.ensureClientVersion(1511, function(success, message)
        if finished then
            return
        end
        if not success then
            fail('asset installation failed: ' .. tostring(message))
            return
        end

        setStage('sending production login')
        EnterGame.setAccountName(g_crypt.encrypt(E2E_CREDENTIALS.account))
        EnterGame.setPassword(g_crypt.encrypt(E2E_CREDENTIALS.password))
        EnterGame.setHttpLogin(false)
        EnterGame.doLogin()
        scheduleEvent(selectCharacter, 250)
    end, true)
end

function init()
    gameCallbacks = {
        onGameStart = function()
            writeResult('PASS', 'production login and game connection succeeded')
        end,
        onLoginError = function(message)
            fail('login error: ' .. tostring(message))
        end,
        onConnectionError = function(message)
            fail('game connection error: ' .. tostring(message))
        end,
        onUpdateNeeded = function()
            fail('client update required')
        end
    }
    connect(g_game, gameCallbacks)

    originalLoginFailed = EnterGame.loginFailed
    EnterGame.loginFailed = function(requestId, message, result)
        if not finished and G.requestId == requestId then
            fail('production login rejected: ' .. tostring(message))
        end
        return originalLoginFailed(requestId, message, result)
    end

    scheduleEvent(beginLogin, 1500)
    scheduleEvent(function()
        if not finished then
            fail('timed out during ' .. stage)
        end
    end, 480000)
end

function terminate()
    if originalLoginFailed then
        EnterGame.loginFailed = originalLoginFailed
        originalLoginFailed = nil
    end
    if gameCallbacks then
        disconnect(g_game, gameCallbacks)
        gameCallbacks = nil
    end
end
