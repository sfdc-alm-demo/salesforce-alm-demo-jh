public class TestHeroku {
    public static void go() {
        herokuapplink.HerokuCaseRanker svc = new herokuapplink.HerokuCaseRanker();
        
        // Create the body
        herokuapplink.HerokuCaseRanker_getSimilarCasesForAgent_IN_body body = 
            new herokuapplink.HerokuCaseRanker_getSimilarCasesForAgent_IN_body();
        body.subject = 'Login issue';
        body.description = 'Cannot login';
        
        // Wrap it in a Request
        herokuapplink.HerokuCaseRanker.getSimilarCasesForAgent_Request req = 
            new herokuapplink.HerokuCaseRanker.getSimilarCasesForAgent_Request();
        req.body = body;
        
        // Call it
        herokuapplink.HerokuCaseRanker.getSimilarCasesForAgent_Response res = 
            svc.getSimilarCasesForAgent(req);
        
        System.debug('Response Code: ' + res.responseCode);
        System.debug('Results: ' + res.Code200);
    }
}