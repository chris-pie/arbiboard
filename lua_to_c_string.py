import sys

def lua_to_c_string_literal(lua_filename, c_filename):
    with open(lua_filename, 'r') as lua_file:
        lua_script = lua_file.read()

    c_string_literal = '"'
    for char in lua_script:
        if char == '\n':
            c_string_literal += '\\n"\n"'
        elif char == '\r':
            c_string_literal += '\\r'
        elif char == '\t':
            c_string_literal += '\\t'
        elif char == '"':
            c_string_literal += '\\"'
        elif char == '\\':
            c_string_literal += '\\\\'
        else:
            c_string_literal += char
    c_string_literal += '"'

    with open(c_filename, 'w') as c_file:
        c_file.write(c_string_literal)

    print(f"Converted Lua script from {lua_filename} to C string literal in {c_filename}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python lua_to_c_string.py <input_lua_script> <output_c_string_literal>")
        sys.exit(1)

    lua_filename = sys.argv[1]
    c_filename = sys.argv[2]
    lua_to_c_string_literal(lua_filename, c_filename)
