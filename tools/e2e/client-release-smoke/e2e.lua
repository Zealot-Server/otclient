local finished = false
local loginStarted = false
local characterLoginStarted = false
local gameCallbacks

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

    local target = E2E_CREDENTIALS and E2E_CREDENTIALS.character
    for _, character in ipairs(G.characters) do
        if character.name == target then
            characterLoginStarted = true
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

    loginStarted = true
    EnterGame.setAccountName(E2E_CREDENTIALS.account)
    EnterGame.setPassword(E2E_CREDENTIALS.password)
    EnterGame.setHttpLogin(false)
    EnterGame.doLogin()
    scheduleEvent(selectCharacter, 250)
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

    scheduleEvent(beginLogin, 1500)
    scheduleEvent(function()
        if not finished then
            fail('timed out waiting for production login and game connection')
        end
    end, 120000)
end

function terminate()
    if gameCallbacks then
        disconnect(g_game, gameCallbacks)
        gameCallbacks = nil
    end
end
