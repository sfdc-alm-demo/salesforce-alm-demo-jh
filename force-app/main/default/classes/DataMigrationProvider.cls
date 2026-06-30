public with sharing class DataMigrationProvider {

    @InvocableMethod(label='Get Migration Tools' description='Provides data migration tools and partner resources (IdeaHelix, Prodly, Forsys)')
    public static List<Response> getMigrationTools(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded demo data
        res.hasData = true;

        // Official migration guide URL
        res.migrationGuideURL = 'https://help.salesforce.com/s/articleView?id=sf.revenue_cloud_cpq_migration_guide.htm';

        // Generate migration tools
        res.migrationTools = generateMigrationTools(req.dataType);

        // UAT challenges
        res.uatChallenges = generateUATChallenges();

        return new List<Response>{ res };
    }

    private static List<MigrationTool> generateMigrationTools(String dataType) {
        List<MigrationTool> tools = new List<MigrationTool>();

        tools.add(new MigrationTool(
            'IdeaHelix CPQ→RCA Converter',
            'ISV AppExchange tool for automated CPQ product catalog, pricing rules, and configuration migration to RCA data model',
            'Product Catalog: Converts CPQ Product2, PricebookEntry, Product Options → RCA ProductCatalog, ProductAttribute\n' +
            'Pricing Rules: Converts CPQ Price Rules → RCA Pricing Procedures\n' +
            'Configuration: Converts CPQ Product Features/Options → RCA Product Bundles',
            'https://appexchange.salesforce.com/ideahelix'
        ));

        tools.add(new MigrationTool(
            'Prodly DevOps',
            'Data migration and release management platform for complex Salesforce implementations',
            'CPQ Data Migration: Quote data, order history, contract data\n' +
            'Sandbox Seeding: Populate test environments with realistic data\n' +
            'Version Control: Track changes across environments during migration',
            'https://prodly.co'
        ));

        tools.add(new MigrationTool(
            'Forsys Migration Services',
            'SI partner with deep CPQ→RCA migration expertise and proven methodologies',
            'Assessment: CPQ complexity scoring and migration roadmap\n' +
            'Data Migration: Custom ETL for complex CPQ data models\n' +
            'Testing: Comprehensive UAT framework for CPQ→RCA validation',
            'https://forsys.com/salesforce-revenue-cloud'
        ));

        tools.add(new MigrationTool(
            'Salesforce Data Loader',
            'Official Salesforce tool for bulk data import/export',
            'Quote Line Items: Export CPQ QuoteLineItems → Transform → Import RCA OrderItems\n' +
            'Product Data: Export CPQ Product2 → Map to RCA ProductCatalog\n' +
            'Historical Data: Migrate historical quote/order data for reporting',
            'https://help.salesforce.com/s/articleView?id=sf.data_loader.htm'
        ));

        if (String.isNotBlank(dataType) && dataType.equalsIgnoreCase('quote_data')) {
            tools.add(new MigrationTool(
                'Custom Apex Migration Script',
                'Salesforce Apex batch job for quote data transformation',
                'Quote Conversion: CPQ Quote → RCA Order/Quote\n' +
                'Line Item Mapping: CPQ QuoteLineItem → RCA OrderItem\n' +
                'Price Calculation: Re-run pricing procedures to validate accuracy',
                'Custom development required'
            ));
        }

        return tools;
    }

    private static List<UATChallenge> generateUATChallenges() {
        List<UATChallenge> challenges = new List<UATChallenge>();

        challenges.add(new UATChallenge(
            'Quote Line Item Data Import Failures',
            'CPQ QuoteLineItem data model differs from RCA OrderItem schema, causing import errors',
            '1. Use IdeaHelix converter for automated field mapping\n' +
            '2. Create custom transformation scripts for complex CPQ fields\n' +
            '3. Import in phases: Products first, then line items with FK references\n' +
            '4. Validate pricing calculations match CPQ output before go-live'
        ));

        challenges.add(new UATChallenge(
            'Sandbox Data Availability',
            'Production CPQ data not available in sandbox environments for UAT testing',
            '1. Use Prodly to clone production CPQ data to Full Copy sandbox\n' +
            '2. Create synthetic test data that mirrors production CPQ complexity\n' +
            '3. Partner with customer IT to request sandbox data refresh\n' +
            '4. Anonymize production data (GDPR compliance) before sandbox import'
        ));

        challenges.add(new UATChallenge(
            'Pricing Discrepancies Between CPQ and RCA',
            'RCA pricing calculations produce different results than legacy CPQ for same inputs',
            '1. Document CPQ custom price rules and validate RCA equivalents\n' +
            '2. Test side-by-side: Same quote in CPQ vs RCA, compare line by line\n' +
            '3. Identify rounding differences, discount order-of-operations issues\n' +
            '4. Create reconciliation report for finance team approval'
        ));

        challenges.add(new UATChallenge(
            'Amendment and Renewal Scenario Testing',
            'Complex amendment scenarios (MDQ, negative amendments, mid-term cancellations) not working in RCA',
            '1. This is WHY you\'re migrating - CPQ chokes on these scenarios\n' +
            '2. Build comprehensive amendment test suite (50+ scenarios)\n' +
            '3. Focus on scenarios that FAILED in CPQ but should work in RCA\n' +
            '4. Document "wow moments" where RCA handles cases CPQ could not'
        ));

        challenges.add(new UATChallenge(
            'Integration Testing with ERP Systems',
            'Order activation in RCA not triggering expected ERP integration',
            '1. Verify RCA Order → ERP integration patterns match CPQ flows\n' +
            '2. Test MuleSoft/middleware connections with RCA APIs\n' +
            '3. Validate order payload format matches ERP expectations\n' +
            '4. Check authentication/authorization for RCA Connect APIs'
        ));

        challenges.add(new UATChallenge(
            'User Training and Change Management',
            'Sales reps struggle with RCA UI differences from familiar CPQ interface',
            '1. Build side-by-side comparison training: "CPQ → RCA equivalent"\n' +
            '2. Create quick reference guides for common tasks (quote, amend, renew)\n' +
            '3. Leverage Quoting Agent to simplify UX (natural language quoting)\n' +
            '4. Run pilot with early adopter sales team before full rollout'
        ));

        return challenges;
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable
        public String dataType;
    }

    public class Response {
        @InvocableVariable
        public String migrationGuideURL;

        @InvocableVariable
        public List<MigrationTool> migrationTools;

        @InvocableVariable
        public List<UATChallenge> uatChallenges;

        @InvocableVariable
        public Boolean hasData;
    }

    public class MigrationTool {
        @InvocableVariable
        public String partnerName;

        @InvocableVariable
        public String toolDescription;

        @InvocableVariable
        public String capabilities;

        @InvocableVariable
        public String url;

        public MigrationTool(String name, String description, String capabilities, String url) {
            this.partnerName = name;
            this.toolDescription = description;
            this.capabilities = capabilities;
            this.url = url;
        }
    }

    public class UATChallenge {
        @InvocableVariable
        public String challengeTitle;

        @InvocableVariable
        public String description;

        @InvocableVariable
        public String mitigation;

        public UATChallenge(String title, String description, String mitigation) {
            this.challengeTitle = title;
            this.description = description;
            this.mitigation = mitigation;
        }
    }
}