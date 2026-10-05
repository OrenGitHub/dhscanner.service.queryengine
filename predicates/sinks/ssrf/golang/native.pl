:- style_check(-singleton).

sinks_http_request_golang(Call) :-
    kb_call_resolved(Call, 'net/http.Get').
