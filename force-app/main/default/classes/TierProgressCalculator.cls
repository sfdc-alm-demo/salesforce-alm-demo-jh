public with sharing class TierProgressCalculator {

    // Tier targets — the goalposts for the next tier up
    private static final Map<String, Map<String, Decimal>> TIER_TARGETS =
        new Map<String, Map<String, Decimal>>{
            'Bronze' => new Map<String, Decimal>{
                'closedDeals' => 5,
                'pipelineRevenue' => 100000,
                'nextTier' => 0  // unused, just a marker
            },
            'Silver' => new Map<String, Decimal>{
                'closedDeals' => 15,
                'pipelineRevenue' => 500000
            },
            'Gold' => new Map<String, Decimal>{
                'closedDeals' => 40,
                'pipelineRevenue' => 2000000
            }
        };

    private static final Map<String, String> NEXT_TIER = new Map<String, String>{
        'Bronze' => 'Silver',
        'Silver' => 'Gold',
        'Gold'   => 'Platinum'
    };

    @InvocableMethod(
        label='Calculate Tier Progress'
        description='Calculates partner progress toward the next tier using real OpportunityPartner data'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        // Resolve partner IDs (default to first partner if blank)
        Set<Id> partnerIds = new Set<Id>();
        Id defaultPartnerId = null;
        for (Request req : requests) {
            if (String.isNotBlank(req.partnerId)) partnerIds.add(req.partnerId);
        }
        if (partnerIds.isEmpty()) {
            List<Account> defaults = [SELECT Id FROM Account WHERE IsPartner = true AND Name = 'Summit Resellers' LIMIT 1];
            if (defaults.isEmpty()) {
                defaults = [SELECT Id FROM Account WHERE IsPartner = true ORDER BY Name LIMIT 1];
            }
            if (!defaults.isEmpty()) {
                defaultPartnerId = defaults[0].Id;
                partnerIds.add(defaultPartnerId);
            }
        }

        // Aggregate via OpportunityPartner junction (the proper PRM pattern)
        Map<Id, Integer> closedDealsByPartner = new Map<Id, Integer>();
        Map<Id, Decimal> totalRevenueByPartner = new Map<Id, Decimal>();
        Map<Id, Integer> pipelineCountByPartner = new Map<Id, Integer>();
        Map<Id, Decimal> pipelineValueByPartner = new Map<Id, Decimal>();

        if (!partnerIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT AccountToId pid,
                       Opportunity.IsClosed isClosed,
                       Opportunity.IsWon isWon,
                       COUNT(Id) cnt,
                       SUM(Opportunity.Amount) amt
                FROM OpportunityPartner
                WHERE IsPrimary = true
                  AND AccountToId IN :partnerIds
                GROUP BY AccountToId, Opportunity.IsClosed, Opportunity.IsWon
            ]) {
                Id pid = (Id) ar.get('pid');
                Boolean isClosed = (Boolean) ar.get('isClosed');
                Boolean isWon = (Boolean) ar.get('isWon');
                Integer cnt = (Integer) ar.get('cnt');
                Decimal amt = (Decimal) ar.get('amt');
                if (amt == null) amt = 0;

                if (isClosed && isWon) {
                    closedDealsByPartner.put(pid, (closedDealsByPartner.get(pid) == null ? 0 : closedDealsByPartner.get(pid)) + cnt);
                    totalRevenueByPartner.put(pid, (totalRevenueByPartner.get(pid) == null ? 0 : totalRevenueByPartner.get(pid)) + amt);
                } else if (!isClosed) {
                    pipelineCountByPartner.put(pid, (pipelineCountByPartner.get(pid) == null ? 0 : pipelineCountByPartner.get(pid)) + cnt);
                    pipelineValueByPartner.put(pid, (pipelineValueByPartner.get(pid) == null ? 0 : pipelineValueByPartner.get(pid)) + amt);
                }
            }
        }

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;

            Id pid = String.isNotBlank(req.partnerId) ? (Id) req.partnerId : defaultPartnerId;
            String tier = String.isNotBlank(req.currentTier) ? req.currentTier : 'Bronze';

            Integer closedDeals = closedDealsByPartner.get(pid);
            if (closedDeals == null) closedDeals = 0;
            Decimal closedRevenue = totalRevenueByPartner.get(pid);
            if (closedRevenue == null) closedRevenue = 0;
            Integer pipelineCount = pipelineCountByPartner.get(pid);
            if (pipelineCount == null) pipelineCount = 0;
            Decimal pipelineValue = pipelineValueByPartner.get(pid);
            if (pipelineValue == null) pipelineValue = 0;

            if (tier == 'Platinum' || tier == 'Gold' && !TIER_TARGETS.containsKey(tier)) {
                r.progressPercentage = 100;
                r.progressDetails = 'You have achieved the highest tier currently available. Continue to grow your business to maintain your status.';
                r.nextMilestone = 'Maintain annual targets to retain ' + tier + ' status.';
            } else if (TIER_TARGETS.containsKey(tier)) {
                Map<String, Decimal> targets = TIER_TARGETS.get(tier);
                Decimal closedTarget = targets.get('closedDeals');
                Decimal revenueTarget = targets.get('pipelineRevenue');

                Decimal dealsPct = (closedTarget > 0) ? Math.min(100, (Decimal.valueOf(closedDeals) / closedTarget) * 100) : 0;
                Decimal revPct = (revenueTarget > 0) ? Math.min(100, (closedRevenue / revenueTarget) * 100) : 0;
                Decimal avgPct = ((dealsPct + revPct) / 2).setScale(0);

                r.progressPercentage = avgPct;

                String nextTierName = NEXT_TIER.get(tier);
                r.progressDetails = String.format(
                    'You have closed {0} of {1} required deals ({2}%), generated ${3} of ${4} required revenue ({5}%), and have {6} active opportunities worth ${7} in pipeline. Average progress toward {8}: {9}%.',
                    new List<Object>{
                        closedDeals,
                        closedTarget.intValue(),
                        dealsPct.setScale(0),
                        closedRevenue.setScale(0).format(),
                        revenueTarget.setScale(0).format(),
                        revPct.setScale(0),
                        pipelineCount,
                        pipelineValue.setScale(0).format(),
                        nextTierName,
                        avgPct
                    }
                );

                Integer dealsRemaining = (closedTarget - closedDeals).intValue();
                Decimal revRemaining = revenueTarget - closedRevenue;
                if (dealsRemaining > 0 && revRemaining > 0) {
                    r.nextMilestone = 'Close ' + dealsRemaining + ' more deals and generate $' + revRemaining.setScale(0).format() + ' more revenue to reach ' + nextTierName + ' tier.';
                } else if (dealsRemaining > 0) {
                    r.nextMilestone = 'Close ' + dealsRemaining + ' more deals to reach ' + nextTierName + ' tier (revenue target met).';
                } else if (revRemaining > 0) {
                    r.nextMilestone = 'Generate $' + revRemaining.setScale(0).format() + ' more revenue to reach ' + nextTierName + ' tier (deal target met).';
                } else {
                    r.nextMilestone = 'You have met all targets — eligible for promotion to ' + nextTierName + ' tier.';
                }
            } else {
                r.progressPercentage = 0;
                r.progressDetails = 'Unable to determine tier progress.';
                r.nextMilestone = 'Contact your Channel Manager.';
            }

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable
        public String partnerId;

        @InvocableVariable
        public String currentTier;
    }

    public class Result {
        @InvocableVariable
        public Decimal progressPercentage;

        @InvocableVariable
        public String progressDetails;

        @InvocableVariable
        public String nextMilestone;

        @InvocableVariable
        public Boolean hasData;
    }
}