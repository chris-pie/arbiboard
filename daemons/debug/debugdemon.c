#include "debugdemon.h"

#include <stdio.h>

#include "arbiboard.h"
int main() {
    auto script =
#include "api_lua_string.txt"
        ;
    board_state state = init_game("", script, "zzzzzzzzzzzz", true);
    char** queries = malloc(2);
    queries[0] = "unga";
    queries[1] = "bunga";
    bool success = make_move(&state, "awooga123456789");
    vc_vector* response = query(&state, 2, queries);
    query_response* resp = vc_vector_at(response, 0);
    query_response* resp2 = vc_vector_at(response, 1);
    destroy_board(state);

}