trigger WorkOrderAfterInsert on WorkOrder (after insert) {
    SDO_SFS_WorkOrderTriggerHandler.handleAfterInsert(Trigger.new);
}