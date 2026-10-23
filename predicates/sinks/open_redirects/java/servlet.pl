:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_open_redirect_java_servlet( Call )
%
% `HttpServletResponse.sendRedirect( location )` answers with a 302
% pointing the client at `location`. When `location` is wholly or partly
% user-controlled, this is a textbook Open-Redirect sink ( CWE-601 ).
% Both the jakarta ( servlet 5+ ) and the legacy javax namespaces are
% covered.
%
% First end-to-end sensor on DSpace 10.1 : `GET /api/authn/oidc`
% ( `OidcRestController.oidc` ) redirects to its `redirectUrl` request
% param - guarded by a host allow-list check, so a correct verdict needs
% the guard too ( see the `BranchGuardedCall` kbapi query ).
%
% Same convention as the other open-redirect sinks : no taint check
% here, dataflow is composed on top.

sinks_open_redirect_java_servlet(Call) :-
    kb_call_resolved(Call, 'jakarta.servlet.http.HttpServletResponse.sendRedirect').
sinks_open_redirect_java_servlet(Call) :-
    kb_call_resolved(Call, 'javax.servlet.http.HttpServletResponse.sendRedirect').
