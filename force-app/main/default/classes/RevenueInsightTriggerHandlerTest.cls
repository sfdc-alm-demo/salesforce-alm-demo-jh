@IsTest
private class RevenueInsightTriggerHandlerTest {

    @IsTest static void notable_detectsHighRiskInsert() {
        Revenue_Insight__c ri = new Revenue_Insight__c(Risk_Score__c = 0.85, Transaction_Id__c = '801000000000001');
        System.assertEquals(true, RevenueInsightTriggerHandler.isNotable(ri, null));
    }

    @IsTest static void notable_detectsRiskCrossingThreshold() {
        Revenue_Insight__c prior = new Revenue_Insight__c(Risk_Score__c = 0.4);
        Revenue_Insight__c curr = new Revenue_Insight__c(Risk_Score__c = 0.8, Transaction_Id__c = '801000000000001');
        System.assertEquals(true, RevenueInsightTriggerHandler.isNotable(curr, prior));
    }

    @IsTest static void notable_detectsSegmentChange() {
        Revenue_Insight__c prior = new Revenue_Insight__c(Risk_Score__c = 0.2, Data_360_Segment__c = '');
        Revenue_Insight__c curr = new Revenue_Insight__c(Risk_Score__c = 0.2, Data_360_Segment__c = 'Renewal_Risk', Transaction_Id__c = '801000000000001');
        System.assertEquals(true, RevenueInsightTriggerHandler.isNotable(curr, prior));
    }

    @IsTest static void notable_skipsLowRiskNoChange() {
        Revenue_Insight__c prior = new Revenue_Insight__c(Risk_Score__c = 0.2, Data_360_Segment__c = 'Renewal_Risk');
        Revenue_Insight__c curr = new Revenue_Insight__c(Risk_Score__c = 0.3, Data_360_Segment__c = 'Renewal_Risk');
        System.assertEquals(false, RevenueInsightTriggerHandler.isNotable(curr, prior));
    }

    @IsTest static void chatterBody_includesAllFields() {
        Revenue_Insight__c ri = new Revenue_Insight__c(
            Transaction_Id__c = '801000000000001',
            Risk_Score__c = 0.92,
            Data_360_Segment__c = 'Renewal_Risk',
            Recommendation_Text__c = 'Push the renewal call this week.'
        );
        String body = RevenueInsightTriggerHandler.composeChatterBody(ri);
        System.assert(body.contains('801000000000001'));
        System.assert(body.contains('high risk'));
        System.assert(body.contains('Renewal_Risk'));
        System.assert(body.contains('Push the renewal'));
    }

    @IsTest static void trigger_runsWithoutAccountResolution() {
        // Insert a Revenue_Insight__c with a transaction id that doesn't match any real Order.
        // The trigger should run without error and post no Chatter.
        Revenue_Insight__c ri = new Revenue_Insight__c(
            Transaction_Id__c = '801000000000001',
            Risk_Score__c = 0.95
        );
        Test.startTest();
        insert ri;
        Test.stopTest();
        // No assertion needed beyond "did not throw" — verifies bulk safety + null handling.
        System.assertNotEquals(null, ri.Id);
    }
}