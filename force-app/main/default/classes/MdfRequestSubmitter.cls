public with sharing class MdfRequestSubmitter {

    @InvocableMethod(
        label='Submit MDF Request'
        description='Submits a Marketing Development Fund (MDF) request against the partner active fund allocation. Returns the new request ID and updated remaining balance.'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        // Resolve default partner (Summit Resellers) if blank
        Id defaultPartnerId = null;
        for (Request req : requests) {
            if (String.isBlank(req.partnerId)) {
                if (defaultPartnerId == null) {
                    List<Account> defaults = [SELECT Id FROM Account WHERE IsPartner = true AND Name = 'Summit Resellers' LIMIT 1];
                    if (defaults.isEmpty()) {
                        defaults = [SELECT Id FROM Account WHERE IsPartner = true ORDER BY Name LIMIT 1];
                    }
                    if (!defaults.isEmpty()) defaultPartnerId = defaults[0].Id;
                }
            }
        }

        for (Request req : requests) {
            Result res = new Result();
            res.success = false;
            Id pid = String.isNotBlank(req.partnerId) ? (Id) req.partnerId : defaultPartnerId;

            try {
                if (pid == null) {
                    res.message = 'Could not resolve a partner account for the request.';
                    results.add(res);
                    continue;
                }
                if (req.requestedAmount == null || req.requestedAmount <= 0) {
                    res.message = 'Requested amount must be greater than zero.';
                    results.add(res);
                    continue;
                }

                // Find the most recent allocation for this partner
                List<PartnerFundAllocation> allocations = [
                    SELECT Id, BudgetId, Amount, Title
                    FROM PartnerFundAllocation
                    WHERE ChannelPartnerId = :pid
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (allocations.isEmpty()) {
                    res.message = 'No active fund allocation found for this partner. Contact your Channel Manager to request an allocation.';
                    results.add(res);
                    continue;
                }

                PartnerFundAllocation alloc = allocations[0];

                // Map demo activity types to picklist values supported on PartnerFundRequest.Activity
                String activity = mapActivity(req.activityType);

                PartnerFundRequest fr = new PartnerFundRequest();
                fr.Title = (String.isNotBlank(req.projectTitle))
                    ? req.projectTitle
                    : 'MDF Request - ' + Date.today().format();
                fr.ChannelPartnerId = pid;
                fr.AllocationId = alloc.Id;
                fr.BudgetId = alloc.BudgetId;
                fr.RequestedAmount = req.requestedAmount;
                fr.Description = (String.isNotBlank(req.description))
                    ? req.description
                    : 'Submitted via PEM Engagement Agent';
                fr.Activity = activity;
                fr.Status = 'Submitted';

                insert fr;

                // Recompute remaining
                Decimal allocTotal = (alloc.Amount == null) ? 0 : alloc.Amount;
                AggregateResult[] usedAr = [
                    SELECT SUM(RequestedAmount) used
                    FROM PartnerFundRequest
                    WHERE ChannelPartnerId = :pid
                      AND Status IN ('Approved','Submitted')
                ];
                Decimal used = (Decimal) usedAr[0].get('used');
                if (used == null) used = 0;

                res.success = true;
                res.requestId = fr.Id;
                res.remainingBalance = allocTotal - used;
                res.message = 'Your MDF request has been submitted successfully (ID: ' + fr.Id +
                    '). Channel Manager will review within 48 hours. Remaining balance: $' +
                    (allocTotal - used).format() + '.';
            } catch (Exception e) {
                res.success = false;
                res.message = 'Could not submit MDF request: ' + e.getMessage();
            }
            results.add(res);
        }

        return results;
    }

    private static String mapActivity(String input) {
        if (String.isBlank(input)) return 'Other';
        String lower = input.toLowerCase();
        if (lower.contains('tradeshow') || lower.contains('trade show') || lower.contains('event') || lower.contains('conference') || lower.contains('seminar')) {
            return 'Seminar / Conference';
        }
        if (lower.contains('email')) return 'Email';
        if (lower.contains('webinar') || lower.contains('telemarket')) return 'Telemarketing';
        if (lower.contains('banner') || lower.contains('ad ')) return 'Banner Ads';
        if (lower.contains('pr') || lower.contains('public relations')) return 'Public Relations';
        if (lower.contains('referral')) return 'Referral Program';
        if (lower.contains('advert')) return 'Advertisement';
        return 'Other';
    }

    public class Request {
        @InvocableVariable(required=true)
        public Decimal requestedAmount;

        @InvocableVariable
        public String activityType;

        @InvocableVariable
        public String projectTitle;

        @InvocableVariable
        public String description;

        @InvocableVariable
        public String partnerId;
    }

    public class Result {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String requestId;

        @InvocableVariable
        public Decimal remainingBalance;

        @InvocableVariable
        public String message;
    }
}