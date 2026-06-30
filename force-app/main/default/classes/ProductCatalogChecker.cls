public with sharing class ProductCatalogChecker {

    @InvocableMethod(label='Check Product Catalog' description='Demonstrates Product Catalog Management (PCM) capabilities and migration from CPQ product/bundle structure')
    public static List<Response> checkProductCatalog(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded sample data
        res.productCount = 50;
        res.hasData = true;

        // Build catalog structure JSON
        res.catalogStructure = buildCatalogStructure(req.industry);

        // Generate migration tips based on industry
        res.migrationTips = generateMigrationTips(req.industry, req.catalogType);

        // RCA standard objects
        res.rcaObjects = getRCAObjects();

        return new List<Response>{ res };
    }

    private static String buildCatalogStructure(String industry) {
        String structureJson = '{\n';
        structureJson += '  "catalogName": "' + (String.isNotBlank(industry) ? industry : 'Enterprise') + ' Product Catalog",\n';
        structureJson += '  "structure": "attribute-based",\n';
        structureJson += '  "personaViews": [\n';
        structureJson += '    {"persona": "Product Manager", "access": "full_edit"},\n';
        structureJson += '    {"persona": "Sales Rep", "access": "read_only"},\n';
        structureJson += '    {"persona": "Pricing Admin", "access": "pricing_edit"}\n';
        structureJson += '  ],\n';
        structureJson += '  "sampleProducts": [\n';
        structureJson += '    {"name": "Enterprise License", "type": "subscription", "attributes": ["user_count", "tier_level"]},\n';
        structureJson += '    {"name": "Professional Services", "type": "one_time", "attributes": ["hours", "consultant_level"]},\n';
        structureJson += '    {"name": "Platform Credits", "type": "consumption", "attributes": ["credit_amount", "expiration"]}\n';
        structureJson += '  ]\n';
        structureJson += '}';
        return structureJson;
    }

    private static List<MigrationTip> generateMigrationTips(String industry, String catalogType) {
        List<MigrationTip> tips = new List<MigrationTip>();

        // Universal tip
        tips.add(new MigrationTip(
            'Use Attribute-Based Modeling',
            'RCA uses attribute-based product modeling instead of CPQ\'s custom fields approach. This reduces product SKU proliferation.',
            'High'
        ));

        // Industry-specific tips
        if (String.isNotBlank(industry)) {
            if (industry.containsIgnoreCase('Manufacturing')) {
                tips.add(new MigrationTip(
                    'Complex Configuration Support',
                    'Manufacturing products with complex configurations work well in RCA\'s PCM with asset lifecycle tracking for maintenance and parts.',
                    'High'
                ));
                tips.add(new MigrationTip(
                    'Multi-Channel Selling',
                    'RCA supports direct sales, partner channels, and self-service from one unified product catalog.',
                    'Medium'
                ));
            } else if (industry.containsIgnoreCase('Technology') || industry.containsIgnoreCase('SaaS')) {
                tips.add(new MigrationTip(
                    'Subscription Bundle Modeling',
                    'Model SaaS subscription tiers (Starter, Professional, Enterprise) as product bundles with tiered pricing.',
                    'High'
                ));
                tips.add(new MigrationTip(
                    'Usage-Based Products',
                    'RCA handles consumption-based products (API calls, storage, compute) with built-in usage tracking.',
                    'Medium'
                ));
            } else if (industry.containsIgnoreCase('Financial') || industry.containsIgnoreCase('Fintech')) {
                tips.add(new MigrationTip(
                    'Payment Product Modeling',
                    'Financial services products (payment processing, merchant accounts) map cleanly to RCA\'s asset-based model.',
                    'High'
                ));
                tips.add(new MigrationTip(
                    'Partner Channel Products',
                    'Dojo (UK fintech) successfully migrated partner channel products to RCA with full GTM transformation.',
                    'Medium'
                ));
            }
        }

        // Catalog type specific tip
        if (String.isNotBlank(catalogType)) {
            if (catalogType.equalsIgnoreCase('B2B')) {
                tips.add(new MigrationTip(
                    'B2B Product Hierarchy',
                    'Leverage RCA\'s hierarchical catalog structure for complex B2B product relationships and dependencies.',
                    'Medium'
                ));
            } else if (catalogType.equalsIgnoreCase('B2C')) {
                tips.add(new MigrationTip(
                    'Headless Commerce Support',
                    'Use RCA Connect APIs for headless B2C storefronts while maintaining catalog in Salesforce.',
                    'High'
                ));
            }
        }

        return tips;
    }

    private static List<RCAObject> getRCAObjects() {
        List<RCAObject> objects = new List<RCAObject>();

        objects.add(new RCAObject(
            'ProductCatalog',
            'Container for organizing products by business unit, region, or product line',
            'ProductCatalog'
        ));

        objects.add(new RCAObject(
            'Product2',
            'Standard Salesforce product object - on-core, not in a managed package',
            'Product2'
        ));

        objects.add(new RCAObject(
            'ProductAttribute',
            'Defines configurable attributes (size, color, tier) for attribute-based pricing',
            'ProductAttribute'
        ));

        objects.add(new RCAObject(
            'ProductAttributeSet',
            'Groups related attributes together for easier management',
            'ProductAttributeSet'
        ));

        return objects;
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable
        public String industry;

        @InvocableVariable
        public String catalogType;
    }

    public class Response {
        @InvocableVariable
        public Integer productCount;

        @InvocableVariable
        public String catalogStructure;

        @InvocableVariable
        public List<MigrationTip> migrationTips;

        @InvocableVariable
        public List<RCAObject> rcaObjects;

        @InvocableVariable
        public Boolean hasData;
    }

    public class MigrationTip {
        @InvocableVariable
        public String tipTitle;

        @InvocableVariable
        public String tipDescription;

        @InvocableVariable
        public String priority;

        public MigrationTip(String title, String description, String priority) {
            this.tipTitle = title;
            this.tipDescription = description;
            this.priority = priority;
        }
    }

    public class RCAObject {
        @InvocableVariable
        public String objectName;

        @InvocableVariable
        public String objectDescription;

        @InvocableVariable
        public String apiName;

        public RCAObject(String name, String description, String api) {
            this.objectName = name;
            this.objectDescription = description;
            this.apiName = api;
        }
    }
}