@IsTest
private class DailySegmentEnrichmentJobTest {

    private class FakeHttp implements HttpCalloutMock {
        public String body;
        public Integer status = 200;
        public FakeHttp(String body) { this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(status);
            r.setBody(body);
            r.setHeader('Content-Type', 'application/json');
            return r;
        }
    }

    @IsTest static void start_returnsStaleAccounts() {
        // 1000 days ago — well past 270-day cutoff
        String oldDate = Datetime.now().addDays(-1000).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String body = '{"data":[' +
            '{"accountId":"001000000000001","orders":3,"lastOrder":"' + oldDate + '"},' +
            '{"accountId":"001000000000002","orders":2,"lastOrder":"' + Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"}' +
            '],"done":true}';
        Test.setMock(HttpCalloutMock.class, new FakeHttp(body));

        Test.startTest();
        Set<Id> ids = DailySegmentEnrichmentJob.loadRenewalRiskAccounts();
        Test.stopTest();

        System.assertEquals(1, ids.size(), 'Only the stale account should be returned');
        System.assert(ids.contains('001000000000001'));
    }

    @IsTest static void schedulable_kicksOffBatch() {
        Test.setMock(HttpCalloutMock.class, new FakeHttp('{"data":[],"done":true}'));
        Test.startTest();
        new DailySegmentEnrichmentJob().execute((SchedulableContext) null);
        Test.stopTest();
        // No assertion beyond "did not throw" — Database.executeBatch with no rows is a no-op.
    }
}