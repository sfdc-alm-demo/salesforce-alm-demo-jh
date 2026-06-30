trigger OmsEventTrigger on OMS_Cancel_Event__e (after insert) {
    // List to hold all events to be created.
    List<OMS_Cancel_Context_Change__e> contextList = new List<OMS_Cancel_Context_Change__e>();
    System.debug('OmsEventTrigger running..');
    
    for (OMS_Cancel_Event__e event : Trigger.New) {
        // Create OMS_Cancel_Context_Change__e for each OMS_Cancel_Event__e
        OMS_Cancel_Context_Change__e secondEvent = new OMS_Cancel_Context_Change__e();
        secondEvent.Order_Item_Id__c = event.Order_Item_Id__c;
        secondEvent.Cancel_Reason__c = event.Cancel_Reason__c;
        secondEvent.Quantity__c = event.Quantity__c;
        secondEvent.Shipping_Reduction__c = event.Shipping_Reduction__c; 
        secondEvent.User_Name__c = event.User_Name__c;
        secondEvent.Recipient_Email__c  = event.Recipient_Email__c;
        System.debug('the email is ' + event.Recipient_Email__c);
            contextList.add(secondEvent);
        
    }
    
    // Call method to publish events
    List<Database.SaveResult> results = EventBus.publish(contextList);
    
    // Inspect publishing result for each event
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            System.debug('Successfully published event.');
        } else {
            for(Database.Error err : sr.getErrors()) {
                System.debug('Error returned: ' +
                             err.getStatusCode() +
                             ' - ' +
                             err.getMessage());
            }
        }      
    }
}