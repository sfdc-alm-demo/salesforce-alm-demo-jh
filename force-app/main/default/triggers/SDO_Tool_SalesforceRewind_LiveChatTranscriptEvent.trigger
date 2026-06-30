trigger SDO_Tool_SalesforceRewind_LiveChatTranscriptEvent on LiveChatTranscriptEvent (after insert, after update, after delete) {
    SDO_Tool_SalesforceRewindTriggerHandler.publishNotifications(Trigger.oldMap, Trigger.new, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete);
}