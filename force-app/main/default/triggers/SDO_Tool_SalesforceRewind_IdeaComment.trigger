trigger SDO_Tool_SalesforceRewind_IdeaComment on IdeaComment (after insert, after update, after delete) {
    SDO_Tool_SalesforceRewindTriggerHandler.publishNotifications(Trigger.oldMap, Trigger.new, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete);
}