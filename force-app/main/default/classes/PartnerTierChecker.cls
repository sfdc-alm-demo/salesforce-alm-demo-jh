public with sharing class PartnerTierChecker {

    @InvocableMethod(
        label='Check Partner Tier'
        description='Retrieves partner tier from the active ChannelProgramMember enrollment'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        Set<Id> partnerIds = new Set<Id>();
        for (Request req : requests) {
            if (String.isNotBlank(req.partnerId)) {
                partnerIds.add(req.partnerId);
            }
        }

        // Default to Summit Resellers (Silver tier) — chosen because progression scenario
        // shows meaningful percentage toward Gold rather than "you've reached the top"
        Id defaultPartnerId = null;
        if (partnerIds.isEmpty()) {
            List<Account> defaults = [
                SELECT Id FROM Account
                WHERE IsPartner = true AND Name = 'Summit Resellers'
                LIMIT 1
            ];
            if (defaults.isEmpty()) {
                // Fallback to first partner if Summit doesn't exist
                defaults = [SELECT Id FROM Account WHERE IsPartner = true ORDER BY Name ASC LIMIT 1];
            }
            if (!defaults.isEmpty()) {
                defaultPartnerId = defaults[0].Id;
                partnerIds.add(defaultPartnerId);
            }
        }

        Map<Id, Account> accountById = new Map<Id, Account>();
        Map<Id, ChannelProgramMember> enrollmentByPartner = new Map<Id, ChannelProgramMember>();

        if (!partnerIds.isEmpty()) {
            for (Account a : [
                SELECT Id, Name, ChannelProgramName, ChannelProgramLevelName
                FROM Account
                WHERE Id IN :partnerIds
            ]) {
                accountById.put(a.Id, a);
            }

            for (ChannelProgramMember m : [
                SELECT Id, PartnerId, Program.Name, Level.Name, CreatedDate
                FROM ChannelProgramMember
                WHERE PartnerId IN :partnerIds
                ORDER BY CreatedDate ASC
            ]) {
                if (!enrollmentByPartner.containsKey(m.PartnerId)) {
                    enrollmentByPartner.put(m.PartnerId, m);
                }
            }
        }

        for (Request req : requests) {
            Result r = new Result();
            Id pid = String.isNotBlank(req.partnerId) ? (Id) req.partnerId : defaultPartnerId;

            Account acct = (pid != null) ? accountById.get(pid) : null;
            ChannelProgramMember m = (pid != null) ? enrollmentByPartner.get(pid) : null;

            if (acct != null) {
                r.accountName = acct.Name;
                r.partnerTier = (m != null && m.Level != null) ? m.Level.Name
                              : (acct.ChannelProgramLevelName != null ? acct.ChannelProgramLevelName : 'Unenrolled');
                r.tierSince = (m != null) ? m.CreatedDate.date() : null;
                r.hasData = true;
            } else {
                r.accountName = 'Unknown Partner';
                r.partnerTier = 'Unenrolled';
                r.hasData = false;
            }

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable(
            label='Partner ID'
            description='Salesforce Account ID for the partner (must have IsPartner = true)'
        )
        public String partnerId;
    }

    public class Result {
        @InvocableVariable(label='Partner Tier')
        public String partnerTier;

        @InvocableVariable(label='Account Name')
        public String accountName;

        @InvocableVariable(label='Tier Since')
        public Date tierSince;

        @InvocableVariable(label='Has Data')
        public Boolean hasData;
    }
}