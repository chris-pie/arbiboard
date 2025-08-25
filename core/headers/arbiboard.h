#ifndef ARBIBOARD_LIBRARY_H
#define ARBIBOARD_LIBRARY_H

#include <stdlib.h>
#include "vc_vector.h"

typedef struct string_sized {
    char *str;
    size_t len;
}
string_sized;

typedef struct board_internal_state board_internal_state;
typedef string_sized board_response;

typedef struct board_state {
    board_internal_state *state;
    board_response *response;
    char* error;
    vc_vector* request_history;
    vc_vector* response_history;

} board_state;

typedef struct query_response {
    bool success;
    char* request;
    char* response;
} query_response;

board_state init_game(const char *rules_script, const char *api_script, const char* init_request, bool history);

bool make_move(board_state *board, const char *move);

void destroy_board(board_state board);

vc_vector* query(board_state* board, int query_number, char** queries);

#endif //ARBIBOARD_LIBRARY_H
