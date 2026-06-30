/**
 * DailySegmentEnrichmentJob — proactive sweep of the Renewal_Risk segment.
 *
 * Replaces the original "only fires when Data Cloud sends a webhook" model with
 * a nightly batch that reads the segment members from Data Cloud (via the same
 * pattern Data360Service uses in the purple-agent-revcloud-demos project) and
 * calls the existing /webhook/data-360-enrichment endpoint for each one.
 *
 * Scheduling:
 *   System.schedule(
 *     'Daily Segment Enrichment',
 *     '0 0 2 * * ?',
 *     new DailySegmentEnrichmentJob()
 *   );
 *
 * Manual run:
 *   Database.executeBatch(new DailySegmentEnrichmentJob(), 25);
 */
public with sharing class DailySegmentEnrichmentJob
        implements Database.Batchable<Id>, Database.AllowsCallouts, Schedulable {

    private static final String NAMED_CREDENTIAL = 'Revenue_Intelligence_Engine';
    private static final String SEGMENT_LABEL = 'Renewal_Risk';
    private static final Decimal RECENCY_THRESHOLD_DAYS = 270;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 25);
    }

    public Iterable<Id> start(Database.BatchableContext bc) {
        return new List<Id>(loadRenewalRiskAccounts());
    }

    public void execute(Database.BatchableContext bc, List<Id> accountIds) {
        for (Id acctId : accountIds) {
            try {
                postEnrichmentWebhook(acctId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Enrichment failed for ' + acctId + ': ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('DailySegmentEnrichmentJob complete.');
    }

    /**
     * Resolve segment members live from Data Cloud. The query mirrors the
     * Renewal_Risk derivation in purple-agent-revcloud-demos Data360Service:
     * accounts with 2+ orders whose most recent order is older than 270 days.
     */
    @TestVisible
    private static Set<Id> loadRenewalRiskAccounts() {
        Set<Id> accountIds = new Set<Id>();
        String sql =
            'SELECT a.ssot__Id__c AS accountId,' +
            ' COUNT(DISTINCT o.ssot__Id__c) AS orders,' +
            ' MAX(o.ssot__OrderStartDate__c) AS lastOrder' +
            ' FROM ssot__Account__dlm a' +
            ' JOIN ssot__SalesOrder__dlm o ON a.ssot__Id__c = o.ssot__BillToAccountId__c' +
            ' GROUP BY a.ssot__Id__c HAVING COUNT(DISTINCT o.ssot__Id__c) >= 2';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/ssot/query');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setBody(JSON.serialize(new Map<String, Object>{ 'sql' => sql }));
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) return accountIds;

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> rows = (List<Object>) body.get('data');
        if (rows == null) return accountIds;

        Datetime cutoff = Datetime.now().addDays(-RECENCY_THRESHOLD_DAYS.intValue());
        for (Object o : rows) {
            Map<String, Object> row = (Map<String, Object>) o;
            String acctId = (String) row.get('accountId');
            String last = (String) row.get('lastOrder');
            if (String.isBlank(acctId) || String.isBlank(last)) continue;
            try {
                Datetime lastDt = (Datetime) JSON.deserialize('"' + last + '"', Datetime.class);
                if (lastDt < cutoff) accountIds.add((Id) acctId);
            } catch (Exception e) {
                continue;
            }
        }
        return accountIds;
    }

    @TestVisible
    private static HttpResponse postEnrichmentWebhook(Id accountId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/webhook/data-360-enrichment');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'source_account_id' => String.valueOf(accountId),
            'segment_label' => SEGMENT_LABEL
        }));
        req.setTimeout(30000);
        return new Http().send(req);
    }
}