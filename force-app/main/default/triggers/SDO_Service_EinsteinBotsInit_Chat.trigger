//This trigger is designed to help eliminate the need for pre-chat forms.
//This trigger can be used in combination with Snippet Settings code to associate new LiveChatTranscript records with the correct Contact and Account records.
//This trigger also creates a new Case for each new LiveChatTranscript session record created and associates it with the correct Contact record.
trigger SDO_Service_EinsteinBotsInit_Chat on LiveChatTranscript (before insert) {
    if(System.isBatch()) return;
    // Note that we can't move this to a Record Triggered Flow because the record seems to get locked when it is in the 'Waiting' state
    // by some underlying code (can't set the caseId field). Messaging Session and Voice have been moved to Flow though.
    for (LiveChatTranscript lct : Trigger.New){
        String caseSubject = 'Support Chat Conversation';
        if(lct.ChatEndUserId__c != null) {
            List<User> thisUser = [SELECT Id, ContactId FROM User WHERE Id = :lct.ChatEndUserId__c];
            if(thisUser.size() > 0){
                lct.ContactId = thisUser[0].ContactId;
                List<Contact> thisContact = [SELECT Id, Name, AccountId FROM Contact WHERE Id = :lct.ContactId];
                if(thisContact.size() > 0) 
                {
                    lct.AccountId = thisContact[0].AccountId;
                    caseSubject += ' with ' + thisContact[0].Name;
                }   
            }

        }
        // Create a case every time as a catch-all - this prevents errors in the bot and matches how Messaging Sessions behave in the SDO.
        if(lct.CaseId == null) {
            Case newCase = new Case();
            newCase.subject = caseSubject;
            newCase.Origin = 'Chat';
            newCase.contactId = lct.ContactId;
            newCase.accountId = lct.AccountId;
            try {
                insert newCase;
                lct.CaseId = newCase.Id;
            } catch(dmlexception e){
                system.debug('Case creation error: ' + e);
            }
        }  
    }
}