:- style_check(-singleton).

% -----------------------------------------------------------------------------
% endpoints_user_input_echo( QueryParam )
%
% A value returned by `echo.Context.QueryParam(...)` inside the lambda
% registered with `echo.Group.GET(url, lambda)`. The lambda's first
% param is the `echo.Context` ; the KB intra-procedural dataflow
% witness ties that context to the `QueryParam` call site.

endpoints_user_input_echo(QueryParam) :-
    kb_call_resolved(Call, 'echo.Group.GET'),
    kb_param_has_resolved_type(Param, 'echo.Context'),
    kb_call_resolved(QueryParam, 'echo.Context.QueryParam'),
    kb_arg_i_for_call(Url, 0, Call),
    kb_const_string(Url, _),
    kb_arg_i_for_call(Lambda, 1, Call),
    kb_param_i_of_callable(Param, 0, Lambda),
    dataflow_intra_path(Param, QueryParam, _).
