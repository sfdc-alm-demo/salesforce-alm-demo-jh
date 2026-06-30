public with sharing class ERPIntegrationChecker {

    @InvocableMethod(label='Check ERP Integration' description='Demonstrates ERP integration patterns (NetSuite, SAP, Oracle) with RCA API-first architecture')
    public static List<Response> checkERPIntegration(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded demo data
        res.hasData = true;

        // Generate integration patterns
        res.integrationPatterns = generateIntegrationPatterns(req.erpSystem);

        // MuleSoft guidance
        res.mulesoftGuidance = 'MuleSoft Anypoint Platform serves as the middleware orchestration layer for RCA → ERP integrations:\n\n' +
                               '1. **API-Led Connectivity**: System APIs (RCA, ERP) → Process APIs (order fulfillment) → Experience APIs (mobile, portal)\n' +
                               '2. **Real-Time Order Sync**: RCA Order Activation triggers MuleSoft flow → Transform to ERP format → Post to ERP\n' +
                               '3. **Error Handling**: Retry logic, dead letter queue, notification to ops team on failure\n' +
                               '4. **Monitoring**: Anypoint Monitoring tracks RCA→ERP transaction volume, latency, errors\n' +
                               '5. **Pre-Built Connectors**: MuleSoft connectors available for NetSuite, SAP, Oracle, Dynamics\n\n' +
                               'Alternative: Point-to-point integration using RCA Connect APIs (simpler for single ERP)';

        // API advantage
        res.apiAdvantage = '🚀 RCA API-First Architecture vs CPQ Managed Package:\n\n' +
                           '**CPQ (Legacy):**\n' +
                           '- Managed package limits API access to certain objects\n' +
                           '- Custom integrations require workarounds (remote site settings, middleware)\n' +
                           '- Governor limits hit faster due to package namespace overhead\n' +
                           '- Upgrades can break custom integrations\n\n' +
                           '**RCA (Modern):**\n' +
                           '- Native Salesforce objects = full API access\n' +
                           '- Standard REST/SOAP APIs work out of the box\n' +
                           '- Connect Commerce APIs designed for headless integration\n' +
                           '- No managed package namespace = cleaner integration code\n' +
                           '- Bulk API 2.0 support for high-volume data sync\n\n' +
                           '💡 Result: ERP integrations are simpler, faster, and more maintainable with RCA';

        return new List<Response>{ res };
    }

    private static List<IntegrationPattern> generateIntegrationPatterns(String erpSystem) {
        List<IntegrationPattern> patterns = new List<IntegrationPattern>();

        // NetSuite patterns
        if (String.isBlank(erpSystem) || erpSystem.containsIgnoreCase('NetSuite')) {
            patterns.add(new IntegrationPattern(
                'NetSuite',
                'RCA Order Activation → MuleSoft → NetSuite Sales Order creation with line items, pricing, customer info',
                'MuleSoft Anypoint or custom REST API integration',
                'Customer orders 100 licenses in RCA → Order activates → NetSuite Sales Order SO-12345 created → Triggers NetSuite fulfillment workflow'
            ));

            patterns.add(new IntegrationPattern(
                'NetSuite (Invoice Sync)',
                'NetSuite Invoice created → Webhook to RCA → Update RCA Invoice record with NetSuite Invoice ID',
                'NetSuite SuiteScript webhook + RCA REST API',
                'NetSuite generates invoice INV-56789 → RCA Invoice record updated with external reference for reconciliation'
            ));
        }

        // SAP patterns
        if (String.isBlank(erpSystem) || erpSystem.containsIgnoreCase('SAP')) {
            patterns.add(new IntegrationPattern(
                'SAP',
                'RCA Order → SAP ECC/S4HANA Sales Order (BAPI_SALESORDER_CREATEFROMDAT2)',
                'MuleSoft SAP Connector or SAP PI/PO middleware',
                'Enterprise customer orders $500K deal in RCA → SAP Sales Order created in ECC → SAP SD/FI modules process billing'
            ));

            patterns.add(new IntegrationPattern(
                'SAP (Material Master Sync)',
                'SAP Material Master (products) → Sync to RCA Product Catalog nightly via batch job',
                'SAP IDoc or RFC → MuleSoft → RCA Bulk API',
                'New product launched in SAP → Overnight sync → Product appears in RCA catalog for sales reps next day'
            ));
        }

        // Oracle patterns
        if (String.isBlank(erpSystem) || erpSystem.containsIgnoreCase('Oracle')) {
            patterns.add(new IntegrationPattern(
                'Oracle EBS',
                'RCA Order → Oracle Order Management (OM) via Oracle Integration Cloud (OIC)',
                'Oracle Integration Cloud or custom SOAP/REST',
                'Customer places order in RCA → OIC transforms to Oracle OM format → Order created in Oracle EBS for fulfillment'
            ));

            patterns.add(new IntegrationPattern(
                'Oracle Financials (AR/GL)',
                'RCA Invoice → Oracle Receivables (AR) for payment tracking and GL posting',
                'Oracle Integration Cloud + RCA Connect API',
                'RCA generates invoice → Posted to Oracle AR as customer receivable → GL entry for revenue recognition'
            ));
        }

        // Microsoft Dynamics
        if (String.isBlank(erpSystem) || erpSystem.containsIgnoreCase('Dynamics') || erpSystem.containsIgnoreCase('Microsoft')) {
            patterns.add(new IntegrationPattern(
                'Microsoft Dynamics 365',
                'RCA Order → Dynamics 365 Sales Order via Microsoft Power Automate or Azure Logic Apps',
                'Power Automate + Salesforce Connector',
                'RCA order placed → Power Automate flow triggered → Dynamics 365 Sales Order created with line items'
            ));
        }

        // Generic pattern (always include)
        patterns.add(new IntegrationPattern(
            'Generic ERP (API-First Pattern)',
            'RCA Platform Event (OrderActivated) → Listen via Salesforce Streaming API → Transform → POST to ERP REST API',
            'Custom middleware or event-driven architecture',
            'Works with any modern ERP exposing REST APIs (Acumatica, Epicor, IFS, etc.)'
        ));

        return patterns;
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable
        public String erpSystem;
    }

    public class Response {
        @InvocableVariable
        public List<IntegrationPattern> integrationPatterns;

        @InvocableVariable
        public String mulesoftGuidance;

        @InvocableVariable
        public String apiAdvantage;

        @InvocableVariable
        public Boolean hasData;
    }

    public class IntegrationPattern {
        @InvocableVariable
        public String erpName;

        @InvocableVariable
        public String patternDescription;

        @InvocableVariable
        public String middleware;

        @InvocableVariable
        public String example;

        public IntegrationPattern(String name, String description, String middleware, String example) {
            this.erpName = name;
            this.patternDescription = description;
            this.middleware = middleware;
            this.example = example;
        }
    }
}