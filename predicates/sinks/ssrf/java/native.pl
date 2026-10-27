:- style_check(-singleton).

% -----------------------------------------------------------------------------
% sinks_ssrf_java( Call )
%
% Outgoing http requests from Java : apache httpclient 4 / 5 request
% objects and `execute`, `java.net.http.HttpClient`, `java.net.URL`
% connections, spring `RestTemplate` / `WebClient` and commons-io
% `copyURLToFile`.
%
% For apache httpclient the request constructor ( `new HttpGet( url )` ) is
% where the url enters, so it is the sink. `execute` is listed too, for
% clients whose fqn resolves ( a 1st-party factory's `execute` resolves to
% the factory chain instead, the constructor still catches those ).
% Building a `java.net.URL` / `java.net.URI` is not a request.
%
% First end-to-end sensor on DSpace 10.1 : `OREIngestionCrosswalk` fetches
% `new HttpGet( processedURL )` at `:205`, the url taken from the ingested
% ORE document, behind `validResourceUri( processedURL )` ( runner #119 ).
%
% No taint check here, dataflow is composed on top.
% -----------------------------------------------------------------------------

sinks_ssrf_java(Call) :-
    kb_call_resolved(Call, Fqn),
    java_ssrf_fqn(Fqn).

java_ssrf_fqn('org.apache.http.client.methods.HttpGet').
java_ssrf_fqn('org.apache.http.client.methods.HttpPost').
java_ssrf_fqn('org.apache.http.client.methods.HttpPut').
java_ssrf_fqn('org.apache.http.client.methods.HttpPatch').
java_ssrf_fqn('org.apache.http.client.methods.HttpDelete').
java_ssrf_fqn('org.apache.http.client.methods.HttpHead').
java_ssrf_fqn('org.apache.http.client.methods.HttpOptions').
java_ssrf_fqn('org.apache.http.client.methods.HttpTrace').
java_ssrf_fqn('org.apache.http.client.HttpClient.execute').
java_ssrf_fqn('org.apache.http.impl.client.CloseableHttpClient.execute').
java_ssrf_fqn('org.apache.hc.client5.http.classic.methods.HttpGet').
java_ssrf_fqn('org.apache.hc.client5.http.classic.methods.HttpPost').
java_ssrf_fqn('org.apache.hc.client5.http.classic.methods.HttpPut').
java_ssrf_fqn('org.apache.hc.client5.http.classic.methods.HttpPatch').
java_ssrf_fqn('org.apache.hc.client5.http.classic.methods.HttpDelete').
java_ssrf_fqn('org.apache.hc.client5.http.classic.methods.HttpHead').
java_ssrf_fqn('org.apache.hc.client5.http.impl.classic.CloseableHttpClient.execute').
java_ssrf_fqn('java.net.http.HttpClient.send').
java_ssrf_fqn('java.net.http.HttpClient.sendAsync').
java_ssrf_fqn('java.net.URL.openConnection').
java_ssrf_fqn('java.net.URL.openStream').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.getForObject').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.getForEntity').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.postForObject').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.postForEntity').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.postForLocation').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.put').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.patchForObject').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.delete').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.exchange').
java_ssrf_fqn('org.springframework.web.client.RestTemplate.execute').
java_ssrf_fqn('org.springframework.web.reactive.function.client.WebClient.get').
java_ssrf_fqn('org.springframework.web.reactive.function.client.WebClient.post').
java_ssrf_fqn('org.springframework.web.reactive.function.client.WebClient.put').
java_ssrf_fqn('org.springframework.web.reactive.function.client.WebClient.patch').
java_ssrf_fqn('org.springframework.web.reactive.function.client.WebClient.delete').
java_ssrf_fqn('org.springframework.web.reactive.function.client.WebClient.method').
java_ssrf_fqn('org.apache.commons.io.FileUtils.copyURLToFile').
