public with sharing class EnablementResourceProvider {

    @InvocableMethod(
        label='Get Enablement Resources'
        description='Returns tier-specific enablement resources (training, sales collateral, onboarding)'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;
            r.resources = buildResources(req.partnerTier, req.resourceType);
            r.resourceCount = r.resources.size();
            results.add(r);
        }

        return results;
    }

    private static List<EnablementResource> buildResources(String tier, String resourceType) {
        List<EnablementResource> all = new List<EnablementResource>();

        all.add(new EnablementResource(
            'Partner Onboarding 101',
            'onboarding',
            'Bronze',
            'https://partner.acme.com/onboarding/101',
            'Get started as a new partner: portal navigation, deal registration basics, escalation paths'
        ));
        all.add(new EnablementResource(
            'Product Overview Catalog',
            'sales_collateral',
            'Bronze',
            'https://partner.acme.com/collateral/product-overview.pdf',
            'High-level overview of all partner-sellable products with positioning and pricing'
        ));

        if (tier == 'Silver' || tier == 'Gold') {
            all.add(new EnablementResource(
                'Advanced Selling Techniques',
                'sales_collateral',
                'Silver',
                'https://partner.acme.com/training/advanced-selling',
                'Multi-stakeholder selling, objection handling, and deal acceleration tactics'
            ));
            all.add(new EnablementResource(
                'Deal Registration Best Practices Guide',
                'onboarding',
                'Silver',
                'https://partner.acme.com/playbooks/deal-reg.pdf',
                'How to register clean deals: avoid conflicts, qualify leads, accelerate approval'
            ));
            all.add(new EnablementResource(
                'ROI Justification Toolkit',
                'sales_collateral',
                'Silver',
                'https://partner.acme.com/tools/roi-calculator',
                'Customer-facing ROI calculator with pre-built business case templates'
            ));
        }

        if (tier == 'Gold') {
            all.add(new EnablementResource(
                'Enterprise Sales Strategy Playbook',
                'sales_collateral',
                'Gold',
                'https://partner.acme.com/playbooks/enterprise-strategy',
                'Executive engagement strategies for $500K+ enterprise deals'
            ));
            all.add(new EnablementResource(
                'Technical Deep Dive: Architecture and Integration',
                'technical_training',
                'Gold',
                'https://partner.acme.com/training/technical-deep-dive',
                'Solution architecture, API integration, custom extensibility patterns'
            ));
            all.add(new EnablementResource(
                'Executive Sponsor Program Access',
                'onboarding',
                'Gold',
                'https://partner.acme.com/programs/exec-sponsor',
                'Direct access to executives for strategic deal support and joint planning'
            ));
        }

        if (String.isNotBlank(resourceType) && !resourceType.equalsIgnoreCase('all')) {
            List<EnablementResource> filtered = new List<EnablementResource>();
            for (EnablementResource er : all) {
                if (er.resourceType.equalsIgnoreCase(resourceType)) {
                    filtered.add(er);
                }
            }
            return filtered;
        }
        return all;
    }

    public class Request {
        @InvocableVariable
        public String partnerTier;

        @InvocableVariable
        public String resourceType;
    }

    public class Result {
        @InvocableVariable
        public List<EnablementResource> resources;

        @InvocableVariable
        public Decimal resourceCount;

        @InvocableVariable
        public Boolean hasData;
    }

    public class EnablementResource {
        @InvocableVariable
        public String resourceTitle;

        @InvocableVariable
        public String resourceType;

        @InvocableVariable
        public String tierRequired;

        @InvocableVariable
        public String url;

        @InvocableVariable
        public String resourceDescription;

        public EnablementResource(String title, String rType, String tier, String urlVal, String descText) {
            this.resourceTitle = title;
            this.resourceType = rType;
            this.tierRequired = tier;
            this.url = urlVal;
            this.resourceDescription = descText;
        }
    }
}