:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_open_redirect_nodejs_response_redirect( Call )
%
% The WHATWG `Response.redirect(url, status?)` static method is a global
% in Node.js 18+ / modern browsers and emits an HTTP 302/303 pointing
% the client at the given URL. When the URL argument is wholly or partly
% user-controlled, this is a textbook Open-Redirect sink ( CWE-601 ).
%
% The parser instrumentation `instrumentNodejsResponseType` in
% `TsParserActions.hs` already pins the `Response` global to the FQN
% prefix `nodejs.Response` by prepending a synthetic
% `import { Response } from 'nodejs'` to every TS file. The method
% access `Response.redirect` then naturally resolves through kbgen's
% fielded-access serialization ( `prologifyFieldedAccess` in
% `Kbgen.hs` ) to the atom `nodejs.Response.redirect` -- same shape
% as the already-established `nodejs.Response.json`
% ( see `predicates/auth/nodejs/native.pl` ) and
% `nodejs.Request.headers.get`
% ( see `tests/expected/facts/formbricks/auth_functions.txt` ).
%
% First end-to-end sensor on formbricks v3.16.0 : the Slack OAuth
% callback endpoint `GET /api/v1/integrations/slack/callback`
% ( `apps/web/app/api/v1/integrations/slack/callback/route.ts` )
% calls `Response.redirect(...)` TWICE in the same handler body :
%
%     line 81 : return Response.redirect(`${WEBAPP_URL}/environments/${environmentId}/integrations/slack`);
%     line 84 : return Response.redirect(`${WEBAPP_URL}/environments/${environmentId}/integrations/slack?error=${error}`);
%
% Both URLs interpolate the `environmentId` query-parameter ( + the
% `error` query-parameter on the second site ), so BOTH fit the
% Open-Redirect sink shape structurally. We do NOT taint-check the
% URL argument here -- same convention as `sinks_ssrf_nodejs_fetch/1`
% and `sinks_ssrf_python_requests/1` ; taint-checking is downstream
% work in `open_redirect/1` ( `utils.pl` ) which composes the sink
% with `dataflow_inter_path/3`.

sinks_open_redirect_nodejs_response_redirect(Call) :-
    kb_call_resolved(Call, 'nodejs.Response.redirect').
