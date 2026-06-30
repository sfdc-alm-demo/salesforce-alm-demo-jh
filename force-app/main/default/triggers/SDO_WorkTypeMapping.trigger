//This Trigger helps get around the limitations of Salesforce UPSERT in the prescence of duplicate record type names present in the SFS package

trigger SDO_WorkTypeMapping on FSL__Work_Rule__c (before insert, before update) {

    String sobjectType = 'FSL__Work_Rule__c';
    // Query for all record types for the sObject we are working with
    List<RecordType> recordTypes = [
        SELECT Id, Name
        FROM RecordType
        WHERE sObjectType = :sobjectType
    ];

    if(Trigger.isBefore){
        // Define a map to hold the relationship between record type names and their IDs
        Map<String, Id> recordTypeNameToIdMap = new Map<String, Id>();
        // Populate the record type name to ID map with data from the query
        for(RecordType rt: recordTypes){
            recordTypeNameToIdMap.put(rt.Name, rt.Id);
        }

        for(FSL__Work_Rule__c obj: Trigger.new){
            // Validates that the Record_Type__c field has a value as well as an External ID for Data Tool Operations
            if(null != obj.Record_Type__c && obj.Record_Type__c != ''&& obj.External_Id__c != ''){
                if(obj.Id == null || Trigger.oldMap.get(obj.Id).Record_Type__c != obj.Record_Type__c){
                    // Set the record type ID to the appropriate value in the record type name to ID map
                    obj.RecordTypeId = recordTypeNameToIdMap.get(obj.Record_Type__c);
                }
            }
        }
    }
}