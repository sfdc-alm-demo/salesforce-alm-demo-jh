public with sharing class AnomalySelectors {

    public class AssetContext {
        @InvocableVariable public Id assetId;
        @InvocableVariable public Id accountId;
        @InvocableVariable public String accountName;
        @InvocableVariable public String slaTier;
        @InvocableVariable public Boolean strategicAccount;
        @InvocableVariable public Boolean triageFrozen;
        @InvocableVariable public String productCode;
    }

    public class PatternMatch {
        @InvocableVariable public Id patternId;
        @InvocableVariable public String patternName;
        @InvocableVariable public Decimal matchConfidence;
        @InvocableVariable public String recommendedAction;
        @InvocableVariable public Boolean found;
    }

    // -------- Single-record (legacy; kept for compatibility) --------

    public static AssetContext lookupAssetBySerial(String serial) {
        if (String.isBlank(serial)) return new AssetContext();
        Map<String, AssetContext> m = lookupAssetsBySerial(new Set<String>{serial});
        return m.containsKey(serial) ? m.get(serial) : new AssetContext();
    }

    public static Integer countOpenP1P2Cases(Id assetId) {
        if (assetId == null) return 0;
        Map<Id, Integer> m = countOpenP1P2CasesBulk(new Set<Id>{assetId});
        return m.containsKey(assetId) ? m.get(assetId) : 0;
    }

    public static Integer countRecentAnomalies(Id assetId, Integer lookbackHours) {
        if (assetId == null) return 0;
        Map<Id, Integer> m = countRecentAnomaliesBulk(new Set<Id>{assetId}, lookbackHours);
        return m.containsKey(assetId) ? m.get(assetId) : 0;
    }

    public static PatternMatch lookupKnownPattern(String hash) {
        PatternMatch pm = new PatternMatch();
        pm.found = false;
        pm.matchConfidence = 0;
        if (String.isBlank(hash)) return pm;
        Map<String, PatternMatch> m = lookupKnownPatternsByHash(new Set<String>{hash});
        return m.containsKey(hash) ? m.get(hash) : pm;
    }

    // -------- Bulk methods (used by AnomalyTriageActions.triage) --------

    public static Map<String, AssetContext> lookupAssetsBySerial(Set<String> serials) {
        Map<String, AssetContext> out = new Map<String, AssetContext>();
        if (serials == null || serials.isEmpty()) return out;
        Set<String> cleaned = new Set<String>();
        for (String s : serials) { if (String.isNotBlank(s)) cleaned.add(s); }
        if (cleaned.isEmpty()) return out;
        for (Asset a : [
            SELECT Id, SerialNumber, AccountId, Account.Name, Account.SLA_Tier__c, Account.Strategic_Account__c,
                   Triage_Frozen__c, Product2.ProductCode
            FROM Asset
            WHERE SerialNumber IN :cleaned
            WITH SECURITY_ENFORCED
        ]) {
            AssetContext ctx = new AssetContext();
            ctx.assetId = a.Id;
            ctx.accountId = a.AccountId;
            ctx.accountName = a.Account != null ? a.Account.Name : null;
            ctx.slaTier = (a.Account != null && a.Account.SLA_Tier__c != null) ? a.Account.SLA_Tier__c : 'Gold';
            ctx.strategicAccount = (a.Account != null && a.Account.Strategic_Account__c == true);
            ctx.triageFrozen = a.Triage_Frozen__c == true;
            ctx.productCode = a.Product2 != null ? a.Product2.ProductCode : null;
            out.put(a.SerialNumber, ctx);
        }
        return out;
    }

    public static Set<String> findExistingCorrelationIds(Set<String> ids) {
        Set<String> out = new Set<String>();
        if (ids == null || ids.isEmpty()) return out;
        Set<String> cleaned = new Set<String>();
        for (String s : ids) { if (String.isNotBlank(s)) cleaned.add(s); }
        if (cleaned.isEmpty()) return out;
        for (Anomaly_Audit__c a : [
            SELECT Correlation_Id__c
            FROM Anomaly_Audit__c
            WHERE Correlation_Id__c IN :cleaned
            WITH SECURITY_ENFORCED
        ]) {
            out.add(a.Correlation_Id__c);
        }
        return out;
    }

    public static Map<String, PatternMatch> lookupKnownPatternsByHash(Set<String> hashes) {
        Map<String, PatternMatch> out = new Map<String, PatternMatch>();
        if (hashes == null || hashes.isEmpty()) return out;
        Set<String> cleaned = new Set<String>();
        for (String s : hashes) { if (String.isNotBlank(s)) cleaned.add(s); }
        if (cleaned.isEmpty()) return out;
        for (Known_Pattern__c p : [
            SELECT Id, Name, Match_Confidence__c, Recommended_Action__c, Pattern_Hash__c
            FROM Known_Pattern__c
            WHERE Pattern_Hash__c IN :cleaned
            WITH SECURITY_ENFORCED
        ]) {
            PatternMatch pm = new PatternMatch();
            pm.found = true;
            pm.patternId = p.Id;
            pm.patternName = p.Name;
            pm.matchConfidence = p.Match_Confidence__c;
            pm.recommendedAction = p.Recommended_Action__c;
            // Only record first hit per hash
            if (!out.containsKey(p.Pattern_Hash__c)) out.put(p.Pattern_Hash__c, pm);
        }
        return out;
    }

    public static Map<Id, Integer> countRecentAnomaliesBulk(Set<Id> assetIds, Integer lookbackHours) {
        Map<Id, Integer> out = new Map<Id, Integer>();
        if (assetIds == null || assetIds.isEmpty()) return out;
        DateTime since = DateTime.now().addHours(-1 * lookbackHours);
        for (AggregateResult ar : [
            SELECT Asset__c assetId, COUNT(Id) cnt
            FROM Anomaly_Audit__c
            WHERE Asset__c IN :assetIds
            AND Processed_At__c >= :since
            WITH SECURITY_ENFORCED
            GROUP BY Asset__c
        ]) {
            Id aid = (Id) ar.get('assetId');
            Integer cnt = (Integer) ar.get('cnt');
            if (aid != null) out.put(aid, cnt);
        }
        for (Id aid : assetIds) { if (!out.containsKey(aid)) out.put(aid, 0); }
        return out;
    }

    public static Map<Id, Integer> countOpenP1P2CasesBulk(Set<Id> assetIds) {
        Map<Id, Integer> out = new Map<Id, Integer>();
        if (assetIds == null || assetIds.isEmpty()) return out;
        for (AggregateResult ar : [
            SELECT AssetId assetId, COUNT(Id) cnt
            FROM Case
            WHERE AssetId IN :assetIds
            AND IsClosed = false
            AND Priority IN ('High', 'Critical')
            WITH SECURITY_ENFORCED
            GROUP BY AssetId
        ]) {
            Id aid = (Id) ar.get('assetId');
            Integer cnt = (Integer) ar.get('cnt');
            if (aid != null) out.put(aid, cnt);
        }
        for (Id aid : assetIds) { if (!out.containsKey(aid)) out.put(aid, 0); }
        return out;
    }
}