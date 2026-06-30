/**
 * Bidirectional loop closer: when Heroku Connect pushes an updated Revenue_Insight__c
 * into Salesforce (Data Cloud webhook → enrichment → insight write-back), this handler
 * surfaces the change to humans by posting a Chatter note on the related Account whenever
 * risk_score crosses 0.7 OR the Data 360 segment label changes.
 *
 * Account resolution is best-effort:
 *   - Transaction_Id__c is the Quote/Order/SBQQ__Quote__c Id
 *   - Lookup AccountId via the parent transaction in a single bulk SOQL (no DML in trigger)
 */
public with sharing class RevenueInsightTriggerHandler {

    private static final Decimal HIGH_RISK_THRESHOLD = 0.7;

    public static void handle(List<Revenue_Insight__c> newList, Map<Id, Revenue_Insight__c> oldMap) {
        List<Revenue_Insight__c> notable = new List<Revenue_Insight__c>();
        for (Revenue_Insight__c ri : newList) {
            Revenue_Insight__c prior = (oldMap == null) ? null : oldMap.get(ri.Id);
            if (isNotable(ri, prior)) notable.add(ri);
        }
        if (notable.isEmpty()) return;

        Map<Id, Id> txnToAccount = resolveAccountIds(notable);
        if (txnToAccount.isEmpty()) return;

        List<FeedItem> posts = new List<FeedItem>();
        for (Revenue_Insight__c ri : notable) {
            Id acctId = lookupAccount(txnToAccount, ri.Transaction_Id__c);
            if (acctId == null) continue;
            posts.add(new FeedItem(
                ParentId = acctId,
                Body = composeChatterBody(ri),
                Type = 'TextPost'
            ));
        }
        if (!posts.isEmpty() && Schema.SObjectType.FeedItem.isCreateable()) {
            insert posts;
        }
    }

    @TestVisible
    private static Boolean isNotable(Revenue_Insight__c ri, Revenue_Insight__c prior) {
        if (prior == null) {
            return ri.Risk_Score__c != null && ri.Risk_Score__c >= HIGH_RISK_THRESHOLD;
        }
        Boolean crossedRisk =
            ri.Risk_Score__c != null
            && ri.Risk_Score__c >= HIGH_RISK_THRESHOLD
            && (prior.Risk_Score__c == null || prior.Risk_Score__c < HIGH_RISK_THRESHOLD);
        Boolean segmentChanged =
            ri.Data_360_Segment__c != prior.Data_360_Segment__c
            && String.isNotBlank(ri.Data_360_Segment__c);
        return crossedRisk || segmentChanged;
    }

    private static Map<Id, Id> resolveAccountIds(List<Revenue_Insight__c> insights) {
        Set<Id> orderIds = new Set<Id>();
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> sbqqQuoteIds = new Set<Id>();
        for (Revenue_Insight__c ri : insights) {
            if (String.isBlank(ri.Transaction_Id__c)) continue;
            Id parsed = safeId(ri.Transaction_Id__c);
            if (parsed == null) continue;
            String prefix = String.valueOf(parsed).substring(0, 3);
            if (prefix == '801') orderIds.add(parsed);
            else if (prefix == '0Q0') quoteIds.add(parsed);
            else sbqqQuoteIds.add(parsed); // best guess for Revenue Cloud quote custom object
        }

        Map<Id, Id> accountByTxn = new Map<Id, Id>();
        if (!orderIds.isEmpty()) {
            for (Order o : [SELECT Id, AccountId FROM Order WHERE Id IN :orderIds]) {
                if (o.AccountId != null) accountByTxn.put(o.Id, o.AccountId);
            }
        }
        if (!quoteIds.isEmpty()) {
            // Standard Quote object — guarded against orgs without Quote enabled
            try {
                String soql = 'SELECT Id, AccountId FROM Quote WHERE Id IN :quoteIds';
                List<SObject> quotes = Database.query(soql);
                for (SObject q : quotes) {
                    Id acct = (Id) q.get('AccountId');
                    if (acct != null) accountByTxn.put((Id) q.get('Id'), acct);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Quote not enabled in this org: ' + e.getMessage());
            }
        }
        // SBQQ__Quote__c lookup intentionally omitted — handler is org-agnostic.
        return accountByTxn;
    }

    private static Id safeId(String s) {
        try { return (Id) s; } catch (Exception e) { return null; }
    }

    private static Id lookupAccount(Map<Id, Id> accountByTxn, String txnId) {
        Id parsed = safeId(txnId);
        return parsed == null ? null : accountByTxn.get(parsed);
    }

    @TestVisible
    private static String composeChatterBody(Revenue_Insight__c ri) {
        List<String> parts = new List<String>();
        parts.add('Revenue Intelligence update for transaction ' + ri.Transaction_Id__c + '.');
        if (ri.Risk_Score__c != null) {
            parts.add('Risk score: ' + ri.Risk_Score__c + (ri.Risk_Score__c >= HIGH_RISK_THRESHOLD ? ' (high risk).' : '.'));
        }
        if (String.isNotBlank(ri.Data_360_Segment__c)) {
            parts.add('Data 360 segment: ' + ri.Data_360_Segment__c + '.');
        }
        if (String.isNotBlank(ri.Recommendation_Text__c)) {
            String snippet = ri.Recommendation_Text__c.length() > 240
                ? ri.Recommendation_Text__c.substring(0, 240) + '…'
                : ri.Recommendation_Text__c;
            parts.add('Recommendation: ' + snippet);
        }
        return String.join(parts, ' ');
    }
}