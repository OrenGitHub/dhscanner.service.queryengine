:- style_check(-singleton).

sinks_ssrf_python_requests(Call) :-
    kb_call_resolved(Call, 'requests.post').
