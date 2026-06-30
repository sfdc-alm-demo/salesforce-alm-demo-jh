public with sharing class ChannelConflictChecker {

    @InvocableMethod(
        label='Check Channel Conflict'
        description='Searches for duplicate accounts and open opportunities to detect channel conflict before deal registration'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;
            r.conflictDetails = new List<ConflictDetail>();

            String company = (req.companyName == null) ? '' : req.companyName.trim();
            if (String.isBlank(company)) {
                r.conflictDetected = false;
                r.conflictReason = 'No company name provided.';
                r.autoApprovalEligible = false;
                results.add(r);
                continue;
            }

            // Use first significant word for fuzzy matching (handles "Datanet Inc" vs "Datanet, Inc.")
            String firstWord = company.split('[\\s,\\.]+')[0];
            String namePattern = '%' + company + '%';
            String firstWordPattern = '%' + firstWord + '%';
            String domain = (req.companyDomain == null) ? '' : req.companyDomain.trim().toLowerCase();
            String webLike = String.isNotBlank(domain) ? '%' + domain + '%' : 'NO_MATCH_SENTINEL_STRING';

            List<Account> matchingAccounts = [
                SELECT Id, Name, Website
                FROM Account
                WHERE (Name LIKE :namePattern OR Name LIKE :firstWordPattern OR Website LIKE :webLike)
                  AND IsPartner = false
                LIMIT 25
            ];

            if (matchingAccounts.isEmpty()) {
                r.conflictDetected = false;
                r.conflictReason = 'No existing accounts found matching "' + company + '". This deal can proceed without conflict.';
            } else {
                Set<Id> acctIds = new Map<Id, Account>(matchingAccounts).keySet();

                List<Opportunity> openOpps = [
                    SELECT Id, Name, Amount, StageName, Owner.Name, Account.Name
                    FROM Opportunity
                    WHERE AccountId IN :acctIds
                      AND IsClosed = false
                    ORDER BY Amount DESC NULLS LAST
                    LIMIT 5
                ];

                if (openOpps.isEmpty()) {
                    r.conflictDetected = false;
                    r.conflictReason = 'Found ' + matchingAccounts.size() + ' matching account(s) but no open opportunities. Deal can proceed.';
                } else {
                    r.conflictDetected = true;
                    for (Opportunity o : openOpps) {
                        ConflictDetail cd = new ConflictDetail();
                        cd.opportunityId = o.Id;
                        cd.accountName = (o.Account != null) ? o.Account.Name : 'Unknown';
                        cd.ownerName = (o.Owner != null) ? o.Owner.Name : 'Unassigned';
                        cd.stage = o.StageName;
                        cd.amount = (o.Amount == null) ? 0 : o.Amount;
                        r.conflictDetails.add(cd);
                    }
                    r.conflictReason = 'Found ' + openOpps.size() + ' open opportunit' +
                        (openOpps.size() == 1 ? 'y' : 'ies') +
                        ' for accounts matching "' + company + '". This deal must be escalated to a Channel Manager for review.';
                }
            }

            // Auto-approval rule: no conflict AND deal value < $50K
            r.autoApprovalEligible = (!r.conflictDetected && req.dealValue != null && req.dealValue < 50000);

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable(required=true)
        public String companyName;

        @InvocableVariable
        public String companyDomain;

        @InvocableVariable(required=true)
        public Decimal dealValue;
    }

    public class Result {
        @InvocableVariable
        public Boolean conflictDetected;

        @InvocableVariable
        public List<ConflictDetail> conflictDetails;

        @InvocableVariable
        public String conflictReason;

        @InvocableVariable
        public Boolean autoApprovalEligible;

        @InvocableVariable
        public Boolean hasData;
    }

    public class ConflictDetail {
        @InvocableVariable
        public String opportunityId;

        @InvocableVariable
        public String accountName;

        @InvocableVariable
        public String ownerName;

        @InvocableVariable
        public String stage;

        @InvocableVariable
        public Decimal amount;
    }
}