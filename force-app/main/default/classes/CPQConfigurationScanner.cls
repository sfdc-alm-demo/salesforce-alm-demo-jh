public with sharing class CPQConfigurationScanner {

    private static final String CPQ_PRODUCT_OBJECT = 'SBQQ__Product__c';
    private static final String CPQ_PRICE_RULE_OBJECT = 'SBQQ__PriceRule__c';
    private static final String CPQ_QUOTE_OBJECT = 'SBQQ__Quote__c';
    private static final String CPQ_PRODUCT_OPTION_OBJECT = 'SBQQ__ProductOption__c';

    @InvocableMethod(label='Scan CPQ Configuration' description='Detects CPQ managed package and scans the customer org for product, rule, and bundle counts. Falls back to upload guidance when CPQ is not installed.')
    public static List<Response> scanConfiguration(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();
        res.hasData = true;

        Boolean cpqInstalled = isCPQInstalled();
        res.cpqDetected = cpqInstalled;

        if (cpqInstalled) {
            populateLiveScanResults(res);
            res.detectionMessage = 'CPQ managed package detected in this org. Counts below reflect your live configuration.';
        } else {
            populateNoCPQGuidance(res);
            res.detectionMessage = 'CPQ managed package was not detected in this org. To get a real assessment, export your CPQ configuration as JSON or CSV and share it with this assistant.';
        }

        res.scanFindings = buildScanFindings(res, req.industry);
        res.complexityScore = scoreComplexity(res.productCount, res.priceRuleCount, res.bundleDepth);

        return new List<Response>{ res };
    }

    private static Boolean isCPQInstalled() {
        try {
            Schema.DescribeSObjectResult[] results = Schema.describeSObjects(
                new String[]{ CPQ_PRICE_RULE_OBJECT }
            );
            return results != null && !results.isEmpty() && results[0] != null;
        } catch (Exception e) {
            return false;
        }
    }

    private static void populateLiveScanResults(Response res) {
        res.productCount = safeCount(CPQ_PRODUCT_OBJECT);
        res.priceRuleCount = safeCount(CPQ_PRICE_RULE_OBJECT);
        res.quoteCount = safeCount(CPQ_QUOTE_OBJECT);
        res.bundleDepth = safeBundleDepth();
        res.scanSource = 'live_org';
    }

    private static void populateNoCPQGuidance(Response res) {
        res.productCount = 0;
        res.priceRuleCount = 0;
        res.quoteCount = 0;
        res.bundleDepth = 0;
        res.scanSource = 'no_cpq_detected';
    }

    private static Integer safeCount(String objectApiName) {
        try {
            Schema.DescribeSObjectResult[] describes = Schema.describeSObjects(
                new String[]{ objectApiName }
            );
            if (describes == null || describes.isEmpty() || describes[0] == null) {
                return 0;
            }
            Schema.DescribeSObjectResult describe = describes[0];
            if (!describe.isAccessible()) {
                return 0;
            }
            String soql = 'SELECT COUNT() FROM ' + String.escapeSingleQuotes(objectApiName);
            return Database.countQuery(soql);
        } catch (Exception e) {
            return 0;
        }
    }

    private static Integer safeBundleDepth() {
        try {
            Schema.DescribeSObjectResult[] describes = Schema.describeSObjects(
                new String[]{ CPQ_PRODUCT_OPTION_OBJECT }
            );
            if (describes == null || describes.isEmpty() || describes[0] == null) {
                return 0;
            }
            if (!describes[0].isAccessible()) {
                return 0;
            }
            Integer optionCount = Database.countQuery(
                'SELECT COUNT() FROM ' + CPQ_PRODUCT_OPTION_OBJECT
            );
            if (optionCount == 0) return 0;
            if (optionCount < 50) return 1;
            if (optionCount < 250) return 2;
            return 3;
        } catch (Exception e) {
            return 0;
        }
    }

    private static List<ScanFinding> buildScanFindings(Response res, String industry) {
        List<ScanFinding> findings = new List<ScanFinding>();

        if (res.cpqDetected) {
            findings.add(new ScanFinding(
                'Product Catalog Size',
                'Detected ' + res.productCount + ' CPQ products. ' +
                (res.productCount > 200 ? 'Large catalog — recommend phased migration by product line.' :
                 res.productCount > 50 ? 'Moderate catalog — Net New Pilot strategy is a good fit.' :
                 'Small catalog — full cutover migration is feasible.'),
                res.productCount > 200 ? 'High' : 'Medium'
            ));

            findings.add(new ScanFinding(
                'Pricing Rule Volume',
                'Detected ' + res.priceRuleCount + ' price rules. ' +
                (res.priceRuleCount > 50 ? 'High rule volume — SI partner engagement strongly recommended for conversion.' :
                 res.priceRuleCount > 20 ? 'Moderate rule volume — most rules will convert declaratively, some may need custom Apex steps.' :
                 'Low rule volume — Pricing Procedures should convert cleanly.'),
                res.priceRuleCount > 50 ? 'High' : 'Medium'
            ));

            findings.add(new ScanFinding(
                'Bundle Complexity',
                'Bundle depth estimate: ' + res.bundleDepth + '. ' +
                (res.bundleDepth >= 3 ? 'Deep nesting detected — review attribute-based modeling carefully.' :
                 res.bundleDepth >= 1 ? 'Standard bundle depth — straightforward to remodel in PCM.' :
                 'No bundle structure detected.'),
                res.bundleDepth >= 3 ? 'High' : 'Low'
            ));

            findings.add(new ScanFinding(
                'Historical Quote Volume',
                'Detected ' + res.quoteCount + ' historical quotes. ' +
                (res.quoteCount > 1000 ? 'Significant historical data — plan for staged data migration with reconciliation reports.' :
                 'Manageable quote volume for migration.'),
                res.quoteCount > 1000 ? 'Medium' : 'Low'
            ));
        } else {
            findings.add(new ScanFinding(
                'CPQ Not Detected',
                'The CPQ managed package (SBQQ namespace) is not installed in this org. To proceed, export your CPQ configuration (Products, Price Rules, Bundles) as JSON or CSV and provide it to this assistant for analysis.',
                'Action Required'
            ));

            findings.add(new ScanFinding(
                'Recommended Export Format',
                'Use Salesforce Data Loader or Workbench to export: SBQQ__Product__c, SBQQ__PriceRule__c, SBQQ__ProductOption__c. The assistant can then ingest these to provide tailored recommendations.',
                'Guidance'
            ));
        }

        if (String.isNotBlank(industry)) {
            findings.add(new ScanFinding(
                industry + ' Industry Considerations',
                'Industry-specific patterns will be applied during plan generation. Provide this scan output to the migration plan generator for tailored guidance.',
                'Info'
            ));
        }

        return findings;
    }

    private static String scoreComplexity(Integer productCount, Integer ruleCount, Integer bundleDepth) {
        if (productCount == 0 && ruleCount == 0) {
            return 'unknown';
        }
        Integer score = 0;
        if (productCount > 200) score += 3;
        else if (productCount > 50) score += 2;
        else score += 1;

        if (ruleCount > 50) score += 3;
        else if (ruleCount > 20) score += 2;
        else score += 1;

        if (bundleDepth >= 3) score += 2;
        else if (bundleDepth >= 1) score += 1;

        if (score >= 7) return 'highly_complex';
        if (score >= 5) return 'complex';
        if (score >= 3) return 'moderate';
        return 'simple';
    }

    public class Request {
        @InvocableVariable
        public String industry;

        @InvocableVariable
        public String legacySystem;
    }

    public class Response {
        @InvocableVariable
        public Boolean cpqDetected;

        @InvocableVariable
        public Integer productCount;

        @InvocableVariable
        public Integer priceRuleCount;

        @InvocableVariable
        public Integer quoteCount;

        @InvocableVariable
        public Integer bundleDepth;

        @InvocableVariable
        public String complexityScore;

        @InvocableVariable
        public String scanSource;

        @InvocableVariable
        public String detectionMessage;

        @InvocableVariable
        public List<ScanFinding> scanFindings;

        @InvocableVariable
        public Boolean hasData;
    }

    public class ScanFinding {
        @InvocableVariable
        public String findingTitle;

        @InvocableVariable
        public String findingDetail;

        @InvocableVariable
        public String severity;

        public ScanFinding(String title, String detail, String severity) {
            this.findingTitle = title;
            this.findingDetail = detail;
            this.severity = severity;
        }
    }
}