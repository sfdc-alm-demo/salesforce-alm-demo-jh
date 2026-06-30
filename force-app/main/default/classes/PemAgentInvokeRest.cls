@RestResource(urlMapping='/pem/agent-invoke')
global with sharing class PemAgentInvokeRest {

    private static final String AGENT_ID = '0XxHu000001lgcSKAQ';
    private static final String AGENT_API_BASE = 'https://api.salesforce.com/einstein/ai-agent/v1';

    global class Request {
        global String message;
        global String sessionId;
    }

    global class Result {
        global String sessionId;
        global String reply;
        global String planId;
        global Boolean isContentSafe;
        global String rawResponse;
    }

    @HttpPost
    global static void invoke() {
        try {
            Request req = (Request) PemRestUtil.readRequest(Request.class);
            if (String.isBlank(req.message)) {
                throw new PemAgentInvokeException('message is required');
            }
            String jwt = mintBootstrapJwt();
            String sessionId = String.isNotBlank(req.sessionId) ? req.sessionId : startSession(jwt);
            Map<String, Object> agentResp = sendMessage(jwt, sessionId, req.message);
            Result r = new Result();
            r.sessionId = sessionId;
            r.rawResponse = JSON.serialize(agentResp);
            List<Object> msgs = (List<Object>) agentResp.get('messages');
            if (msgs != null && !msgs.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>) msgs[0];
                r.reply = (String) first.get('message');
                r.planId = (String) first.get('planId');
                r.isContentSafe = (Boolean) first.get('isContentSafe');
            }
            PemRestUtil.writeResult(r);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }

    private static String mintBootstrapJwt() {
        HttpRequest r = new HttpRequest();
        r.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/agentforce/bootstrap/nameduser');
        r.setMethod('GET');
        r.setHeader('Cookie', 'sid=' + UserInfo.getSessionId());
        r.setHeader('Content-Type', 'application/json');
        r.setTimeout(60000);
        HttpResponse resp = new Http().send(r);
        if (resp.getStatusCode() != 200) {
            throw new PemAgentInvokeException(
                'Bootstrap failed: ' + resp.getStatusCode() + ' ' + resp.getBody()
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
        return (String) parsed.get('access_token');
    }

    private static String startSession(String jwt) {
        HttpRequest r = new HttpRequest();
        r.setEndpoint(AGENT_API_BASE + '/agents/' + AGENT_ID + '/sessions');
        r.setMethod('POST');
        r.setHeader('Authorization', 'Bearer ' + jwt);
        r.setHeader('Content-Type', 'application/json');
        r.setHeader('x-client-name', 'pem-mcp');
        r.setBody(JSON.serialize(new Map<String, Object>{
            'externalSessionKey' => 'pem-mcp-' + System.currentTimeMillis(),
            'instanceConfig' => new Map<String, Object>{
                'endpoint' => URL.getOrgDomainUrl().toExternalForm()
            },
            'streamingCapabilities' => new Map<String, Object>{
                'chunkTypes' => new List<String>{ 'Text', 'LightningChunk' }
            },
            'bypassUser' => false
        }));
        r.setTimeout(120000);
        HttpResponse resp = new Http().send(r);
        if (resp.getStatusCode() != 200) {
            throw new PemAgentInvokeException(
                'Session start failed: ' + resp.getStatusCode() + ' ' + resp.getBody()
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
        return (String) parsed.get('sessionId');
    }

    private static Map<String, Object> sendMessage(String jwt, String sessionId, String text) {
        HttpRequest r = new HttpRequest();
        r.setEndpoint(AGENT_API_BASE + '/sessions/' + sessionId + '/messages');
        r.setMethod('POST');
        r.setHeader('Authorization', 'Bearer ' + jwt);
        r.setHeader('Content-Type', 'application/json');
        r.setHeader('x-client-name', 'pem-mcp');
        r.setBody(JSON.serialize(new Map<String, Object>{
            'message' => new Map<String, Object>{
                'sequenceId' => System.currentTimeMillis(),
                'type' => 'Text',
                'text' => text
            },
            'variables' => new List<Object>()
        }));
        r.setTimeout(120000);
        HttpResponse resp = new Http().send(r);
        if (resp.getStatusCode() != 200) {
            throw new PemAgentInvokeException(
                'Send message failed: ' + resp.getStatusCode() + ' ' + resp.getBody()
            );
        }
        return (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
    }

    public class PemAgentInvokeException extends Exception {}
}