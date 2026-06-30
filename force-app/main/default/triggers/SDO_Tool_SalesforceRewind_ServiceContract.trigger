trigger SDO_Tool_SalesforceRewind_ServiceContract on ServiceContract (after insert, after update, after delete) {
    if(System.isBatch()) return;
    SDO_Tool_SalesforceRewindTriggerHandler.publishNotifications(Trigger.oldMap, Trigger.new, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete);
}