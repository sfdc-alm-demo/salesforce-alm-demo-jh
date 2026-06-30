trigger RevenueInsightTrigger on Revenue_Insight__c (after insert, after update) {
    RevenueInsightTriggerHandler.handle(Trigger.new, Trigger.oldMap);
}