trigger SDO_Service_OpenCTI_isActiveBeforeUpdate on SDO_Service_openCTIconfig__c (before update) {
    if(!System.isBatch()) return;
    System.debug('coshea : starting the before update');

    List<SDO_Service_openCTIconfig__c> myListToUpdate = new List<SDO_Service_openCTIconfig__c>();

    for(SDO_Service_openCTIconfig__c cti : trigger.new) {
        if(cti.isActive__c == true) {
            myListToUpdate = [SELECT Id, Account__c, AccountName__c, Contact__c, ContactName__c, Title__c, Phone__c, isActive__c from SDO_Service_openCTIconfig__c WHERE isActive__c=:true];
            for(SDO_Service_openCTIconfig__c tmp : myListToUpdate) {
                tmp.isActive__c = false;
            }
        }
    }

    if(myListToUpdate.size() > 0) {
        update myListToUpdate;
    }
}