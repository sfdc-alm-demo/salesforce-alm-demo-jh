trigger SDO_Tool_SalesforceRewind_Task on Task (after insert, after update, after delete) {
    if(System.isBatch()) return;
    SDO_Tool_SalesforceRewindTriggerHandler.publishNotifications(Trigger.oldMap, Trigger.new, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete); 
}