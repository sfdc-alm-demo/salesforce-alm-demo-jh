public with sharing class MdfBalanceChecker {

    @InvocableMethod(
        label='Check MDF Balance'
        description='Returns the partner total Marketing Development Fund (MDF) allocation, used and remaining balance for the current fiscal year'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        Set<Id> partnerIds = new Set<Id>();
        Id defaultPartnerId = null;
        for (Request req : requests) {
            if (String.isNotBlank(req.partnerId)) partnerIds.add(req.partnerId);
        }
        if (partnerIds.isEmpty()) {
            // Default to Summit Resellers (Silver) — matches the demo persona
            List<Account> defaults = [SELECT Id FROM Account WHERE IsPartner = true AND Name = 'Summit Resellers' LIMIT 1];
            if (defaults.isEmpty()) {
                defaults = [SELECT Id FROM Account WHERE IsPartner = true ORDER BY Name LIMIT 1];
            }
            if (!defaults.isEmpty()) {
                defaultPartnerId = defaults[0].Id;
                partnerIds.add(defaultPartnerId);
            }
        }

        // Sum allocations per partner
        Map<Id, Decimal> totalAllocByPartner = new Map<Id, Decimal>();
        Map<Id, String> allocTitleByPartner = new Map<Id, String>();

        if (!partnerIds.isEmpty()) {
            for (PartnerFundAllocation a : [
                SELECT Id, ChannelPartnerId, Amount, Title
                FROM PartnerFundAllocation
                WHERE ChannelPartnerId IN :partnerIds
                ORDER BY CreatedDate DESC
            ]) {
                Decimal current = totalAllocByPartner.get(a.ChannelPartnerId);
                totalAllocByPartner.put(a.ChannelPartnerId,
                    (current == null ? 0 : current) + (a.Amount == null ? 0 : a.Amount));
                if (!allocTitleByPartner.containsKey(a.ChannelPartnerId)) {
                    allocTitleByPartner.put(a.ChannelPartnerId, a.Title);
                }
            }

            // Sum approved/submitted requests per partner (these reduce remaining)
            Map<Id, Decimal> usedByPartner = new Map<Id, Decimal>();
            for (PartnerFundRequest r : [
                SELECT Id, ChannelPartnerId, RequestedAmount, Status
                FROM PartnerFundRequest
                WHERE ChannelPartnerId IN :partnerIds
                  AND Status IN ('Approved','Submitted')
            ]) {
                Decimal current = usedByPartner.get(r.ChannelPartnerId);
                usedByPartner.put(r.ChannelPartnerId,
                    (current == null ? 0 : current) + (r.RequestedAmount == null ? 0 : r.RequestedAmount));
            }

            for (Request req : requests) {
                Result res = new Result();
                Id pid = String.isNotBlank(req.partnerId) ? (Id) req.partnerId : defaultPartnerId;

                Decimal totalAlloc = totalAllocByPartner.get(pid);
                if (totalAlloc == null) totalAlloc = 0;
                Decimal used = usedByPartner.get(pid);
                if (used == null) used = 0;
                Decimal remaining = totalAlloc - used;

                res.totalAllocation = totalAlloc;
                res.usedAmount = used;
                res.remainingBalance = remaining;
                res.allocationTitle = allocTitleByPartner.get(pid);
                res.expirationNote = 'The expiration date for this balance is the end of the current fiscal year, December 31, 2026.';
                res.hasData = (totalAlloc > 0);

                results.add(res);
            }
        } else {
            for (Request req : requests) {
                Result res = new Result();
                res.totalAllocation = 0;
                res.usedAmount = 0;
                res.remainingBalance = 0;
                res.expirationNote = '';
                res.hasData = false;
                results.add(res);
            }
        }

        return results;
    }

    public class Request {
        @InvocableVariable
        public String partnerId;
    }

    public class Result {
        @InvocableVariable
        public Decimal totalAllocation;

        @InvocableVariable
        public Decimal usedAmount;

        @InvocableVariable
        public Decimal remainingBalance;

        @InvocableVariable
        public String allocationTitle;

        @InvocableVariable
        public String expirationNote;

        @InvocableVariable
        public Boolean hasData;
    }
}