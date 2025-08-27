API = {}
function API.move(request)
    return true, request .. "AA"
end

function API.init(request)
    return request .. "frominit"
end

function API.query(request)
    return false, "query: " .. request
end