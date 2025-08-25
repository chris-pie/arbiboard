-- serialize.lua
local function make_serializer(opts)
    opts = opts or {}
    local ID_FIELD = opts.id_field or "id"
    local INDENT   = opts.indent   or "  "
    local SKIP_FUNC_USER_THREAD = true   -- ignore these value types

    local function is_ident(s)
        return type(s) == "string" and s:match("^[_%a][_%w]*$")
    end

    local function q(s) return string.format("%q", s) end

    local function serialize_value(v, seen, indent)
        local tv = type(v)

        if tv == "nil" or tv == "number" or tv == "boolean" then
            return tostring(v)
        elseif tv == "string" then
            return q(v)
        elseif tv ~= "table" then
            if SKIP_FUNC_USER_THREAD then
                return nil -- signal "skip"
            else
                error("Cannot serialize type: " .. tv)
            end
        end

        local id = rawget(v, ID_FIELD)

        if seen[v] then
            if id == nil then
                error("Cannot serialize repeated reference/cycle without '" .. ID_FIELD .. "' on table")
            end
            return tostring(id)
        end

        seen[v] = true

        local pieces = {}
        local nextIndent = indent .. INDENT
        table.insert(pieces, "{\n")

        if id ~= nil then
            table.insert(pieces, nextIndent .. ID_FIELD .. " = " .. tostring(id) .. ",\n")
        end

        for k, val in pairs(v) do
            if not (k == ID_FIELD) then
                local key_s
                local tk = type(k)
                if tk == "string" and is_ident(k) then
                    key_s = k .. " = "
                elseif tk == "string" then
                    key_s = "[" .. q(k) .. "] = "
                elseif tk == "number" or tk == "boolean" then
                    key_s = "[" .. tostring(k) .. "] = "
                elseif tk == "table" then
                    local kid = rawget(k, ID_FIELD)
                    if kid == nil then
                        error("Table used as key without '" .. ID_FIELD .. "'")
                    end
                    key_s = "[" .. tostring(kid) .. "] = "
                else
                    error("Unsupported key type: " .. tk)
                end

                local val_s = serialize_value(val, seen, nextIndent)
                if val_s ~= nil then
                    table.insert(pieces, nextIndent .. key_s .. val_s .. ",\n")
                end
            end
        end

        table.insert(pieces, indent .. "}")
        return table.concat(pieces)
    end

    local function serialize(root)
        local seen = {}
        return "return " .. (serialize_value(root, seen, "") or "nil")
    end

    return serialize
end

local serialize = make_serializer({
    id_field = "id",
    indent   = "  ",
})

return {
    make_serializer = make_serializer,
    serialize = serialize
}
