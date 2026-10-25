:- style_check(-singleton).

% Not every KB carries these facts ( non-java KBs ), so declare them
% here to keep calls to them failing quietly rather than raising.

:- dynamic kb_param_has_resolved_type/2.
:- dynamic kb_callable_source_body_length/2.

% -----------------------------------------------------------------------------
% endpoints_http_servlet( Handler, Request )
%
% `Handler` takes the request as a param named `req` or `request`, typed
% `HttpServletRequest`, so a request reaches it. Its verb and url live
% elsewhere ( eg DSpace registers `new OidcLoginFilter( "/api/authn/oidc",
% HttpMethod.GET.name(), ... )` in WebSecurityConfiguration.java ), so
% `endpoints_http/4` reports it with verb `unknown` and url '{?}'.
% Abstract and interface methods ( no body ) are left out.

endpoints_http_servlet(Handler, Request) :-
    endpoints_request_type_servlet(Type),
    kb_param_has_resolved_type(Request, Type),
    kb_param_has_name(Request, Name),
    endpoints_request_name_servlet(Name),
    kb_param_i_of_callable(Request, _, Handler),
    kb_callable_source_body_length(Handler, Length),
    Length > 0.

endpoints_request_name_servlet(req).
endpoints_request_name_servlet(request).

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
