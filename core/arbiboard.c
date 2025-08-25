#include "headers/arbiboard.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>

#define INIT_RESPONSE_LENGTH 1024

void deleter(void* data) {
    free(*(char**) data);
}


struct board_internal_state {
    lua_State *L;
    bool keep_history;
    vc_vector* query_responses;
    int move_number;
};


void copy_message(string_sized* response, lua_State* L, vc_vector* history) {
    size_t response_len = 0;
    const char* response_new= lua_tolstring(L, -1, &response_len);
    if (response_len > response->len) {
        response->str = realloc(response, response_len + 1);
        response->len = response_len;
    }
    strcpy_s(response->str, response_len+1, response_new);
    if(history) {
        char* response_copy = malloc(response_len + 1);
        strcpy(response_copy, response_new);
        vc_vector_append(history, &response_copy, 1);
    }
    lua_pop(L, 1);
}


void destroy_board(const board_state board) {
    lua_close(board.state->L);
    vc_vector_release(board.state->query_responses);
    if (board.state->keep_history) {
        vc_vector_release(board.request_history);
        vc_vector_release(board.response_history);
    }
    free(board.state);
    free(board.response->str);
    free(board.response);
    free(board.error);
}



void panic(board_state* board, const char* error, const bool include_lua_err) {
    const size_t error_len = strlen(error);
    if (include_lua_err && board->state != NULL && board->state->L != NULL) {
        size_t lua_error_len = 1;
        const char *lua_error = lua_tolstring(board->state->L, -1, &lua_error_len);
        board->error = malloc(error_len + lua_error_len + 1);
        if (board->error) {
            strcpy(board->error, error);
            strcat(board->error, lua_error);
        }
    }
    else {
        board->error = malloc( error_len + 1);
        strcpy(board->error, error);
    }
}

board_state init_game(const char *rules_script, const char *api_script, const char* init_request, const bool history) {
    lua_State *L = luaL_newstate();
    if (L == NULL) {
        board_state board = {NULL, NULL, NULL};
        panic(&board, "ERROR FROM ARBIBOARD: Error allocating Lua state", false);
        return board;
    }

    luaL_requiref(L, LUA_GNAME, luaopen_base, 1);
    luaL_requiref(L, LUA_TABLIBNAME, luaopen_table, 1);
    luaL_requiref(L, LUA_STRLIBNAME, luaopen_string, 1);
    luaL_requiref(L, LUA_MATHLIBNAME, luaopen_math, 1);
    luaL_requiref(L, LUA_UTF8LIBNAME, luaopen_utf8, 1);
    lua_pop(L, 5);
    board_internal_state *board_internal = malloc(sizeof(board_internal_state));
    board_response* response = malloc(sizeof(board_response));
    response->len = INIT_RESPONSE_LENGTH;
    response->str = malloc(INIT_RESPONSE_LENGTH);
    board_state board =  {board_internal, response, NULL};
    board.state->L = L;
    board.state->keep_history = history;
    board.state->query_responses = vc_vector_create(0, sizeof(query_response), NULL);
    if(history) {
        board.request_history = vc_vector_create(0, sizeof(char*), deleter);
        board.response_history = vc_vector_create(0, sizeof(char*), deleter);
        char* request_copy = malloc( strlen(init_request) + 1);
        strcpy(request_copy, init_request);
        vc_vector_append(board.request_history, &request_copy, 1);
    }
    else {
        board.request_history = NULL;
        board.response_history = NULL;
    }

    const char* base_script =
#include "base_lua_string.txt"
        ;


    if (luaL_dostring(L, rules_script) != LUA_OK) {
        panic(&board, "ERROR FROM ARBIBOARD: Error while loading rules script: ", true);
        return board;
    }
    lua_getglobal(L, "API");

    if (!lua_isnil(L, -1)) {
        panic(&board, "ERROR FROM ARBIBOARD: Rules script is not allowed to define name \"API\"", false);
        return board;
    }

    lua_getglobal(L, "BASE_ARBIBOARD");

    if (!lua_isnil(L, -1)) {
        panic(&board, "ERROR FROM ARBIBOARD: Rules script is not allowed to define name \"BASE_ARBIBOARD\"", false);
        return board;
    }

    lua_pop(L, 2);

    if (luaL_dostring(L, api_script) != LUA_OK) {

        panic(&board, "ERROR FROM ARBIBOARD: Error while loading api script: ", true);
        return board;
    }

    lua_getglobal(L, "BASE_ARBIBOARD");

    if (!lua_isnil(L, -1)) {
        panic(&board, "ERROR FROM ARBIBOARD: API script is not allowed to define name \"BASE_ARBIBOARD\"", false);
        return board;
    }


    lua_getglobal(L, "API");

    if (!lua_istable(L, -1)) {
        panic(&board, "ERROR FROM ARBIBOARD: API table is not defined in the script", false);
        return board;
    }

    lua_getfield(L, -1, "move");
    if (!lua_isfunction(L, -1)) {
        panic(&board, "ERROR FROM ARBIBOARD: API.move function is not defined in the script", false);
        return board;
    }

    lua_getfield(L, -2, "init");
    if (!lua_isfunction(L, -1)) {
        panic(&board, "ERROR FROM ARBIBOARD: API.init function is not defined in the script", false);
        return board;
    }
    lua_pop(L, 4);


    if (luaL_dostring(L, base_script) != LUA_OK) {

        panic(&board, "ERROR FROM ARBIBOARD: Error while loading base script: ", true);
        return board;
    }
    if (init_request != NULL) {
        lua_getglobal(L, "BASE_ARBIBOARD");
        lua_getfield(L, -1, "init");
        lua_pushstring(L, init_request);
        lua_pushboolean(L, history);

        if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
            panic(&board, "ERROR FROM ARBIBOARD: Error while initializing board: ", true);
            return board;
        }
        copy_message(board.response, L, board.response_history);

        lua_pop(L, 1);
    }
    return board;

}

bool make_move(board_state* board, const char *move) {
    if (board->state->keep_history) {
        char* request_copy = malloc( strlen(move) + 1);
        strcpy(request_copy, move);
        vc_vector_append(board->request_history, &request_copy, 1);
    }
    lua_State *L = board->state->L;

    lua_getglobal(L, "BASE_ARBIBOARD");
    lua_getfield(L, -1, "move");
    lua_pushstring(L, move);
    if (lua_pcall(L, 1, 2, 0) != LUA_OK) {
        panic(board, "ERROR FROM ARBIBOARD: Error while making a move: ", true);
        return false;
    }
    copy_message(board->response, L, board->response_history);
    const int result = lua_toboolean(L, -1);
    lua_pop(L, 2);
    return result;
}

vc_vector* query(board_state* board, int query_number, char** queries) {
    vc_vector_clear(board->state->query_responses);
    lua_State *L = board->state->L;
    lua_getglobal(L, "BASE_ARBIBOARD");
    lua_getfield(L, -1, "query");
    lua_newtable(L);
    for(int i = 0; i<query_number; i++) {
        lua_pushstring(L, queries[i]);
        lua_rawseti(L, -2, i + 1);
    }
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        panic(board, "ERROR FROM ARBIBOARD: Error while making a query: ", true);
        return NULL;
    }
    for(int i = 0; i<query_number; i++) {
        lua_geti(L, -1, i + 1);
        lua_getfield(L, -1, "message");
        lua_getfield(L, -2, "request");
        lua_getfield(L, -3, "success");
        query_response response;
        response.success = lua_toboolean(L, -1);
        size_t stringlen;
        const char* respstring = lua_tolstring(L, -2, &stringlen);
        char* savestring = malloc(stringlen + 1);
        strcpy_s(savestring, stringlen + 1, respstring);
        response.request = savestring;
        respstring = lua_tolstring(L, -3, &stringlen);
        savestring = malloc(stringlen + 1);
        strcpy_s(savestring, stringlen + 1, respstring);
        response.response = savestring;
        vc_vector_append(board->state->query_responses, &response, 1);
        lua_pop(L, 4);
        if(!response.success) {
            break;
        }
    }
    lua_pop(L, 2);
    return board->state->query_responses;
}
