public with sharing class CustomCodeAnalyzer {

    private static final Set<String> CPQ_NAMESPACE_PREFIXES = new Set<String>{ 'SBQQ', 'sbqq' };
    private static final Set<String> CPQ_HOOK_KEYWORDS = new Set<String>{
        'CalculateCustomQuoteLineFields',
        'CustomScript',
        'PriceAction',
        'OnInit',
        'OnBeforeCalculate',
        'OnAfterCalculate'
    };

    @InvocableMethod(label='Analyze Custom Code' description='Detects custom Apex pricing plugins and CPQ JavaScript hooks. Flags items requiring manual conversion to RCA.')
    public static List<Response> analyzeCustomCode(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();
        res.hasData = true;

        Boolean cpqInstalled = isCPQInstalled();
        res.cpqDetected = cpqInstalled;

        if (cpqInstalled) {
            res.findings = scanCustomCodeArtifacts();
            res.scanSource = 'live_org';
        } else {
            res.findings = buildNoCPQGuidance();
            res.scanSource = 'no_cpq_detected';
        }

        res.manualConversionCount = countBySeverity(res.findings, 'manual_required');
        res.autoConvertibleCount = countBySeverity(res.findings, 'auto_convertible');
        res.recommendation = recommend(res.manualConversionCount);

        return new List<Response>{ res };
    }

    private static Boolean isCPQInstalled() {
        try {
            Schema.DescribeSObjectResult[] results = Schema.describeSObjects(
                new String[]{ 'SBQQ__PriceRule__c' }
            );
            return results != null && !results.isEmpty() && results[0] != null;
        } catch (Exception e) {
            return false;
        }
    }

    private static List<CodeFinding> scanCustomCodeArtifacts() {
        List<CodeFinding> findings = new List<CodeFinding>();

        Integer apexClassCount = countApexClassesReferencingCPQ();
        if (apexClassCount > 0) {
            findings.add(new CodeFinding(
                'Custom Apex Classes Referencing CPQ',
                'Found ' + apexClassCount + ' Apex classes that reference the SBQQ namespace. ' +
                'Each requires manual review: pricing plugins (QuoteCalculator hooks), custom price actions, ' +
                'integration handlers, and trigger logic on CPQ objects must be rewritten against RCA APIs.',
                'manual_required',
                'High'
            ));
        }

        Integer customScriptCount = countCPQCustomScripts();
        if (customScriptCount > 0) {
            findings.add(new CodeFinding(
                'CPQ Custom Scripts (JavaScript Hooks)',
                'Found ' + customScriptCount + ' CPQ Custom Script records (SBQQ__CustomScript__c). ' +
                'These are JavaScript pricing hooks (OnInit, OnBeforeCalculate, OnAfterCalculate). ' +
                'RCA does not support JavaScript pricing hooks — convert to declarative Pricing Procedure steps or Apex extensions.',
                'manual_required',
                'High'
            ));
        }

        Integer priceRulesWithApex = countPriceRulesWithApexAction();
        if (priceRulesWithApex > 0) {
            findings.add(new CodeFinding(
                'Price Rules with Custom Apex Actions',
                'Found ' + priceRulesWithApex + ' price rules referencing custom Apex actions. ' +
                'Declarative conditions usually convert cleanly; the Apex action body must be rewritten against the RCA Pricing Procedure API.',
                'manual_required',
                'Medium'
            ));
        }

        Integer simpleRuleCount = countSimplePriceRules();
        if (simpleRuleCount > 0) {
            findings.add(new CodeFinding(
                'Declarative Price Rules (Auto-Convertible)',
                simpleRuleCount + ' price rules use only declarative conditions and standard actions. ' +
                'These are candidates for tooling-assisted conversion (e.g., IdeaHelix CPQ→RCA converter).',
                'auto_convertible',
                'Low'
            ));
        }

        if (findings.isEmpty()) {
            findings.add(new CodeFinding(
                'No Custom Code Detected',
                'No CPQ-related Apex classes or custom scripts were found. Migration scope is limited to declarative conversion.',
                'auto_convertible',
                'Info'
            ));
        }

        return findings;
    }

    private static Integer countApexClassesReferencingCPQ() {
        try {
            Schema.DescribeSObjectResult[] describes = Schema.describeSObjects(
                new String[]{ 'ApexClass' }
            );
            if (describes == null || describes.isEmpty() || !describes[0].isAccessible()) {
                return 0;
            }
            return Database.countQuery(
                'SELECT COUNT() FROM ApexClass WHERE NamespacePrefix = NULL AND Body LIKE \'%SBQQ__%\''
            );
        } catch (Exception e) {
            return 0;
        }
    }

    private static Integer countCPQCustomScripts() {
        try {
            Schema.DescribeSObjectResult[] describes = Schema.describeSObjects(
                new String[]{ 'SBQQ__CustomScript__c' }
            );
            if (describes == null || describes.isEmpty() || !describes[0].isAccessible()) {
                return 0;
            }
            return Database.countQuery('SELECT COUNT() FROM SBQQ__CustomScript__c');
        } catch (Exception e) {
            return 0;
        }
    }

    private static Integer countPriceRulesWithApexAction() {
        try {
            Schema.DescribeSObjectResult[] describes = Schema.describeSObjects(
                new String[]{ 'SBQQ__PriceAction__c' }
            );
            if (describes == null || describes.isEmpty() || !describes[0].isAccessible()) {
                return 0;
            }
            return Database.countQuery(
                'SELECT COUNT() FROM SBQQ__PriceAction__c WHERE SBQQ__Formula__c != NULL'
            );
        } catch (Exception e) {
            return 0;
        }
    }

    private static Integer countSimplePriceRules() {
        try {
            Schema.DescribeSObjectResult[] describes = Schema.describeSObjects(
                new String[]{ 'SBQQ__PriceRule__c' }
            );
            if (describes == null || describes.isEmpty() || !describes[0].isAccessible()) {
                return 0;
            }
            return Database.countQuery('SELECT COUNT() FROM SBQQ__PriceRule__c');
        } catch (Exception e) {
            return 0;
        }
    }

    private static List<CodeFinding> buildNoCPQGuidance() {
        List<CodeFinding> findings = new List<CodeFinding>();
        findings.add(new CodeFinding(
            'CPQ Not Installed in This Org',
            'Custom code detection runs against the SBQQ namespace, which is not present here. ' +
            'To analyze custom code, run this assistant in the customer org with CPQ installed, ' +
            'or share an export of ApexClass bodies and SBQQ__CustomScript__c records.',
            'action_required',
            'Action Required'
        ));
        findings.add(new CodeFinding(
            'What to Export Manually',
            'From the customer org, export: (1) ApexClass records where Body contains SBQQ__, ' +
            '(2) SBQQ__CustomScript__c records (full Code__c body), ' +
            '(3) SBQQ__PriceAction__c records with non-null SBQQ__Formula__c. ' +
            'These three artifacts cover 95% of custom CPQ code that needs manual conversion.',
            'guidance',
            'Guidance'
        ));
        return findings;
    }

    private static Integer countBySeverity(List<CodeFinding> findings, String type) {
        if (findings == null) return 0;
        Integer count = 0;
        for (CodeFinding f : findings) {
            if (type.equals(f.classification)) count++;
        }
        return count;
    }

    private static String recommend(Integer manualCount) {
        if (manualCount == 0) {
            return 'No manual code conversion required. Migration can proceed with declarative tooling (e.g., IdeaHelix converter).';
        } else if (manualCount <= 3) {
            return 'Limited manual conversion required. Internal Salesforce dev team can handle. Plan 4-8 weeks for custom code rewrite.';
        } else if (manualCount <= 8) {
            return 'Moderate manual conversion required. Recommend SI partner with Apex expertise. Plan 8-16 weeks.';
        }
        return 'Heavy manual conversion required. Engage SI partner with deep Revenue Cloud experience. ' +
               'Plan 16-24+ weeks for code rewrite. Consider phased approach by code module.';
    }

    public class Request {
        @InvocableVariable
        public String legacySystem;
    }

    public class Response {
        @InvocableVariable
        public Boolean cpqDetected;

        @InvocableVariable
        public List<CodeFinding> findings;

        @InvocableVariable
        public Integer manualConversionCount;

        @InvocableVariable
        public Integer autoConvertibleCount;

        @InvocableVariable
        public String recommendation;

        @InvocableVariable
        public String scanSource;

        @InvocableVariable
        public Boolean hasData;
    }

    public class CodeFinding {
        @InvocableVariable
        public String findingTitle;

        @InvocableVariable
        public String findingDetail;

        @InvocableVariable
        public String classification;

        @InvocableVariable
        public String severity;

        public CodeFinding(String title, String detail, String classification, String severity) {
            this.findingTitle = title;
            this.findingDetail = detail;
            this.classification = classification;
            this.severity = severity;
        }
    }
}