public with sharing class AnomalyClassifier {

    public class Decision {
        @InvocableVariable public Integer tier;
        @InvocableVariable public String rule;
        @InvocableVariable public String summary;
    }

    public static Decision classify(
        AnomalySelectors.AssetContext ctx,
        AnomalySelectors.PatternMatch pattern,
        Integer recentAnomalyCount,
        Integer openP1P2Cases,
        String severitySignal,
        String anomalyCategory
    ) {
        Decision d = new Decision();

        Boolean novel = (pattern == null || pattern.found != true);
        Decimal conf = (pattern != null && pattern.matchConfidence != null) ? pattern.matchConfidence : 0;
        Boolean strategic = ctx != null && ctx.strategicAccount == true;
        String sla = (ctx != null && String.isNotBlank(ctx.slaTier)) ? ctx.slaTier : 'Gold';
        String sev = String.isNotBlank(severitySignal) ? severitySignal : 'Medium';
        Boolean highSev = (sev == 'Critical' || sev == 'High');

        if (novel && highSev) {
            d.tier = 3; d.rule = 'NOVEL_PATTERN_HIGH_SEVERITY';
        } else if (strategic && highSev) {
            d.tier = 3; d.rule = 'STRATEGIC_ACCOUNT_HIGH_SEVERITY';
        } else if (recentAnomalyCount >= 3) {
            d.tier = 3; d.rule = 'CORRELATION_BREACH_3_IN_24H';
        } else if ((sla == 'Platinum' || sla == 'Strategic') && highSev) {
            d.tier = 3; d.rule = 'PLATINUM_OR_STRATEGIC_HIGH_SEVERITY';
        } else if (!novel && conf >= 0.60 && conf < 0.85) {
            d.tier = 2; d.rule = 'KNOWN_PATTERN_ESCALATION_CONFIDENCE_BAND';
        } else if (sla == 'Gold' && sev == 'High') {
            d.tier = 2; d.rule = 'GOLD_SLA_HIGH_SEVERITY';
        } else if (novel && sev == 'Medium') {
            d.tier = 2; d.rule = 'NOVEL_PATTERN_MEDIUM_SEVERITY';
        } else if (openP1P2Cases > 0) {
            d.tier = 2; d.rule = 'EXISTING_OPEN_P1_P2_CASE';
        } else if (!novel && conf >= 0.85
                   && (sla == 'Standard' || sla == 'Silver')
                   && (anomalyCategory == 'Thermal' || anomalyCategory == 'Firmware')) {
            d.tier = 1; d.rule = 'KNOWN_RECOVERABLE_LOW_SLA';
        } else {
            d.tier = 2; d.rule = 'DEFAULT_ESCALATE';
        }

        d.summary = 'Tier ' + d.tier + ' classification fired by rule ' + d.rule
            + ' [novel=' + novel + ', conf=' + conf + ', sev=' + sev
            + ', sla=' + sla + ', strategic=' + strategic
            + ', recent24h=' + recentAnomalyCount + ', openP1P2=' + openP1P2Cases + ']';
        return d;
    }
}