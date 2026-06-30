public with sharing class PricingProcedureAnalyzer {

    @InvocableMethod(label='Analyze Pricing Procedures' description='Maps legacy CPQ pricing rules to RCA Pricing Procedures (declarative price waterfall designer)')
    public static List<Response> analyzePricingProcedures(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded analysis
        res.rulesAnalyzed = 45;
        res.hasData = true;

        // Generate pricing procedures based on legacy system
        res.pricingProcedures = generatePricingProcedures(req.legacySystem, req.ruleComplexity);

        // Assess conversion complexity
        res.conversionComplexity = assessComplexity(req.ruleComplexity, req.attributeComplexity);

        // Attribute-based pricing warning
        res.attributeWarning = generateAttributeWarning(req.attributeComplexity);

        // Wow moment
        res.wowMoment = 'Drag-and-drop Pricing Procedure designer vs CPQ JavaScript pricing rules. Visualize your entire price waterfall: List Price → Volume Discounts → Promotions → Partner Discounts → Final Price. No code required!';

        return new List<Response>{ res };
    }

    private static List<PricingProcedure> generatePricingProcedures(String legacySystem, String ruleComplexity) {
        List<PricingProcedure> procedures = new List<PricingProcedure>();

        // Common pricing procedures
        procedures.add(new PricingProcedure(
            'Volume Discount Rule',
            'Volume Pricing Procedure',
            'Tiered discounts based on quantity: 1-10 units (0%), 11-50 (10%), 51+ (20%)',
            'Declarative'
        ));

        procedures.add(new PricingProcedure(
            'Partner Discount Rule',
            'Partner Channel Pricing',
            'Apply partner-level discounts based on partner tier (Gold 15%, Silver 10%, Bronze 5%)',
            'Declarative'
        ));

        procedures.add(new PricingProcedure(
            'Promotional Discount JavaScript',
            'Promotional Pricing Procedure',
            'Time-based promotional pricing with start/end dates and discount percentage',
            'Declarative'
        ));

        procedures.add(new PricingProcedure(
            'Contract Term Discount',
            'Term-Based Pricing Adjustment',
            'Annual contracts: 0%, 2-year: 10%, 3-year: 20% discount on list price',
            'Declarative'
        ));

        // System-specific procedures
        if (String.isNotBlank(legacySystem)) {
            if (legacySystem.containsIgnoreCase('Salesforce CPQ')) {
                procedures.add(new PricingProcedure(
                    'Price Rule with Custom Action',
                    'Custom Pricing Procedure Step',
                    'CPQ custom price actions → RCA custom pricing steps (Apex-backed when needed)',
                    'Hybrid (mostly declarative with optional Apex)'
                ));
            } else if (legacySystem.containsIgnoreCase('Oracle CPQ')) {
                procedures.add(new PricingProcedure(
                    'Oracle BML Pricing Logic',
                    'Complex Pricing Calculation',
                    'Oracle BML (Business Modeling Language) → RCA Pricing Procedure with formula fields',
                    'Declarative with formulas'
                ));
            } else if (legacySystem.containsIgnoreCase('SAP CPQ')) {
                procedures.add(new PricingProcedure(
                    'SAP Condition Tables',
                    'Condition-Based Pricing',
                    'SAP condition tables → RCA pricing conditions with attribute-based matching',
                    'Declarative'
                ));
            }
        }

        return procedures;
    }

    private static String assessComplexity(String ruleComplexity, String attributeComplexity) {
        if (String.isNotBlank(attributeComplexity) && attributeComplexity.equalsIgnoreCase('complex')) {
            return 'High - Complex attribute-based pricing requires careful migration planning';
        }

        if (String.isNotBlank(ruleComplexity)) {
            if (ruleComplexity.equalsIgnoreCase('complex')) {
                return 'High - Recommend SI partner engagement for complex pricing rule conversion';
            } else if (ruleComplexity.equalsIgnoreCase('moderate')) {
                return 'Medium - Straightforward conversion with some custom pricing steps';
            } else {
                return 'Low - Simple pricing rules convert cleanly to declarative Pricing Procedures';
            }
        }

        return 'Medium - Standard pricing rule conversion';
    }

    private static String generateAttributeWarning(String attributeComplexity) {
        if (String.isNotBlank(attributeComplexity) && attributeComplexity.equalsIgnoreCase('complex')) {
            return '⚠️ CRITICAL WARNING: Current RCA attribute-based pricing can suffer from rule proliferation. ' +
                   'Example: 5 attributes × 5 values = 25 pricing rules per product. ' +
                   'One customer had 35 attributes × 40+ choices, which became unusable. ' +
                   'The product team is redesigning this with a multi-dimensional pricing matrix (not GA yet). ' +
                   'For demos, stick to simpler attribute scenarios (2-3 attributes max).';
        }

        if (String.isNotBlank(attributeComplexity) && attributeComplexity.equalsIgnoreCase('moderate')) {
            return '⚠️ Note: Keep attribute-based pricing scenarios simple (2-3 attributes). ' +
                   'Complex attribute combinations can lead to rule proliferation. ' +
                   'A multi-dimensional pricing matrix is in development.';
        }

        return 'Attribute-based pricing is manageable at current complexity level.';
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable(required=true)
        public String legacySystem;

        @InvocableVariable
        public String ruleComplexity;

        @InvocableVariable
        public String attributeComplexity;
    }

    public class Response {
        @InvocableVariable
        public Integer rulesAnalyzed;

        @InvocableVariable
        public List<PricingProcedure> pricingProcedures;

        @InvocableVariable
        public String conversionComplexity;

        @InvocableVariable
        public String attributeWarning;

        @InvocableVariable
        public String wowMoment;

        @InvocableVariable
        public Boolean hasData;
    }

    public class PricingProcedure {
        @InvocableVariable
        public String cpqRuleName;

        @InvocableVariable
        public String rcaProcedureName;

        @InvocableVariable
        public String description;

        @InvocableVariable
        public String declarativeVsCode;

        public PricingProcedure(String cpqName, String rcaName, String descriptionText, String approach) {
            this.cpqRuleName = cpqName;
            this.rcaProcedureName = rcaName;
            this.description = descriptionText;
            this.declarativeVsCode = approach;
        }
    }
}