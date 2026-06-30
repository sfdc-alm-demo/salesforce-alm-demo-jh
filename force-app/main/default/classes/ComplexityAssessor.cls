public with sharing class ComplexityAssessor {

    @InvocableMethod(label='Assess Complexity' description='Assesses CPQ complexity and recommends migration strategy (Net New Pilot, SI partners, implementation cost)')
    public static List<Response> assessComplexity(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded demo data
        res.hasData = true;

        // Determine complexity score
        res.complexityScore = determineComplexityScore(req.cpqComplexity);

        // Recommend strategy based on complexity
        res.recommendedStrategy = recommendStrategy(res.complexityScore);

        // Partner recommendations
        res.partnerRecommendations = generatePartnerRecommendations(res.complexityScore);

        // Implementation cost estimate
        res.implementationCost = estimateImplementationCost(res.complexityScore);

        // Net New Pilot benefit
        res.netNewPilotBenefit = 'Net New Pilot Strategy: Start RCA for NEW customers/contracts only, keep legacy CPQ running for existing customers\' upsells/renewals. ' +
                                 'Then migrate existing customers in Phase 2 after validating RCA with real revenue.\n\n' +
                                 '✅ Benefits:\n' +
                                 '• Reduces migration risk - prove RCA works before full cutover\n' +
                                 '• Faster time-to-value - new customers on modern platform immediately\n' +
                                 '• Parallel run period - compare CPQ vs RCA side-by-side\n' +
                                 '• Sales team confidence - early adopters become internal champions\n' +
                                 '• Finance approval easier - phased investment vs big-bang\n\n' +
                                 '📊 Real-World Example: Manufacturing company used Net New Pilot for 6 months, ' +
                                 'processed $2M in new business through RCA while maintaining $50M existing CPQ base. ' +
                                 'After success validation, migrated existing customers over 12 months.';

        return new List<Response>{ res };
    }

    private static String determineComplexityScore(String inputComplexity) {
        if (String.isNotBlank(inputComplexity)) {
            return inputComplexity;
        }
        // Default to moderate for demo
        return 'moderate';
    }

    private static String recommendStrategy(String complexityScore) {
        if (complexityScore.equalsIgnoreCase('simple')) {
            return 'Full Cutover (Recommended): Your CPQ implementation is simple enough for a direct cutover migration. ' +
                   'Estimated timeline: 3-4 months. Consider in-house implementation with Salesforce support.';
        } else if (complexityScore.equalsIgnoreCase('moderate')) {
            return 'Net New Pilot (Recommended): Start with RCA for new customers while keeping CPQ for existing base. ' +
                   'Pilot timeline: 4-6 months. Then migrate existing customers in waves over 6-9 months. ' +
                   'Consider SI partner for data migration and testing.';
        } else if (complexityScore.equalsIgnoreCase('complex')) {
            return 'Phased Migration (Recommended): Break migration into phases by region, product line, or business unit. ' +
                   'Phase 1: Simplest products/region (3-6 months). Phase 2+: Remaining products (12-18 months). ' +
                   'SI partner engagement strongly recommended.';
        } else if (complexityScore.equalsIgnoreCase('highly_complex')) {
            return 'SI Partner-Led Migration (Required): Your CPQ complexity requires expert SI partner engagement. ' +
                   'Recommend Net New Pilot strategy with dedicated implementation partner. ' +
                   'Timeline: 18-24 months for full migration. Budget for comprehensive discovery and custom migration tooling.';
        }
        return 'Net New Pilot (Default)';
    }

    private static List<Partner> generatePartnerRecommendations(String complexityScore) {
        List<Partner> partners = new List<Partner>();

        // IdeaHelix (tooling for all complexity levels)
        partners.add(new Partner(
            'IdeaHelix',
            'AppExchange ISV with CPQ→RCA conversion tooling. Automated product catalog, pricing rule, and configuration migration.',
            'Simple to Complex - Tool-based migration'
        ));

        if (complexityScore.equalsIgnoreCase('moderate') ||
            complexityScore.equalsIgnoreCase('complex') ||
            complexityScore.equalsIgnoreCase('highly_complex')) {

            partners.add(new Partner(
                'Forsys',
                'Deep CPQ→RCA migration expertise with proven methodology. Custom ETL, UAT frameworks, change management support.',
                'Moderate to Highly Complex'
            ));

            partners.add(new Partner(
                'Cloudality',
                'Revenue Cloud specialists with focus on manufacturing and B2B complex products. Asset lifecycle migration experts.',
                'Complex to Highly Complex'
            ));
        }

        if (complexityScore.equalsIgnoreCase('complex') || complexityScore.equalsIgnoreCase('highly_complex')) {
            partners.add(new Partner(
                'Fullpress',
                'Enterprise-scale RCA implementations with Fortune 500 experience. Multi-org, M&A, and global rollout specialists.',
                'Highly Complex - Enterprise'
            ));

            partners.add(new Partner(
                'Neocol',
                'Revenue Cloud and RevOps experts. Pricing optimization, quote-to-cash process redesign, Agentforce integration.',
                'Complex - RevOps Transformation'
            ));
        }

        if (complexityScore.equalsIgnoreCase('simple')) {
            partners.add(new Partner(
                'Salesforce Professional Services',
                'Salesforce in-house consulting for straightforward CPQ→RCA migrations with standard patterns.',
                'Simple to Moderate'
            ));
        }

        return partners;
    }

    private static String estimateImplementationCost(String complexityScore) {
        if (complexityScore.equalsIgnoreCase('simple')) {
            return '$50K - $150K\n\n' +
                   'Breakdown:\n' +
                   '• Discovery & Planning: $10K - $20K\n' +
                   '• Data Migration: $15K - $40K\n' +
                   '• Configuration & Testing: $20K - $60K\n' +
                   '• Training & Change Management: $5K - $30K\n\n' +
                   'Timeline: 3-4 months\n' +
                   'Team: 2-3 resources (1 Salesforce admin, 1-2 developers)';
        } else if (complexityScore.equalsIgnoreCase('moderate')) {
            return '$150K - $500K\n\n' +
                   'Breakdown:\n' +
                   '• Discovery & Planning: $30K - $75K\n' +
                   '• Data Migration & Tooling: $50K - $150K\n' +
                   '• Configuration & Custom Development: $40K - $180K\n' +
                   '• UAT & Testing: $20K - $60K\n' +
                   '• Training & Change Management: $10K - $35K\n\n' +
                   'Timeline: 6-9 months\n' +
                   'Team: 4-6 resources (1 PM, 1 architect, 2-3 developers, 1 QA)';
        } else if (complexityScore.equalsIgnoreCase('complex')) {
            return '$500K - $1.5M\n\n' +
                   'Breakdown:\n' +
                   '• Discovery & Architecture: $75K - $200K\n' +
                   '• Custom Migration Tooling: $100K - $300K\n' +
                   '• Data Migration & Validation: $120K - $400K\n' +
                   '• Configuration & Development: $100K - $350K\n' +
                   '• Comprehensive UAT: $50K - $150K\n' +
                   '• Training & Change Management: $30K - $100K\n' +
                   '• Integration Work (ERP): $25K - $100K\n\n' +
                   'Timeline: 12-18 months\n' +
                   'Team: 8-12 resources (1 exec sponsor, 1 PM, 2 architects, 4-6 developers, 2 QA, 1 change mgmt)';
        } else if (complexityScore.equalsIgnoreCase('highly_complex')) {
            return '$1.5M - $5M+\n\n' +
                   'Breakdown:\n' +
                   '• Discovery & Multi-Phase Planning: $200K - $500K\n' +
                   '• Enterprise Migration Platform: $300K - $1M\n' +
                   '• Data Migration (multi-org): $400K - $1.5M\n' +
                   '• Custom Development & Integration: $300K - $1M\n' +
                   '• Enterprise UAT & Validation: $150K - $500K\n' +
                   '• Global Training & Change Mgmt: $100K - $400K\n' +
                   '• ERP/External System Integration: $50K - $300K\n\n' +
                   'Timeline: 18-36 months (phased approach)\n' +
                   'Team: 15-25 resources (dedicated PMO, multiple workstreams)\n\n' +
                   '⚠️ This is the #1 customer objection. Counter with:\n' +
                   '• Net New Pilot reduces initial investment\n' +
                   '• CPQ→RCA promo (#CPQtoRLMpromo) eliminates double licensing\n' +
                   '• Cost of NOT migrating: Paying for End-of-Sale product with no R&D investment';
        }
        return '$150K - $500K (Typical)';
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable
        public String cpqComplexity;
    }

    public class Response {
        @InvocableVariable
        public String complexityScore;

        @InvocableVariable
        public String recommendedStrategy;

        @InvocableVariable
        public List<Partner> partnerRecommendations;

        @InvocableVariable
        public String implementationCost;

        @InvocableVariable
        public String netNewPilotBenefit;

        @InvocableVariable
        public Boolean hasData;
    }

    public class Partner {
        @InvocableVariable
        public String partnerName;

        @InvocableVariable
        public String specialization;

        @InvocableVariable
        public String complexity;

        public Partner(String name, String specialization, String complexity) {
            this.partnerName = name;
            this.specialization = specialization;
            this.complexity = complexity;
        }
    }
}