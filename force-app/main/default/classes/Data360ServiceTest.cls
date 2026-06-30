@IsTest
private class Data360ServiceTest {

    private static final String SAMPLE_TOP =
        '{"data":[{"accountId":"001Hu00003xevLDIAY","accountName":"Elevate Education Group","totalRevenue":707444,"orderCount":10,"avgLineValue":30013.52,"lastOrderDate":"2025-12-17T00:00:00+00:00"}],"done":true}';

    private static final String SAMPLE_FAMILY =
        '{"data":[{"family":"Solar Panels","orderCount":68,"units":529,"revenue":969665,"accountReach":25}],"done":true}';

    private static final String EMPTY_BODY = '{"data":[],"done":true}';

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

    @IsTest static void getTopAccountRevenue_parsesPayload() {
        Test.setMock(HttpCalloutMock.class, new FakeHttp(SAMPLE_TOP));
        Test.startTest();
        List<Data360Service.AccountRevenueSummary> rows = Data360Service.getTopAccountRevenue(5);
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('Elevate Education Group', rows[0].accountName);
        System.assertEquals(707444, rows[0].totalRevenue);
        System.assertEquals(10, rows[0].orderCount);
    }

    @IsTest static void getAccountRevenueSummary_returnsNullForBlankId() {
        Test.startTest();
        Data360Service.AccountRevenueSummary s = Data360Service.getAccountRevenueSummary(null);
        Test.stopTest();
        System.assertEquals(null, s);
    }

    @IsTest static void getAccountRevenueSummary_returnsNullForEmptyData() {
        Test.setMock(HttpCalloutMock.class, new FakeHttp(EMPTY_BODY));
        Test.startTest();
        Data360Service.AccountRevenueSummary s = Data360Service.getAccountRevenueSummary('001000000000001');
        Test.stopTest();
        System.assertEquals(null, s);
    }

    @IsTest static void getProductFamilyPerformance_parses() {
        Test.setMock(HttpCalloutMock.class, new FakeHttp(SAMPLE_FAMILY));
        Test.startTest();
        List<Data360Service.ProductFamilyPerformance> fams = Data360Service.getProductFamilyPerformance(10);
        Test.stopTest();
        System.assertEquals(1, fams.size());
        System.assertEquals('Solar Panels', fams[0].family);
        System.assertEquals(969665, fams[0].revenue);
    }

    @IsTest static void getAccountEngagementScore_buildsRfm() {
        Test.setMock(HttpCalloutMock.class, new FakeHttp(SAMPLE_TOP));
        Test.startTest();
        Data360Service.AccountEngagementScore e = Data360Service.getAccountEngagementScore('001Hu00003xevLDIAY');
        Test.stopTest();
        System.assertNotEquals(null, e);
        System.assertEquals(10, e.orderCount);
        System.assertNotEquals(null, e.rfmScore);
        System.assert(e.rfmScore >= 0 && e.rfmScore <= 100, 'RFM score should be 0-100, got ' + e.rfmScore);
    }

    @IsTest static void getAccountBriefing_aggregates() {
        // Single mock that returns family payload regardless of which call comes through;
        // briefing makes 3 callouts (revenue, engagement[reuses revenue], families) — accept
        // family-shaped data for all to keep the test simple.
        Test.setMock(HttpCalloutMock.class, new FakeHttp(SAMPLE_TOP));
        Test.startTest();
        Data360Service.AccountBriefing b = Data360Service.getAccountBriefing('001Hu00003xevLDIAY');
        Test.stopTest();
        System.assertNotEquals(null, b);
        System.assertNotEquals(null, b.revenue);
    }

    @IsTest static void httpError_throws() {
        FakeHttp fake = new FakeHttp('{"errorCode":"BAD"}');
        fake.status = 400;
        Test.setMock(HttpCalloutMock.class, fake);
        Boolean threw = false;
        Test.startTest();
        try {
            Data360Service.getTopAccountRevenue(5);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should have thrown on non-2xx response');
    }

    @IsTest static void invocableEntrypoint_works() {
        Test.setMock(HttpCalloutMock.class, new FakeHttp(SAMPLE_TOP));
        Data360Service.BriefingRequest req = new Data360Service.BriefingRequest();
        req.accountId = '001Hu00003xevLDIAY';
        Test.startTest();
        List<Data360Service.BriefingResponse> resps = Data360Service.getAccountBriefingInvocable(new List<Data360Service.BriefingRequest>{ req });
        Test.stopTest();
        System.assertEquals(1, resps.size());
        System.assertNotEquals(null, resps[0].briefing);
        System.assertNotEquals(null, resps[0].summary);
    }
}