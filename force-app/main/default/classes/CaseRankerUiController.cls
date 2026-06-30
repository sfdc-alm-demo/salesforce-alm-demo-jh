public with sharing class CaseRankerUiController {
    public class SimilarCaseRow {
        @AuraEnabled public String caseId;
        @AuraEnabled public Integer rank;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String url;
    }

    public class SimilarCasesResponse {
        @AuraEnabled public String status;
        @AuraEnabled public Boolean degraded;
        @AuraEnabled public List<SimilarCaseRow> results;
    }

    @AuraEnabled(cacheable=false)
    public static SimilarCasesResponse getSimilarCasesForCase(Id caseId, Integer returnLimit) {
        if (returnLimit == null || returnLimit <= 0) returnLimit = 5;
        Case c = [
            SELECT Id, Subject, Description
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        herokuapplink.HerokuCaseRanker service = new herokuapplink.HerokuCaseRanker();

        herokuapplink.HerokuCaseRanker_getSimilarCasesForAgent_IN_body body =
            new herokuapplink.HerokuCaseRanker_getSimilarCasesForAgent_IN_body();
        body.subject = c.Subject;
        body.description = c.Description;

        herokuapplink.HerokuCaseRanker.getSimilarCasesForAgent_Request req =
            new herokuapplink.HerokuCaseRanker.getSimilarCasesForAgent_Request();
        req.body = body;

        herokuapplink.HerokuCaseRanker.getSimilarCasesForAgent_Response res =
            service.getSimilarCasesForAgent(req);

        SimilarCasesResponse out = new SimilarCasesResponse();
        out.status = 'ok';
        out.degraded = false;
        out.results = new List<SimilarCaseRow>();

        if (res == null || res.responseCode != 200 || res.Code200 == null || res.Code200.results == null) {
            out.status = 'error';
            out.degraded = true;
            return out;
        }

        out.degraded = res.Code200.degraded;

        for (herokuapplink.HerokuCaseRanker_getSimilarCasesForAgent_OUT_200_results r : res.Code200.results) {
            SimilarCaseRow row = new SimilarCaseRow();
            row.caseId = r.casex5fid;
            row.rank = r.rank;
            row.score = r.score;
            row.url = '/lightning/r/Case/' + r.casex5fid + '/view';
            out.results.add(row);
        }
        return out;
    }
}