function translateNetworkError(errcode, connecting, errdesc)
    local text
    if errcode == 111 or errcode == 61 then
        text = tr('Connection refused, the server might be offline or restarting.\nPlease try again later.')
    elseif errcode == 110 or errcode == 60 then
        text = tr('The connection timed out. Please check your internet connection and try again.')
    elseif errcode == 1 then
        text = tr('Connection failed, the server address does not exist.')
    elseif connecting then
        text = tr('Connection failed.')
    else
        text = tr('Your connection has been lost.\nEither your network or the server went down.')
    end
    text = text .. ' ' .. tr('(ERROR %d)', errcode)
    return text
end
