/**
 * Data360Service — bridge from Apex/LWC/Agentforce to Data Cloud ANSI SQL.
 *
 * Replaces the original CIO-materialization plan: instead of pre-computing
 * Account_Revenue_Summary / Product_Family_Performance / Account_Engagement_Score
 * as Calculated Insights, we run the same SQL on demand against the DMOs via
 * the /services/data/vXX.0/ssot/query REST endpoint. Volumes are small (175
 * orders, 343 line items) so latency is fine.
 *
 * Auth: self-hop using URL.getOrgDomainUrl() + UserInfo.getSessionId() as a
 * Bearer token. The org domain must be added to Setup → Remote Site Settings
 * (or use a Named Credential — see PurpleSolar_Demo_Permissions for the perm
 * grant if a Named Credential is preferred).
 *
 * Methods are exposed both as @AuraEnabled (LWC) and @InvocableMethod (Agent).
 */
public with sharing class Data360Service {

    @TestVisible private static final String ENDPOINT_PATH = '/services/data/v62.0/ssot/query';
    @TestVisible private static final Integer DEFAULT_TIMEOUT_MS = 60000;

    // ---------- DTOs ----------

    public class AccountRevenueSummary {
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Decimal totalRevenue;
        @AuraEnabled public Integer orderCount;
        @AuraEnabled public Decimal avgLineValue;
        @AuraEnabled public String lastOrderDate;
    }

    public class ProductFamilyPerformance {
        @AuraEnabled public String family;
        @AuraEnabled public Integer orderCount;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal revenue;
        @AuraEnabled public Integer accountReach;
    }

    public class AccountEngagementScore {
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Integer orderCount;
        @AuraEnabled public Decimal totalRevenue;
        @AuraEnabled public String lastOrderDate;
        @AuraEnabled public Integer recencyDays;
        @AuraEnabled public Decimal rfmScore;   // composite 0-100
    }

    public class AccountBriefing {
        @AuraEnabled public AccountRevenueSummary revenue;
        @AuraEnabled public List<ProductFamilyPerformance> topFamilies;
        @AuraEnabled public AccountEngagementScore engagement;
        @AuraEnabled public List<String> segmentMembership;
    }

    // ---------- @AuraEnabled (LWC) ----------

    @AuraEnabled(cacheable=true)
    public static List<AccountRevenueSummary> getTopAccountRevenue(Integer topN) {
        Integer n = (topN == null || topN <= 0) ? 10 : topN;
        String sql =
            'SELECT a.ssot__Id__c AS accountId, a.ssot__Name__c AS accountName,' +
            ' SUM(sop.ssot__ListPriceAmount__c * sop.ssot__OrderedQuantity__c) AS totalRevenue,' +
            ' COUNT(DISTINCT o.ssot__Id__c) AS orderCount,' +
            ' AVG(sop.ssot__ListPriceAmount__c * sop.ssot__OrderedQuantity__c) AS avgLineValue,' +
            ' MAX(o.ssot__OrderStartDate__c) AS lastOrderDate' +
            ' FROM ssot__Account__dlm a' +
            ' JOIN ssot__SalesOrder__dlm o ON a.ssot__Id__c = o.ssot__BillToAccountId__c' +
            ' JOIN ssot__SalesOrderProduct__dlm sop ON o.ssot__Id__c = sop.ssot__SalesOrderId__c' +
            ' GROUP BY a.ssot__Id__c, a.ssot__Name__c' +
            ' ORDER BY totalRevenue DESC LIMIT ' + n;
        List<Map<String, Object>> rows = runSql(sql);
        List<AccountRevenueSummary> out = new List<AccountRevenueSummary>();
        for (Map<String, Object> r : rows) {
            AccountRevenueSummary s = new AccountRevenueSummary();
            s.accountId    = (String) r.get('accountId');
            s.accountName  = (String) r.get('accountName');
            s.totalRevenue = toDecimal(r.get('totalRevenue'));
            s.orderCount   = toInteger(r.get('orderCount'));
            s.avgLineValue = toDecimal(r.get('avgLineValue'));
            s.lastOrderDate = (String) r.get('lastOrderDate');
            out.add(s);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static AccountRevenueSummary getAccountRevenueSummary(String accountId) {
        if (String.isBlank(accountId)) return null;
        String sanitized = sanitizeId(accountId);
        String sql =
            'SELECT a.ssot__Id__c AS accountId, a.ssot__Name__c AS accountName,' +
            ' SUM(sop.ssot__ListPriceAmount__c * sop.ssot__OrderedQuantity__c) AS totalRevenue,' +
            ' COUNT(DISTINCT o.ssot__Id__c) AS orderCount,' +
            ' AVG(sop.ssot__ListPriceAmount__c * sop.ssot__OrderedQuantity__c) AS avgLineValue,' +
            ' MAX(o.ssot__OrderStartDate__c) AS lastOrderDate' +
            ' FROM ssot__Account__dlm a' +
            ' JOIN ssot__SalesOrder__dlm o ON a.ssot__Id__c = o.ssot__BillToAccountId__c' +
            ' JOIN ssot__SalesOrderProduct__dlm sop ON o.ssot__Id__c = sop.ssot__SalesOrderId__c' +
            ' WHERE a.ssot__Id__c = \'' + sanitized + '\'' +
            ' GROUP BY a.ssot__Id__c, a.ssot__Name__c';
        List<Map<String, Object>> rows = runSql(sql);
        if (rows.isEmpty()) return null;
        Map<String, Object> r = rows[0];
        AccountRevenueSummary s = new AccountRevenueSummary();
        s.accountId    = (String) r.get('accountId');
        s.accountName  = (String) r.get('accountName');
        s.totalRevenue = toDecimal(r.get('totalRevenue'));
        s.orderCount   = toInteger(r.get('orderCount'));
        s.avgLineValue = toDecimal(r.get('avgLineValue'));
        s.lastOrderDate = (String) r.get('lastOrderDate');
        return s;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductFamilyPerformance> getProductFamilyPerformance(Integer topN) {
        Integer n = (topN == null || topN <= 0) ? 10 : topN;
        String sql =
            'SELECT p.ssot__ProductFamily__c AS family,' +
            ' COUNT(DISTINCT sop.ssot__SalesOrderId__c) AS orderCount,' +
            ' SUM(sop.ssot__OrderedQuantity__c) AS units,' +
            ' SUM(sop.ssot__ListPriceAmount__c * sop.ssot__OrderedQuantity__c) AS revenue,' +
            ' COUNT(DISTINCT o.ssot__BillToAccountId__c) AS accountReach' +
            ' FROM ssot__SalesOrderProduct__dlm sop' +
            ' JOIN ssot__Product__dlm p ON sop.ssot__ProductId__c = p.ssot__Id__c' +
            ' JOIN ssot__SalesOrder__dlm o ON sop.ssot__SalesOrderId__c = o.ssot__Id__c' +
            ' GROUP BY p.ssot__ProductFamily__c' +
            ' ORDER BY revenue DESC LIMIT ' + n;
        List<Map<String, Object>> rows = runSql(sql);
        List<ProductFamilyPerformance> out = new List<ProductFamilyPerformance>();
        for (Map<String, Object> r : rows) {
            ProductFamilyPerformance p = new ProductFamilyPerformance();
            p.family       = (String) r.get('family');
            p.orderCount   = toInteger(r.get('orderCount'));
            p.units        = toDecimal(r.get('units'));
            p.revenue      = toDecimal(r.get('revenue'));
            p.accountReach = toInteger(r.get('accountReach'));
            out.add(p);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static AccountEngagementScore getAccountEngagementScore(String accountId) {
        AccountRevenueSummary rev = getAccountRevenueSummary(accountId);
        if (rev == null) return null;

        AccountEngagementScore e = new AccountEngagementScore();
        e.accountId    = rev.accountId;
        e.accountName  = rev.accountName;
        e.orderCount   = rev.orderCount;
        e.totalRevenue = rev.totalRevenue;
        e.lastOrderDate = rev.lastOrderDate;
        e.recencyDays  = recencyDays(rev.lastOrderDate);
        e.rfmScore     = composeRfm(e.recencyDays, rev.orderCount, rev.totalRevenue);
        return e;
    }

    @AuraEnabled(cacheable=true)
    public static AccountBriefing getAccountBriefing(String accountId) {
        AccountBriefing b = new AccountBriefing();
        b.revenue     = getAccountRevenueSummary(accountId);
        b.engagement  = getAccountEngagementScore(accountId);
        b.topFamilies = getProductFamilyPerformance(5);
        b.segmentMembership = derivedSegmentsFor(b);
        return b;
    }

    // ---------- @InvocableMethod (Agentforce) ----------

    public class BriefingRequest {
        @InvocableVariable(required=true label='Account Id')
        public String accountId;
    }

    public class BriefingResponse {
        @InvocableVariable public AccountBriefing briefing;
        @InvocableVariable public String summary;
    }

    @InvocableMethod(
        label='Get Account Revenue Briefing'
        description='Returns Data Cloud-derived revenue summary, engagement score, top product families, and segment membership for an Account.'
    )
    public static List<BriefingResponse> getAccountBriefingInvocable(List<BriefingRequest> requests) {
        List<BriefingResponse> out = new List<BriefingResponse>();
        for (BriefingRequest req : requests) {
            BriefingResponse resp = new BriefingResponse();
            resp.briefing = getAccountBriefing(req.accountId);
            resp.summary = formatSummary(resp.briefing);
            out.add(resp);
        }
        return out;
    }

    // ---------- Internals ----------

    @TestVisible
    private static List<Map<String, Object>> runSql(String sql) {
        String base = URL.getOrgDomainUrl().toExternalForm();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(base + ENDPOINT_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setTimeout(DEFAULT_TIMEOUT_MS);
        req.setBody(JSON.serialize(new Map<String, Object>{ 'sql' => sql }));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('Data Cloud query failed (' + res.getStatusCode() + '): ' + res.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object data = body.get('data');
        if (data == null) return new List<Map<String, Object>>();
        List<Object> raw = (List<Object>) data;
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (Object o : raw) out.add((Map<String, Object>) o);
        return out;
    }

    private static String sanitizeId(String s) {
        return s == null ? '' : s.replaceAll('[^A-Za-z0-9]', '');
    }

    private static Decimal toDecimal(Object v) {
        if (v == null) return null;
        if (v instanceof Decimal) return (Decimal) v;
        if (v instanceof Integer) return Decimal.valueOf((Integer) v);
        if (v instanceof Long) return Decimal.valueOf((Long) v);
        if (v instanceof Double) return Decimal.valueOf(String.valueOf(v));
        try { return Decimal.valueOf(String.valueOf(v)); } catch (Exception e) { return null; }
    }

    private static Integer toInteger(Object v) {
        Decimal d = toDecimal(v);
        return d == null ? null : d.intValue();
    }

    private static Integer recencyDays(String iso) {
        if (String.isBlank(iso)) return null;
        try {
            Datetime dt = (Datetime) JSON.deserialize('"' + iso + '"', Datetime.class);
            return Integer.valueOf(((Datetime.now().getTime() - dt.getTime()) / (1000L * 60L * 60L * 24L)));
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * RFM composite, scaled 0-100. Recency: lower days -> higher score.
     * Frequency: orderCount banded. Monetary: log10 of revenue banded.
     * This is intentionally simple — it's a demo, not a churn model.
     */
    private static Decimal composeRfm(Integer recencyDays, Integer orderCount, Decimal revenue) {
        Decimal r = recencyDays == null ? 0 : Math.max(0, 100 - Math.min(100, recencyDays / 4));
        Decimal f = orderCount == null ? 0 : Math.min(100, orderCount * 10);
        Decimal m;
        if (revenue == null || revenue <= 0) {
            m = 0;
        } else {
            Double logVal = Math.log10(revenue.doubleValue());
            m = Math.max(0, Math.min(100, (logVal - 3) * 25));
        }
        return ((r + f + m) / 3).setScale(1);
    }

    private static List<String> derivedSegmentsFor(AccountBriefing b) {
        List<String> segs = new List<String>();
        if (b.revenue == null) return segs;

        if (b.revenue.totalRevenue != null && b.revenue.totalRevenue >= 200000) {
            segs.add('High_Value_Renewable_Buyers');
        }
        if (b.engagement != null && b.engagement.recencyDays != null && b.engagement.recencyDays > 270 && b.revenue.orderCount != null && b.revenue.orderCount >= 2) {
            segs.add('Renewal_Risk');
        }
        if (hasFamilyPurchase(b, 'Solar Panels') && !hasFamilyPurchase(b, 'Home Solutions')) {
            segs.add('Cross_Sell_Solar_to_Home_Solutions');
        }
        return segs;
    }

    private static Boolean hasFamilyPurchase(AccountBriefing b, String family) {
        if (b == null || b.topFamilies == null) return false;
        for (ProductFamilyPerformance pf : b.topFamilies) {
            if (family.equalsIgnoreCase(pf.family)) return true;
        }
        return false;
    }

    private static String formatSummary(AccountBriefing b) {
        if (b == null || b.revenue == null) return 'No Data Cloud activity found for this account.';
        List<String> parts = new List<String>();
        parts.add(b.revenue.accountName + ' has ' + b.revenue.orderCount + ' orders totalling $' + b.revenue.totalRevenue + '.');
        if (b.engagement != null && b.engagement.recencyDays != null) {
            parts.add('Last ordered ' + b.engagement.recencyDays + ' days ago. RFM score: ' + b.engagement.rfmScore + '/100.');
        }
        if (b.segmentMembership != null && !b.segmentMembership.isEmpty()) {
            parts.add('Segments: ' + String.join(b.segmentMembership, ', ') + '.');
        }
        return String.join(parts, ' ');
    }
}