:- style_check(-singleton).

% Not every KB carries these facts ( non-java KBs ), so declare them
% here to keep calls to them failing quietly rather than raising.

:- dynamic kb_param_has_resolved_type/2.

% -----------------------------------------------------------------------------
% endpoints_user_input_servlet( Call )
%
% `request.getParameter( name )` where `request` is a param of the
% enclosing callable, typed `HttpServletRequest`. Covers handlers that
% are not spring routes, eg spring security login filters :
%
%   private void redirectAfterSuccess(HttpServletRequest request, ...) {
%       String redirectUrl = request.getParameter("redirectUrl");
%
% ( DSpace 10.1 `OidcLoginFilter`, `OrcidLoginFilter`,
% `ShibbolethLoginFilter` ). The param flows into the callee
% `request.getParameter`, which flows into the call.

endpoints_user_input_servlet(Call) :-
    endpoints_request_type_servlet(Type),
    kb_param_has_resolved_type(Param, Type),
    kb_param_i_of_callable(Param, _, Callable),
    kb_dataflow_edge(Param, Callee),
    kb_dataflow_edge(Callee, Call),
    kb_called_from(Call, Callable),
    atom_concat(Type, '.getParameter', Fqn),
    kb_call_resolved(Call, Fqn).

endpoints_request_type_servlet('jakarta.servlet.http.HttpServletRequest').
endpoints_request_type_servlet('javax.servlet.http.HttpServletRequest').
