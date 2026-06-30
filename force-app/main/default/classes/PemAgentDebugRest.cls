@RestResource(urlMapping='/pem/agent-debug')
global with sharing class PemAgentDebugRest {

    global class Result {
        global String bootstrapJwt;
        global String orgUrl;
        global String agentApiBase;
        global String agentId;
    }

    @HttpGet
    global static void mintBootstrap() {
        try {
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            HttpRequest r = new HttpRequest();
            r.setEndpoint(orgUrl + '/agentforce/bootstrap/nameduser');
            r.setMethod('GET');
            r.setHeader('Cookie', 'sid=' + UserInfo.getSessionId());
            r.setHeader('Content-Type', 'application/json');
            r.setTimeout(60000);
            HttpResponse resp = new Http().send(r);
            if (resp.getStatusCode() != 200) {
                throw new PemAgentDebugException(
                    'Bootstrap failed: ' + resp.getStatusCode() + ' ' + resp.getBody()
                );
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            Result out = new Result();
            out.bootstrapJwt = (String) parsed.get('access_token');
            out.orgUrl = orgUrl;
            out.agentApiBase = 'https://api.salesforce.com/einstein/ai-agent/v1';
            out.agentId = '0XxHu000001lgcSKAQ';
            PemRestUtil.writeResult(out);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }

    public class PemAgentDebugException extends Exception {}
}