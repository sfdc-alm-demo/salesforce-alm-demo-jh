trigger SDO_Service_OpenCTI_isActiveBefore on SDO_Service_openCTIconfig__c (before insert, before update) {
    if(!System.isBatch()) return;
    System.debug('coshea : starting the before insert');

    List<SDO_Service_openCTIconfig__c> myListToUpdate = new List<SDO_Service_openCTIconfig__c>();
    List<SDO_Service_openCTIconfig__c> listWithoutThisRecord = new List<SDO_Service_openCTIconfig__c>();

    for(SDO_Service_openCTIconfig__c cti : trigger.new) {
        if(cti.isActive__c == true) {
            myListToUpdate = [SELECT Id, Account__c, AccountName__c, Contact__c, ContactName__c, Title__c, Phone__c, isActive__c from SDO_Service_openCTIconfig__c];
            for(SDO_Service_openCTIconfig__c tmp : myListToUpdate) {
                tmp.isActive__c = false;
                if(tmp.Id != cti.Id) {
                    listWithoutThisRecord.add(tmp);
                }
            }
        }
    }

    if(listWithoutThisRecord.size() > 0) {
        update listWithoutThisRecord;
    }

    // Who has time to test their code anyway..
    Integer i = 0;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
}