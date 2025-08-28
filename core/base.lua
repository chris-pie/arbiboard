BASE_ARBIBOARD = {}
BASE_ARBIBOARD._modified_tables = {}
BASE_ARBIBOARD._save_history = false
BASE_ARBIBOARD._history = {}
BASE_ARBIBOARD._transaction_layer = 1
BASE_ARBIBOARD._nextID = 1
BASE_ARBIBOARD._object_registry = {}
BASE_ARBIBOARD._history_cursor = nil  -- nil = live; number = browsing at that move index
BASE_ARBIBOARD._init_request = nil
BASE_ARBIBOARD._functions = {}
BASE_ARBIBOARD._function_names = {}
BASE_ARBIBOARD._is_initializing = false

local function _resolve_id(val)
    if type(val) == "string" then
        local obj = BASE_ARBIBOARD._object_registry[val]
        if obj ~= nil then return obj end
        local fn = BASE_ARBIBOARD._function_names[val]
        if fn ~= nil then return fn end
    end
    return val
end

-- Adds a function to the registry.
-- _function_names[name] = func and _functions[func] = name
function BASE_ARBIBOARD.add_function(func, name)
    if not BASE_ARBIBOARD._is_initializing then
        error("BASE_ARBIBOARD.add_function: this function can only be called during init. ")
    end
    if type(func) ~= "function" then
        error("BASE_ARBIBOARD.add_function: 'func' must be a function")
    end
    if type(name) ~= "string" or name == "" then
        error("BASE_ARBIBOARD.add_function: 'name' must be a non-empty string")
    end
    BASE_ARBIBOARD._function_names['BASE_ARBIBOARD_function_'..name] = func
    BASE_ARBIBOARD._functions[func] = 'BASE_ARBIBOARD_function_'..name
end

function BASE_ARBIBOARD.create_game_object()
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
            elseif type(value) == "function" then
                -- Only functions registered via BASE_ARBIBOARD.add_function are allowed
                if BASE_ARBIBOARD._functions[value] == nil then
                    error("Attempted to assign an unregistered function to key '" .. tostring(key) ..
                          "'. Use BASE_ARBIBOARD.add_function(func, name) first.", 2)
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
    BASE_ARBIBOARD._object_registry[proxy["BASE_FIELD_gameobject_id"]] = proxy
    return proxy
end

function BASE_ARBIBOARD._commit_all_tables(request)

    local step_history = {}
    if BASE_ARBIBOARD._transaction_layer == 1 then
        if BASE_ARBIBOARD._save_history then
            table.insert(BASE_ARBIBOARD._history, step_history)
        else
            table.insert(BASE_ARBIBOARD._history, request)
        end
    end

    for k, v in pairs(BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer]) do
        if BASE_ARBIBOARD._transaction_layer == 1 and BASE_ARBIBOARD._save_history then
            local object_changes = v.BASE_METHOD_list_changes()
            local trimmed_changes = {}
            trimmed_changes.move = request
            trimmed_changes.added = BASE_ARBIBOARD._shallow_copy(object_changes.added)
            trimmed_changes.removed = BASE_ARBIBOARD._shallow_copy(object_changes.removed)
            trimmed_changes.modified_old = BASE_ARBIBOARD._shallow_copy(object_changes.modified)
            trimmed_changes.modified_new = {}
            for k1, v1 in pairs(object_changes.modified) do
                trimmed_changes.modified_new[_resolve_id[k1]] = _resolve_id(v[k1])
            end

            step_history[k.BASE_FIELD_gameobject_id] = trimmed_changes
        end
        v.BASE_METHOD_commit_changes()
    end
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = {}
end


function BASE_ARBIBOARD._restore_all_tables()
    for k, v in pairs(BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer]) do
        v.BASE_METHOD_restore()
    end
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = {}
end

function BASE_ARBIBOARD.move(request)
    if BASE_ARBIBOARD._history_cursor ~= nil then
        error("ERROR FROM BASE SCRIPT: Cannot make moves while browsing history. Exit history browsing first.")
    end
    if type(API) ~= "table" then
        error("ERROR FROM BASE SCRIPT: API table is not defined")
    end
    if type(API.move) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.move function is not defined. It should be defined in API script.")
    end
    local success, message = API.move(request)
    if type(success) == "boolean" and type(message) == "string" then
        if success then
            BASE_ARBIBOARD._commit_all_tables(request)
        else
            BASE_ARBIBOARD._restore_all_tables()
        end
        return success, message
    else
        error(string.format("ERROR FROM BASE SCRIPT: Invalid return types from API.move function in API script: expected (boolean, string) but got (%s, %s)", type(success), type(message)))
    end
end

function BASE_ARBIBOARD.init(request, history)
    BASE_ARBIBOARD._is_initializing = true
    if type(API) ~= "table" then
        error("ERROR FROM BASE SCRIPT: API table is not defined")
    end
    if type(API.init) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.init function is not defined. It should be defined in API script.")
    end
    BASE_ARBIBOARD._save_history = history
    if not history then
        -- Requests-only history mode (replay fallback)
        -- Object registry can be weak to avoid leaks; objects are always reachable while game is live.
        setmetatable(BASE_ARBIBOARD._object_registry, {__mode="v"})
    end
    BASE_ARBIBOARD._init_request = request
    local message = API.init(request)
    BASE_ARBIBOARD._commit_all_tables(request)
    if type(message) == "string" then
        return message
    else
        error(string.format("ERROR FROM BASE SCRIPT: Invalid return type from API.init function in API script: %s", type(message)))
    end
    BASE_ARBIBOARD._is_initializing = false
end

function BASE_ARBIBOARD.query(requests)
    if BASE_ARBIBOARD._history_cursor ~= nil then
        error("ERROR FROM BASE SCRIPT: Cannot run queries while browsing history. Exit history browsing first.")
    end
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
    BASE_ARBIBOARD._restore_all_tables()
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
            BASE_ARBIBOARD._restore_all_tables()
            break
        end
    end
    return responses
end

function BASE_ARBIBOARD.simulate_moves(init, requests)
    local responses = BASE_ARBIBOARD._simulate_moves(init, requests)
    BASE_ARBIBOARD._restore_all_tables()
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = nil
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer - 1
    return responses

end

function BASE_ARBIBOARD.try_moves(init, requests)
    local responses = BASE_ARBIBOARD._simulate_moves(init, requests)
    BASE_ARBIBOARD._commit_all_tables()
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = nil
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer - 1
    return responses
end


function BASE_ARBIBOARD._shallow_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = BASE_ARBIBOARD._trim_table(orig)
    elseif orig_type == 'function' then
        local name = BASE_ARBIBOARD._functions[orig]
        if name == nil then
            error("BASE_ARBIBOARD.shallow_copy: encountered unregistered function; register it with BASE_ARBIBOARD.add_function(func, name) first.")
        end
        copy = name
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---@param orig table
function BASE_ARBIBOARD._trim_table(orig)
    copy = {}
    for orig_key, orig_value in pairs(orig) do
        if type(orig_value) == 'table' then
            orig_value = rawget(orig_value, "BASE_FIELD_gameobject_id")
        elseif type(orig_value) == 'function' then
            local name = BASE_ARBIBOARD._functions[orig_value]
            if name == nil then
                error("BASE_ARBIBOARD.trim_table: encountered unregistered function value; register it with BASE_ARBIBOARD.add_function(func, name) first.")
            end
            orig_value = name
        end
        if type(orig_key) == 'table' then
            orig_key = rawget(orig_key, "BASE_FIELD_gameobject_id")
        elseif type(orig_key) == 'function' then
            local kname = BASE_ARBIBOARD._functions[orig_key]
            if kname == nil then
                error("BASE_ARBIBOARD.trim_table: encountered unregistered function key; register it with BASE_ARBIBOARD.add_function(func, name) first.")
            end
            orig_key = kname
        end
        copy[orig_key] = orig_value
    end
    return copy
end

-- Replay fallback helpers (requests-only mode)
local function _replay_reset_to_beginning()
    if type(API) ~= "table" or type(API.init) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.init is required for replay fallback.")
    end
    if BASE_ARBIBOARD._init_request == nil then
        error("ERROR FROM BASE SCRIPT: Replay fallback requires prior init request.")
    end
    -- Clear any browsing-layer edits, then re-run init on the browsing layer
    BASE_ARBIBOARD._restore_all_tables()
    local message = API.init(BASE_ARBIBOARD._init_request)
    BASE_ARBIBOARD._commit_all_tables(BASE_ARBIBOARD._init_request)
    if type(message) ~= "string" then
        error("ERROR FROM BASE SCRIPT: API.init must return a string message for replay fallback.")
    end
end

local function _replay_apply_move_request(req)
    if type(API) ~= "table" or type(API.move) ~= "function" then
        error("ERROR FROM BASE SCRIPT: API.move is required for replay fallback.")
    end
    local ok, msg = API.move(req)
    if ok ~= true then
        BASE_ARBIBOARD._restore_all_tables()
        error("ERROR FROM BASE SCRIPT: Replay failed on a move request. The move did not succeed during replay.")
    end
    BASE_ARBIBOARD._commit_all_tables(req)
end

local function _replay_range(from_idx_inclusive, to_idx_inclusive)
    for i = from_idx_inclusive, to_idx_inclusive do
        local req = BASE_ARBIBOARD._history[i]
        if req ~= nil then
            _replay_apply_move_request(req)
        end
    end
end



local function _apply_map_set(obj, map)
    for k, v in pairs(map or {}) do
        obj[_resolve_id(k)] = _resolve_id(v)
    end
end

local function _apply_map_unset(obj, map)
    for k, _ in pairs(map or {}) do
        obj[_resolve_id(k)] = nil
    end
end

local function _apply_step_forward(step)
    -- Apply changes to move forward one step
    for oid, changes in pairs(step) do
        if type(changes) == "table" then
            local obj = BASE_ARBIBOARD._object_registry[oid]
            if not obj then
                error("ERROR FROM BASE SCRIPT: History refers to unknown object id: " .. tostring(oid))
            end
            -- Remove keys that were removed in that move
            _apply_map_unset(obj, changes.removed)
            -- Add keys that were added in that move
            _apply_map_set(obj, changes.added)
            -- Apply modified to new values
            _apply_map_set(obj, changes.modified_new)
        end
    end
end

local function _apply_step_backward(step)
    -- Apply inverse of a step (to go back one move)
    for oid, changes in pairs(step) do
        if type(changes) == "table" then
            local obj = BASE_ARBIBOARD._object_registry[oid]
            if not obj then
                error("ERROR FROM BASE SCRIPT: History refers to unknown object id: " .. tostring(oid))
            end
            -- Undo additions
            _apply_map_unset(obj, changes.added)
            -- Restore removals
            _apply_map_set(obj, changes.removed)
            -- Restore modified to old values
            _apply_map_set(obj, changes.modified_old)
        end
    end
end

function BASE_ARBIBOARD.history_start()
    if BASE_ARBIBOARD._history_cursor ~= nil then
        return -- already in browsing mode
    end
    -- Open browsing layer
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer + 1
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = {}

    if BASE_ARBIBOARD._save_history then
        BASE_ARBIBOARD._history_cursor = #BASE_ARBIBOARD._history
    else
        -- Replay fallback: rebuild end-of-game state on browsing layer
        _replay_reset_to_beginning()
        BASE_ARBIBOARD._history_cursor = 1
    end
end

function BASE_ARBIBOARD.history_exit()
    if BASE_ARBIBOARD._history_cursor == nil then
        return
    end
    -- Discard browsing-layer mutations and close the layer
    BASE_ARBIBOARD._restore_all_tables()
    BASE_ARBIBOARD._modified_tables[BASE_ARBIBOARD._transaction_layer] = nil
    BASE_ARBIBOARD._transaction_layer = BASE_ARBIBOARD._transaction_layer - 1
    BASE_ARBIBOARD._history_cursor = nil
end

function BASE_ARBIBOARD.history_back(steps)
    if BASE_ARBIBOARD._history_cursor == nil then
        error("ERROR FROM BASE SCRIPT: Not in history browsing mode. Call history_start() first.")
    end
    steps = tonumber(steps) or 1
    if steps < 0 then return BASE_ARBIBOARD.history_forward(-steps) end
    local target = BASE_ARBIBOARD._history_cursor - steps
    if target < 0 then target = 0 end

    if BASE_ARBIBOARD._save_history then
        while BASE_ARBIBOARD._history_cursor > target do
            local step = BASE_ARBIBOARD._history[BASE_ARBIBOARD._history_cursor]
            if step ~= nil then
                _apply_step_backward(step)
            end
            BASE_ARBIBOARD._history_cursor = BASE_ARBIBOARD._history_cursor - 1
        end
        return BASE_ARBIBOARD._history_cursor
    else
        -- Replay fallback: reset to beginning, then replay up to target
        _replay_reset_to_beginning()
        if target > 0 then
            _replay_range(1, target)
        end
        BASE_ARBIBOARD._history_cursor = target
        return BASE_ARBIBOARD._history_cursor
    end
end

function BASE_ARBIBOARD.history_forward(steps)
    if BASE_ARBIBOARD._history_cursor == nil then
        error("ERROR FROM BASE SCRIPT: Not in history browsing mode. Call history_start() first.")
    end
    steps = tonumber(steps) or 1
    if steps < 0 then return BASE_ARBIBOARD.history_back(-steps) end
    local target = BASE_ARBIBOARD._history_cursor + steps
    local last = #BASE_ARBIBOARD._history
    if target > last then target = last end

    if BASE_ARBIBOARD._save_history then
        while BASE_ARBIBOARD._history_cursor < target do
            local step = BASE_ARBIBOARD._history[BASE_ARBIBOARD._history_cursor + 1]
            if step ~= nil then
                _apply_step_forward(step)
            end
            BASE_ARBIBOARD._history_cursor = BASE_ARBIBOARD._history_cursor + 1
        end
        return BASE_ARBIBOARD._history_cursor
    else
        -- Replay only the needed forward moves
        if target > BASE_ARBIBOARD._history_cursor then
            _replay_range(BASE_ARBIBOARD._history_cursor + 1, target)
        end
        BASE_ARBIBOARD._history_cursor = target
        return BASE_ARBIBOARD._history_cursor
    end
end

function BASE_ARBIBOARD.history_goto(index)
    if BASE_ARBIBOARD._history_cursor == nil then
        error("ERROR FROM BASE SCRIPT: Not in history browsing mode. Call history_start() first.")
    end
    index = math.floor(tonumber(index) or 0)
    if index < 0 then index = 0 end
    local last = #BASE_ARBIBOARD._history
    if index > last then index = last end

    if BASE_ARBIBOARD._save_history then
        local delta = index - BASE_ARBIBOARD._history_cursor
        if delta > 0 then
            return BASE_ARBIBOARD.history_forward(delta)
        elseif delta < 0 then
            return BASE_ARBIBOARD.history_back(-delta)
        else
            return BASE_ARBIBOARD._history_cursor
        end
    else
        -- Replay fallback:
        -- If going backwards or to an earlier index, reset and replay to index.
        -- If going forward, replay only the forward gap.
        if index <= BASE_ARBIBOARD._history_cursor then
            _replay_reset_to_beginning()
            if index > 0 then
                _replay_range(1, index)
            end
            BASE_ARBIBOARD._history_cursor = index
        else
            _replay_range(BASE_ARBIBOARD._history_cursor + 1, index)
            BASE_ARBIBOARD._history_cursor = index
        end
        return BASE_ARBIBOARD._history_cursor
    end
end
