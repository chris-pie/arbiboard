BASE_ARBIBOARD = {}
BASE_ARBIBOARD._modified_tables = {{}}
BASE_ARBIBOARD._save_history = false
BASE_ARBIBOARD._history = {}
BASE_ARBIBOARD._transaction_layer = 1
BASE_ARBIBOARD._nextID = 1


function BASE_ARBIBOARD.createGameObject()
    local data = {}
    local transactions = {}

    local mt = {
        __index = function(_, key)
            return data[key]
        end,
        __newindex = function(t, key, value)
            if type(value) == "table" then
                if value.BASE_METHOD_commit_changes == nil then
                    error("Attempted to assign a plain Lua table to key '" .. tostring(key) ..
                            "' in a tracked gameobject. Only gameobjects are allowed.", 2)
                end
            end
            BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer][t] = t
            local current_transaction = transactions[BASE_ARBIBOARD._transaction_layer]
            if current_transaction == nil then
                current_transaction = {
                    modified = {},
                    added = {},
                    removed = {}
                }
                transactions[BASE_ARBIBOARD._transaction_layer] = current_transaction
            end
            if data[key] == nil and value ~= nil then
                if not current_transaction.added[key] and not current_transaction.removed[key] then
                    current_transaction.added[key] = value
                elseif current_transaction.removed[key] then
                    current_transaction.modified[key] = current_transaction.removed[key]
                    current_transaction.removed[key] = nil
                end
            elseif data[key] ~= nil and value == nil then
                if current_transaction.added[key] then
                    current_transaction.added[key] = nil
                else
                    current_transaction.modified[key] = nil
                    current_transaction.removed[key] = data[key]
                end
            elseif data[key] ~= value then
                if not current_transaction.added[key] then
                    if current_transaction.removed[key] ~= nil then
                        current_transaction.modified[key] = current_transaction.removed[key]
                        current_transaction.removed[key] = nil
                    elseif current_transaction.modified[key] == nil then
                        current_transaction.modified[key] = data[key]
                    end
                else
                    current_transaction.added[key] = value
                end
            end
            data[key] = value
        end,
        __pairs = function(t)
            return next, data, nil
        end,
        __metatable = {
            commit_changes = function()
                local current_transaction = transactions[BASE_ARBIBOARD._transaction_layer]
                if current_transaction then
                    local previous_transaction = {
                    modified = {},
                    added = {},
                    removed = {}
                    }
                    local transaction_layer = BASE_ARBIBOARD._transaction_layer - 1
                    if transactions[transaction_layer] ~= nil then
                        previous_transaction = transactions[transaction_layer]
                    end
                    for k, v in pairs(current_transaction.removed) do
                        if previous_transaction.added[k] ~= nil then
                            previous_transaction.added[k] = nil
                        else
                            previous_transaction.removed[k] = v
                            previous_transaction.modified[k] = nil
                        end
                    end
                    for k, v in pairs(current_transaction.modified) do
                        if previous_transaction.added[k] ~= nil then
                            previous_transaction.added[k] = v
                        end
                    end
                    for k, v in pairs(current_transaction.added) do
                        if previous_transaction.removed[k] ~= nil then
                            previous_transaction.modified[k] = previous_transaction.removed[k]
                            previous_transaction.removed[k] = nil
                        else
                            previous_transaction.added[k] = v
                        end
                    end
                    transactions[BASE_ARBIBOARD._transaction_layer] = nil

                end
            end,
            restore = function()
                local current_transaction = transactions[BASE_ARBIBOARD._transaction_layer]
                if current_transaction then
                    for k, v in pairs(current_transaction.removed) do
                        data[k] = v
                    end
                    for k, v in pairs(current_transaction.modified) do
                        data[k] = v
                    end
                    for k, v in pairs(current_transaction.added) do
                        data[k] = nil
                    end
                    transactions[BASE_ARBIBOARD._transaction_layer] = nil

                end
            end
        }
    }

    local proxy = {}

    function proxy:BASE_METHOD_commit_changes()
        mt.__metatable.commit_changes()
        BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer][proxy] = nil
    end

    function proxy:BASE_METHOD_restore()
        mt.__metatable.restore()
        BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer][proxy] = nil
    end

    function proxy:BASE_METHOD_list_changes()
        return transactions[BASE_ARBIBOARD._transaction_layer]
    end

    proxy["BASE_FIELD_gameobject_id"] = "BASE_ARBIBOARD_id_" .. BASE_ARBIBOARD._nextID
    BASE_ARBIBOARD._nextID = BASE_ARBIBOARD._nextID + 1


    setmetatable(proxy, mt)
    proxy.commit_changes()
    return proxy
end

function BASE_ARBIBOARD.commit_all_tables()

    local step_history = {}
    if BASE_ARBIBOARD._transaction_layer == 1 and BASE_ARBIBOARD._save_history then
        table.insert(BASE_ARBIBOARD._history, step_history)
    end
    for k, v in pairs(BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer]) do
        if BASE_ARBIBOARD._transaction_layer == 1 and BASE_ARBIBOARD._save_history then
            local object_changes = v.BASE_METHOD_list_changes()
            local trimmed_changes = {}
            trimmed_changes.added = BASE_ARBIBOARD.shallow_copy(object_changes.added)
            trimmed_changes.removed = BASE_ARBIBOARD.shallow_copy(object_changes.removed)
            trimmed_changes.modified_old = BASE_ARBIBOARD.shallow_copy(object_changes.modified)
            trimmed_changes.modified_new = {}
            for k1, v1 in pairs(trimmed_changes.modified_old) do
                trimmed_changes.modified_new[k1] = BASE_ARBIBOARD.trim_table(v1)
            end

            step_history[k.BASE_FIELD_gameobject_id] = trimmed_changes
        end
        v.BASE_METHOD_commit_changes()
    end
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = {}
end


function BASE_ARBIBOARD.restore_all_tables()
    for k, v in pairs(BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer]) do
        v.BASE_METHOD_restore()
    end
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = {}
end

function BASE_ARBIBOARD.move(request)
    if type(API) ~= "table" then
        error("ERROR FROM BASE SCRIPT: API table is not defined")
    end
    if type(API.move) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.move function is not defined. It should be defined in API script.")
    end
    local success, message = API.move(request)
    if type(success) == "boolean" and type(message) == "string" then
        if success then
            BASE_ARBIBOARD.commit_all_tables()
        else
            BASE_ARBIBOARD.restore_all_tables()
        end
        return success, message
    else
        error(string.format("ERROR FROM BASE SCRIPT: Invalid return types from API.move function in API script: expected (boolean, string) but got (%s, %s)", type(success), type(message)))
    end
end

function BASE_ARBIBOARD.init(request, history)
    if type(API) ~= "table" then
        error("ERROR FROM BASE SCRIPT: API table is not defined")
    end
    if type(API.init) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.init function is not defined. It should be defined in API script.")
    end
    BASE_ARBIBOARD._save_history = history
    local message = API.init(request)
    BASE_ARBIBOARD.commit_all_tables()
    if type(message) == "string" then
        return message
    else
        error(string.format("ERROR FROM BASE SCRIPT: Invalid return type from API.init function in API script: %s", type(message)))
    end
end

function BASE_ARBIBOARD.query(requests)
    local responses = {}
    if type(API) ~= "table" then
        error("ERROR FROM BASE SCRIPT: API table is not defined")
    end
    if type(API.query) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.query function is not defined. It should be defined in API script.")
    end
    for i, request in ipairs(requests) do
        local success, message = API.query(request)
        if type(success) == "boolean" and type(message) == "string" then
            table.insert(responses, {["request"] = request, ["message"] = message, ["success"] = success})
            if not success then
                break
            end
        else
            error(string.format("ERROR FROM BASE SCRIPT: Invalid return type from API.query function in API script: %s", type(message)))
        end

    end
    BASE_ARBIBOARD.restore_all_tables()
    return responses
end

function BASE_ARBIBOARD._simulate_moves(init, requests)
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer + 1
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = {}
    init()
    local responses = {}
    for i, v in ipairs(requests) do
        local success, message = API.move(request)
        table.insert(responses, {["request"] = v, ["message"] = message, ["success"] = success})
        if not success then
            BASE_ARBIBOARD.restore_all_tables()
            break
        end
    end
    return responses
end

function BASE_ARBIBOARD.simulate_moves(init, requests)
    local responses = BASE_ARBIBOARD._simulate_moves(init, requests)
    BASE_ARBIBOARD.restore_all_tables()
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = nil
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer - 1
    return responses

end

function BASE_ARBIBOARD.try_moves(init, requests)
    local responses = BASE_ARBIBOARD._simulate_moves(init, requests)
    BASE_ARBIBOARD.commit_all_tables()
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = nil
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer - 1
    return responses
end


function BASE_ARBIBOARD.shallow_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = BASE_ARBIBOARD.trim_table(orig)
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---@param orig table
function BASE_ARBIBOARD.trim_table(orig)
    copy = {}
    for orig_key, orig_value in pairs(orig) do
        if type(orig_value) == 'table' then
            orig_value = rawget(orig_value, "BASE_FIELD_gameobject_id")
        end
        if type(orig_key) == 'table' then
            orig_key = rawget(orig_key, "BASE_FIELD_gameobject_id")
        end
        copy[orig_key] = orig_value
    end
    return copy
end
