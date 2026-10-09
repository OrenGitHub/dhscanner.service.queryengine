:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_ssrf_nodejs_fetch( Call )
%
% The bare WHATWG `fetch(url, opts?)` global in Node.js 18+ / browsers.
% The parser instrumentation `instrumentNodejsFetchFn` in
% `TsParserActions.hs` pins this global to the FQN `nodejs.fetch` by
% prepending a synthetic `import { fetch } from 'nodejs'` to every TS
% file (mirrors the existing Request / Response / URL treatment).
%
% The explicit `import fetch from "node-fetch"` form resolves to the
% distinct FQN `node-fetch.fetch` via the regular 3rd-party import
% pipeline ; keep that as a separate clause here if / when the first
% real sink site uses it.
%
% First end-to-end sensor on formbricks v3.16.0 : the Slack OAuth
% callback endpoint `GET /api/v1/integrations/slack/callback`
% (`apps/web/app/api/v1/integrations/slack/callback/route.ts:42`)
% calls `fetch("https://slack.com/api/oauth.v2.access", {...})` --
% a hardcoded-URL outbound HTTP call that fits the SSRF SINK shape
% structurally (we do NOT taint-check the URL argument here, same
% way `sinks_ssrf_python_requests/1` matches every `requests.post`
% call regardless of URL argument).

sinks_ssrf_nodejs_fetch(Call) :-
    kb_call_resolved(Call, 'nodejs.fetch').
