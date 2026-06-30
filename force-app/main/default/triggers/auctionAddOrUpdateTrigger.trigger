trigger auctionAddOrUpdateTrigger on SDO_SCOM_Auction__c (after insert, after update, after delete) {
    if (Trigger.isInsert && Trigger.isAfter) {
        // TODO: Create Schedule job to start and end
    } else if (Trigger.isUpdate && Trigger.isAfter) {
        // TODO: Update / Remove schedule if end / start date changes or auction closed
        // Add product to user cart on auction status closed
        System.debug('Auction Update Trigger');
        List<SDO_SCOM_Auction__c> oldAuctions = Trigger.old;
        List<SDO_SCOM_Auction__c> newAuctions = Trigger.new;
        Map<Id, SDO_SCOM_Auction__c> mappedOldAuctions = new Map<Id, SDO_SCOM_Auction__c>();
        mappedOldAuctions.putAll(oldAuctions);

        for(SDO_SCOM_Auction__c auction : newAuctions) {
            SDO_SCOM_Auction__c oldAuction = mappedOldAuctions.get(auction.Id);
            String oldStatus = oldAuction.get('Status__c').toString();
            String newStatus = auction.get('Status__c').toString();
            if(oldStatus != newStatus && newStatus == 'Closed') {
                System.debug('Auction marked as closed, triggering add to cart action');
                Sdo_Scom_Auction_Service.addAuctionProductToUserCart(auction.get('Id').toString());
            }
        }
    }
}