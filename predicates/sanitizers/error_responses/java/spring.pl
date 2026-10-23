:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sanitizers_error_call_java_spring( Call )
%
% Spring ( spring-web ) ways of rejecting a request :
%
%   return ResponseEntity.badRequest().build();
%   return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
%   throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "...");
%
% A constructor call resolves to its class fqn ( eg `new ArrayList<>()`
% resolves to 'java.util.ArrayList' ), so the exception case matches on
% the class itself. `throw` is not lowered, but the constructor call it
% throws is.

sanitizers_error_call_java_spring(Call) :-
    kb_call_resolved(Call, Fqn),
    sanitizers_error_fqn_java_spring(Fqn).

sanitizers_error_fqn_java_spring('org.springframework.http.ResponseEntity.badRequest').
sanitizers_error_fqn_java_spring('org.springframework.http.ResponseEntity.notFound').
sanitizers_error_fqn_java_spring('org.springframework.http.ResponseEntity.unprocessableEntity').
sanitizers_error_fqn_java_spring('org.springframework.http.ResponseEntity.status').
sanitizers_error_fqn_java_spring('org.springframework.web.server.ResponseStatusException').
