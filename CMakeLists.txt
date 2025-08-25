cmake_minimum_required(VERSION 3.28)
project(arbiboard C)

set(CMAKE_C_STANDARD 23)

include_directories(core/headers)

add_library(lualib OBJECT lib/lua-5.4.7/src/lapi.c lib/lua-5.4.7/src/lauxlib.c lib/lua-5.4.7/src/lbaselib.c lib/lua-5.4.7/src/lcode.c lib/lua-5.4.7/src/lcorolib.c lib/lua-5.4.7/src/lctype.c lib/lua-5.4.7/src/ldblib.c lib/lua-5.4.7/src/ldebug.c lib/lua-5.4.7/src/ldo.c lib/lua-5.4.7/src/ldump.c lib/lua-5.4.7/src/lfunc.c lib/lua-5.4.7/src/lgc.c lib/lua-5.4.7/src/linit.c lib/lua-5.4.7/src/liolib.c lib/lua-5.4.7/src/llex.c lib/lua-5.4.7/src/lmathlib.c lib/lua-5.4.7/src/lmem.c lib/lua-5.4.7/src/loadlib.c lib/lua-5.4.7/src/lobject.c lib/lua-5.4.7/src/lopcodes.c lib/lua-5.4.7/src/loslib.c lib/lua-5.4.7/src/lparser.c lib/lua-5.4.7/src/lstate.c lib/lua-5.4.7/src/lstring.c lib/lua-5.4.7/src/lstrlib.c lib/lua-5.4.7/src/ltable.c lib/lua-5.4.7/src/ltablib.c lib/lua-5.4.7/src/ltm.c lib/lua-5.4.7/src/lundump.c lib/lua-5.4.7/src/lutf8lib.c lib/lua-5.4.7/src/lvm.c lib/lua-5.4.7/src/lzio.c)
add_library(vc_vector OBJECT lib/vc_vector/vc_vector.c)
set(LUA_BASE_SCRIPT ${CMAKE_SOURCE_DIR}/core/base.lua)
set(LUA_BASE_SCRIPT_STRING ${CMAKE_SOURCE_DIR}/core/base_lua_string.txt)

add_custom_command(
        OUTPUT ${LUA_BASE_SCRIPT_STRING}
        COMMAND py ${CMAKE_SOURCE_DIR}/lua_to_c_string.py ${LUA_BASE_SCRIPT} ${LUA_BASE_SCRIPT_STRING}
        DEPENDS ${LUA_BASE_SCRIPT} lua_to_c_string.py
        COMMENT "Converting Lua script to C string literal..."
        VERBATIM
)

add_custom_target(ConvertLuaToCString ALL
        DEPENDS ${LUA_BASE_SCRIPT_STRING}
)

add_library(arbiboard OBJECT core/arbiboard.c)

add_dependencies(arbiboard ConvertLuaToCString)

target_include_directories(arbiboard PRIVATE lib/lua-5.4.7/src)
target_include_directories(arbiboard PRIVATE lib/vc_vector)

add_executable(debugdemon daemons/debug/debugdemon.c $<TARGET_OBJECTS:arbiboard> $<TARGET_OBJECTS:lualib> $<TARGET_OBJECTS:vc_vector>)
