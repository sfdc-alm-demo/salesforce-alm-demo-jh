public with sharing class CaseRankerAgentAction {
    public class Request {
        @InvocableVariable(required=true)
        public Id recordId;

        @InvocableVariable
        public Integer returnLimit;
    }

    public class Response {
        @InvocableVariable
        public String status;

        @InvocableVariable
        public Boolean degraded;

        @InvocableVariable
        public String markdown;
    }

    @InvocableMethod(
        label='Get Similar Cases (Case Ranker)'
        description='Calls the Heroku Case Ranker via App Link and returns ranked similar cases for the current Case.'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null || requests.isEmpty()) return out;

        for (Request r : requests) {
            Integer limitVal = (r.returnLimit == null || r.returnLimit <= 0) ? 5 : r.returnLimit;
            CaseRankerUiController.SimilarCasesResponse res =
                CaseRankerUiController.getSimilarCasesForCase(r.recordId, limitVal);

            Response x = new Response();
            x.status = res == null ? 'error' : res.status;
            x.degraded = res == null ? true : res.degraded;

            String md = '';
            md += '### Similar Cases\\n';
            if (x.degraded == true) {
                md += '_Fast mode: rerank unavailable (similarity-only)._\\n\\n';
            }
            if (res != null && res.results != null && !res.results.isEmpty()) {
                for (CaseRankerUiController.SimilarCaseRow row : res.results) {
                    Integer pct = row.score == null ? 0 : Integer.valueOf(Math.round(Double.valueOf(row.score) * 100));
                    md += row.rank + '. ' + row.caseId + ' — **' + pct + '%**  (' + row.url + ')\\n';
                }
            } else {
                md += '_No results returned._\\n';
            }
            x.markdown = md;
            out.add(x);
        }
        return out;
    }
}