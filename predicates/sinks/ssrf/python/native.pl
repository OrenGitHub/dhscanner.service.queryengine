:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_ssrf_python( Call )
%
% Outgoing http requests from Python : `requests`, `httpx` ( and its fork
% `httpx2` ) and the stdlib `urllib.request.urlopen`.
%
%   module functions : `requests.get( url )`, `httpx2.post( url )`, ...
%   sessions / clients : `requests.Session().get( url )` resolves to
%     'requests.Session.get', `httpx.Client().get( url )` to
%     'httpx.Client.get'. A client kept in a variable or an attribute
%     resolves to `Unknown.get`, too generic to match on the method alone.
%
% Building a `urllib.request.Request` / `httpx.Request` is not a request,
% the `urlopen` / `send` that takes it is.
%
% First sensor on Weblate `0195e965e6` : `httpx2.get` 11, `httpx2.post` 4,
% `urllib.request.urlopen` 5, `requests.Session.get` 2 ( runner #129 ).
% Most of Weblate's outbound http goes through `weblate/utils/requests.py`
% ( `fetch_url` and friends ), which reaches the kb only once the parser
% handles its PEP 695 `bound` type params.
%
% No taint check here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_ssrf_python(Call) :-
    kb_call_resolved(Call, Fqn),
    python_ssrf_fqn(Fqn).

python_ssrf_fqn(Fqn) :-
    python_http_module(Module),
    python_http_verb(Verb),
    atomic_list_concat([Module, Verb], '.', Fqn).
python_ssrf_fqn(Fqn) :-
    python_http_client(Client),
    python_http_client_method(Method),
    atomic_list_concat([Client, Method], '.', Fqn).
python_ssrf_fqn('urllib.request.urlopen').

python_http_module('requests').
python_http_module('httpx').
python_http_module('httpx2').

python_http_client('requests.Session').
python_http_client('requests.session').
python_http_client('httpx.Client').
python_http_client('httpx.AsyncClient').
python_http_client('httpx2.Client').
python_http_client('httpx2.AsyncClient').

python_http_verb('get').
python_http_verb('post').
python_http_verb('put').
python_http_verb('patch').
python_http_verb('delete').
python_http_verb('head').
python_http_verb('options').
python_http_verb('request').
python_http_verb('stream').

python_http_client_method(Verb) :- python_http_verb(Verb).
python_http_client_method('send').
