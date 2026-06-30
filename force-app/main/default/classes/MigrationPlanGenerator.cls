public with sharing class MigrationPlanGenerator {

    @InvocableMethod(label='Generate Migration Plan' description='Generates a phased migration roadmap and field mapping table based on scanner findings (product/rule counts, complexity, industry).')
    public static List<Response> generatePlan(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();
        res.hasData = true;

        String complexity = String.isNotBlank(req.complexityScore) ? req.complexityScore : 'moderate';
        Integer productCount = req.productCount != null ? req.productCount : defaultProductCount(complexity);
        Integer ruleCount = req.priceRuleCount != null ? req.priceRuleCount : defaultRuleCount(complexity);

        res.recommendedApproach = recommendApproach(complexity, productCount, ruleCount);
        res.phases = buildPhases(complexity, req.industry);
        res.fieldMappings = buildFieldMappings(req.industry);
        res.timelineEstimate = estimateTimeline(complexity);
        res.keyRisks = buildKeyRisks(complexity, productCount, ruleCount);

        return new List<Response>{ res };
    }

    private static Integer defaultProductCount(String complexity) {
        if (complexity.equalsIgnoreCase('simple')) return 30;
        if (complexity.equalsIgnoreCase('moderate')) return 100;
        if (complexity.equalsIgnoreCase('complex')) return 250;
        if (complexity.equalsIgnoreCase('highly_complex')) return 500;
        return 100;
    }

    private static Integer defaultRuleCount(String complexity) {
        if (complexity.equalsIgnoreCase('simple')) return 10;
        if (complexity.equalsIgnoreCase('moderate')) return 30;
        if (complexity.equalsIgnoreCase('complex')) return 60;
        if (complexity.equalsIgnoreCase('highly_complex')) return 120;
        return 30;
    }

    private static String recommendApproach(String complexity, Integer productCount, Integer ruleCount) {
        if (complexity.equalsIgnoreCase('simple')) {
            return 'Full Cutover: Your scanned configuration is small enough for a direct migration. ' +
                   'Recommend in-house implementation with Salesforce support over 3-4 months.';
        } else if (complexity.equalsIgnoreCase('moderate')) {
            return 'Net New Pilot: Start RCA for new customers while keeping CPQ for existing base. ' +
                   'Pilot for 4-6 months, then migrate existing customers in waves over 6-9 months. ' +
                   'Engage SI partner for data migration and pricing rule conversion.';
        } else if (complexity.equalsIgnoreCase('complex')) {
            return 'Phased Migration: Break into phases by region, product line, or business unit. ' +
                   'Phase 1 covers simplest products (3-6 months). Subsequent phases over 12-18 months. ' +
                   'SI partner engagement strongly recommended.';
        } else if (complexity.equalsIgnoreCase('highly_complex')) {
            return 'SI Partner-Led: Your configuration requires expert engagement. ' +
                   'Net New Pilot with dedicated SI partner. Timeline 18-24 months. ' +
                   'Budget for comprehensive discovery and custom migration tooling.';
        }
        return 'Net New Pilot (default recommendation pending scan data).';
    }

    private static List<Phase> buildPhases(String complexity, String industry) {
        List<Phase> phases = new List<Phase>();

        phases.add(new Phase(
            1,
            'Discovery & Assessment',
            'Inventory products, pricing rules, custom Apex/JS plugins, ERP integrations. Baseline current CPQ behavior. Document business-critical scenarios.',
            complexity.equalsIgnoreCase('highly_complex') ? '6-8 weeks' : '3-4 weeks'
        ));

        phases.add(new Phase(
            2,
            'Architecture & Design',
            'Map CPQ Product2/Bundle hierarchy to RCA ProductCatalog/ProductAttribute model. Design Pricing Procedures replacing legacy rules. Plan ERP integration via Connect APIs.',
            complexity.equalsIgnoreCase('highly_complex') ? '8-12 weeks' : '4-6 weeks'
        ));

        phases.add(new Phase(
            3,
            'Build & Configure',
            'Provision RCA in target org. Build product catalog, configure Pricing Procedures, implement Asset Lifecycle. Develop required custom Apex extensions.',
            complexity.equalsIgnoreCase('highly_complex') ? '16-24 weeks' : '8-12 weeks'
        ));

        phases.add(new Phase(
            4,
            'Data Migration & UAT',
            'Run migration scripts (IdeaHelix or custom Apex batch). Side-by-side reconciliation between CPQ and RCA. Amendment / renewal scenario testing. Finance sign-off.',
            complexity.equalsIgnoreCase('highly_complex') ? '12-16 weeks' : '6-8 weeks'
        ));

        phases.add(new Phase(
            5,
            'Cutover & Hypercare',
            'Decommission CPQ for migrated cohort. Sales training, hypercare support, monitor pricing accuracy. Plan next migration wave.',
            '4-6 weeks'
        ));

        if (String.isNotBlank(industry)) {
            phases.add(new Phase(
                6,
                industry + '-Specific Validation',
                'Validate industry-specific scenarios (e.g., Manufacturing: complex configurations; SaaS: subscription ramps; Fintech: partner channel pricing). Engage industry SME from SI partner.',
                '2-4 weeks'
            ));
        }

        return phases;
    }

    private static List<FieldMapping> buildFieldMappings(String industry) {
        List<FieldMapping> mappings = new List<FieldMapping>();

        mappings.add(new FieldMapping(
            'SBQQ__Product__c',
            'Product2 + ProductCatalog membership',
            'Direct map. Custom fields become ProductAttribute entries. Bundles remodel as ProductRelationship.'
        ));

        mappings.add(new FieldMapping(
            'SBQQ__PriceRule__c',
            'PricingProcedure + PricingProcedureStep',
            'Conditions become Pricing Procedure entry criteria. Actions become declarative steps. Custom Apex actions need manual conversion.'
        ));

        mappings.add(new FieldMapping(
            'SBQQ__ProductOption__c',
            'ProductRelatedComponent',
            'Bundle option hierarchy maps to RCA component model. Use attribute-based pricing for option-driven price changes.'
        ));

        mappings.add(new FieldMapping(
            'SBQQ__Quote__c',
            'Quote (standard) + Order',
            'CPQ Quote becomes standard Salesforce Quote. Activated quote becomes Order. Asset records track customer ownership state.'
        ));

        mappings.add(new FieldMapping(
            'SBQQ__QuoteLine__c',
            'QuoteLineItem + OrderItem',
            'Quote lines map to standard QuoteLineItem. On activation, OrderItem records are created. Asset tracking begins at activation.'
        ));

        mappings.add(new FieldMapping(
            'SBQQ__Subscription__c',
            'Asset + AssetAction',
            'Subscriptions become Assets. Lifecycle changes (amend/renew/cancel) tracked via AssetAction records, providing full history.'
        ));

        return mappings;
    }

    private static String estimateTimeline(String complexity) {
        if (complexity.equalsIgnoreCase('simple')) {
            return '3-4 months total. Suitable for in-house team with Salesforce support.';
        } else if (complexity.equalsIgnoreCase('moderate')) {
            return '6-9 months total. Requires SI partner for data migration and rule conversion.';
        } else if (complexity.equalsIgnoreCase('complex')) {
            return '12-18 months total (phased). SI partner engagement strongly recommended.';
        } else if (complexity.equalsIgnoreCase('highly_complex')) {
            return '18-24 months total (multi-phase). Dedicated SI partner with proven Revenue Cloud track record required.';
        }
        return '6-9 months estimated (refine after detailed scan).';
    }

    private static List<Risk> buildKeyRisks(String complexity, Integer productCount, Integer ruleCount) {
        List<Risk> risks = new List<Risk>();

        risks.add(new Risk(
            'Reimplementation, Not Lift-and-Shift',
            'CPQ is a managed package with its own data model; RCA is on-core with a different model. Set this expectation with stakeholders early.',
            'Treat the project as a reimplementation. Budget for design and rebuild, not a copy-paste migration.'
        ));

        if (ruleCount > 30) {
            risks.add(new Risk(
                'Pricing Rule Conversion Volume',
                ruleCount + ' price rules detected. Custom Apex price actions and complex JavaScript pricing will not auto-convert.',
                'Inventory each rule and classify as auto-convertible (declarative) vs manual rebuild. Engage SI partner for the manual cohort.'
            ));
        }

        if (productCount > 200) {
            risks.add(new Risk(
                'Product Catalog Size',
                productCount + ' products detected. Re-modeling as attribute-based PCM is non-trivial at this scale.',
                'Phase the catalog migration by product line. Validate each phase end-to-end before starting the next.'
            ));
        }

        risks.add(new Risk(
            'Amendment & Renewal Edge Cases',
            'CPQ amendment/renewal flows often have edge cases customers depend on. RCA handles these differently via Asset Lifecycle.',
            'Build a comprehensive amendment test suite (50+ scenarios) covering negative amendments, mid-term cancellations, multi-year ramps.'
        ));

        risks.add(new Risk(
            'Agentforce Forcing Function',
            'Legacy CPQ cannot support Agentforce. If Agentforce is on the customer roadmap, RCA migration is on the critical path.',
            'Surface Agentforce timing as part of the business case. Sequence the migration to unblock AI initiatives.'
        ));

        if (complexity.equalsIgnoreCase('highly_complex')) {
            risks.add(new Risk(
                'Implementation Cost',
                'Highly complex migrations land in the $1.5M-$5M+ range. This is the #1 customer objection.',
                'Pair with the #CPQtoRLMpromo (CPQ spend converts to RCA, eliminates double licensing). Use Net New Pilot to phase investment.'
            ));
        }

        return risks;
    }

    public class Request {
        @InvocableVariable
        public String complexityScore;

        @InvocableVariable
        public Integer productCount;

        @InvocableVariable
        public Integer priceRuleCount;

        @InvocableVariable
        public String industry;

        @InvocableVariable
        public String legacySystem;
    }

    public class Response {
        @InvocableVariable
        public String recommendedApproach;

        @InvocableVariable
        public List<Phase> phases;

        @InvocableVariable
        public List<FieldMapping> fieldMappings;

        @InvocableVariable
        public String timelineEstimate;

        @InvocableVariable
        public List<Risk> keyRisks;

        @InvocableVariable
        public Boolean hasData;
    }

    public class Phase {
        @InvocableVariable
        public Integer phaseNumber;

        @InvocableVariable
        public String phaseName;

        @InvocableVariable
        public String phaseDescription;

        @InvocableVariable
        public String duration;

        public Phase(Integer num, String name, String description, String duration) {
            this.phaseNumber = num;
            this.phaseName = name;
            this.phaseDescription = description;
            this.duration = duration;
        }
    }

    public class FieldMapping {
        @InvocableVariable
        public String cpqObject;

        @InvocableVariable
        public String rcaTarget;

        @InvocableVariable
        public String mappingNotes;

        public FieldMapping(String cpq, String rca, String notes) {
            this.cpqObject = cpq;
            this.rcaTarget = rca;
            this.mappingNotes = notes;
        }
    }

    public class Risk {
        @InvocableVariable
        public String riskTitle;

        @InvocableVariable
        public String riskDescription;

        @InvocableVariable
        public String mitigation;

        public Risk(String title, String description, String mitigation) {
            this.riskTitle = title;
            this.riskDescription = description;
            this.mitigation = mitigation;
        }
    }
}