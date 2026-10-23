:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sanitizers_error_call_java_servlet( Call )
%
% `HttpServletResponse.sendError( status [, message] )` answers the
% request with an error status. Jakarta ( servlet 5+ ) and javax.
%
% DSpace 10.1 `OidcRestController.oidc` rejects a redirect url outside
% the allowed hosts with :
%
%   response.sendError(HttpServletResponse.SC_BAD_REQUEST,
%                      "Invalid redirectURL! Must match server or ui hostname.");

sanitizers_error_call_java_servlet(Call) :-
    kb_call_resolved(Call, 'jakarta.servlet.http.HttpServletResponse.sendError').
sanitizers_error_call_java_servlet(Call) :-
    kb_call_resolved(Call, 'javax.servlet.http.HttpServletResponse.sendError').
