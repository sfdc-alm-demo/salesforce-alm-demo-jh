public with sharing class UXComponentProvider {

    @InvocableMethod(label='Get UX Components' description='Provides UI/UX components for unified sales experience (Lightning Web Components, Flows, Agentforce for Revenue)')
    public static List<Response> getUXComponents(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded demo data
        res.hasData = true;

        // Generate components based on type
        res.components = generateComponents(req.componentType);

        // Implementation guide
        res.implementationGuide = generateImplementationGuide(req.componentType);

        // Quoting Agent demo
        res.quotingAgentDemo = '🤖 Agentforce Quoting Agent Demo:\n\n' +
                               'Sales Rep: "Quote 25 Enterprise licenses with a 10% discount for Acme Corp"\n\n' +
                               'Agent Response: "I\'ve created a quote for Acme Corp:\n' +
                               '- Product: Enterprise License\n' +
                               '- Quantity: 25\n' +
                               '- List Price: $500/user/month\n' +
                               '- Discount: 10% ($50/user)\n' +
                               '- Final Price: $450/user/month\n' +
                               '- Annual Total: $135,000\n\n' +
                               'Quote QUOT-00125 created and ready for review."\n\n' +
                               '⏱️ Time Saved: 75% reduction (3 minutes → 45 seconds)\n' +
                               '✨ No manual data entry, no navigating multiple screens';

        // Connect APIs
        res.connectAPIs = generateConnectAPIs();

        return new List<Response>{ res };
    }

    private static List<Component> generateComponents(String componentType) {
        List<Component> components = new List<Component>();

        if (String.isBlank(componentType) || componentType.equalsIgnoreCase('lightning')) {
            components.add(new Component(
                'rcaQuoteBuilder',
                'Lightning Web Component',
                'Visual quote builder with drag-and-drop product selection and real-time pricing',
                'Sales reps build quotes visually, see pricing update in real-time as products are added'
            ));

            components.add(new Component(
                'rcaAssetViewer',
                'Lightning Web Component',
                'Customer asset viewer showing what customer owns, contract terms, and renewal dates',
                'Account managers see complete customer ownership state for upsell/renewal conversations'
            ));

            components.add(new Component(
                'rcaPriceWaterfall',
                'Lightning Web Component',
                'Visual price waterfall showing list price → discounts → final price breakdown',
                'CFOs and pricing managers visualize price waterfall for pricing governance'
            ));
        }

        if (String.isBlank(componentType) || componentType.equalsIgnoreCase('flow')) {
            components.add(new Component(
                'RCA Quote Approval Flow',
                'Screen Flow',
                'Automated quote approval routing based on discount percentage and deal size',
                'Quotes under $50K auto-approve, $50K-$500K require manager, $500K+ require VP'
            ));

            components.add(new Component(
                'RCA Amendment Flow',
                'Screen Flow',
                'Guided amendment process for adding products, changing quantities, or canceling services',
                'Customer success reps walk through amendment scenarios with validation guardrails'
            ));

            components.add(new Component(
                'RCA Renewal Flow',
                'Screen Flow',
                'Automated renewal quote generation 90 days before contract expiration',
                'Account managers receive pre-built renewal quotes for proactive customer outreach'
            ));
        }

        if (String.isBlank(componentType) || componentType.equalsIgnoreCase('agentforce')) {
            components.add(new Component(
                'Quoting Agent',
                'Agentforce Agent',
                'Natural language quote creation - "Quote 25 licenses with 10% discount" → Complete quote',
                '75% time reduction for quote creation, eliminates manual data entry errors'
            ));

            components.add(new Component(
                'Pricing Agent',
                'Agentforce Agent',
                'Intelligent pricing recommendations based on deal size, customer segment, and competitive pressure',
                'Sales reps get AI-powered pricing guidance to maximize win rate and margin'
            ));

            components.add(new Component(
                'Renewal Agent',
                'Agentforce Agent',
                'Proactive renewal outreach with personalized messaging based on product usage and health score',
                'Automated renewal campaigns increase net retention by 15%'
            ));
        }

        return components;
    }

    private static String generateImplementationGuide(String componentType) {
        String guide = '📋 Implementation Guide:\n\n';

        if (String.isBlank(componentType) || componentType.equalsIgnoreCase('lightning')) {
            guide += '**Lightning Web Components:**\n';
            guide += '1. Install RCA LWC package from AppExchange or deploy from source\n';
            guide += '2. Add components to Account, Opportunity, or Quote page layouts\n';
            guide += '3. Configure component properties (pricing display, approval thresholds)\n';
            guide += '4. Assign permissions via Permission Set: "RCA Quote Builder User"\n';
            guide += '5. Train sales team on visual quoting interface\n\n';
        }

        if (String.isBlank(componentType) || componentType.equalsIgnoreCase('flow')) {
            guide += '**Flows:**\n';
            guide += '1. Activate RCA flows in Setup → Flows\n';
            guide += '2. Configure approval routing rules (manager hierarchy or custom)\n';
            guide += '3. Customize email templates for approval notifications\n';
            guide += '4. Test flows in sandbox with real-world scenarios\n';
            guide += '5. Deploy to production and monitor flow execution logs\n\n';
        }

        if (String.isBlank(componentType) || componentType.equalsIgnoreCase('agentforce')) {
            guide += '**Agentforce for Revenue:**\n';
            guide += '1. ⚠️ Prerequisite: RCA must be deployed before Agentforce agents can be activated\n';
            guide += '2. License: Agentforce for Revenue license (separate from RCA license) or Flex Credits\n';
            guide += '3. Enable Agentforce in Setup → Einstein Setup → Enable Agentforce\n';
            guide += '4. Activate Quoting Agent from Agent Builder\n';
            guide += '5. Configure agent topics (quote creation, pricing inquiry, product search)\n';
            guide += '6. Train agent with sample conversations and test in sandbox\n';
            guide += '7. Deploy to production and monitor agent conversation logs\n\n';
            guide += '🚨 Key Blocker: Legacy CPQ cannot support Agentforce. RCA migration is required.\n\n';
        }

        guide += '**Testing Checklist:**\n';
        guide += '✓ Golden path scenarios (new quote, amendment, renewal)\n';
        guide += '✓ Edge cases (negative amendments, midterm cancellations)\n';
        guide += '✓ Performance (quote load time under 2 seconds)\n';
        guide += '✓ Mobile experience (responsive design on tablet/phone)\n';
        guide += '✓ Accessibility (screen reader compatible, keyboard navigation)';

        return guide;
    }

    private static List<ConnectAPI> generateConnectAPIs() {
        List<ConnectAPI> apis = new List<ConnectAPI>();

        apis.add(new ConnectAPI(
            'Commerce API - Product Catalog',
            '/services/data/v62.0/commerce/products',
            'Headless product catalog access for external storefronts (B2C, partner portals)'
        ));

        apis.add(new ConnectAPI(
            'Commerce API - Pricing',
            '/services/data/v62.0/commerce/pricing/products/{productId}',
            'Real-time pricing calculation for external applications without Salesforce UI'
        ));

        apis.add(new ConnectAPI(
            'Commerce API - Cart Management',
            '/services/data/v62.0/commerce/webstores/{webstoreId}/carts',
            'Shopping cart operations for B2C e-commerce integration (add, update, checkout)'
        ));

        apis.add(new ConnectAPI(
            'RCA Quote API',
            '/services/apexrest/rca/v1/quotes',
            'Programmatic quote creation for partner portals and custom UIs'
        ));

        apis.add(new ConnectAPI(
            'RCA Asset API',
            '/services/apexrest/rca/v1/assets',
            'Customer asset lookup for external systems (support portals, billing systems)'
        ));

        return apis;
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable
        public String componentType;
    }

    public class Response {
        @InvocableVariable
        public List<Component> components;

        @InvocableVariable
        public String implementationGuide;

        @InvocableVariable
        public String quotingAgentDemo;

        @InvocableVariable
        public List<ConnectAPI> connectAPIs;

        @InvocableVariable
        public Boolean hasData;
    }

    public class Component {
        @InvocableVariable
        public String componentName;

        @InvocableVariable
        public String componentType;

        @InvocableVariable
        public String description;

        @InvocableVariable
        public String useCases;

        public Component(String name, String type, String descriptionText, String uses) {
            this.componentName = name;
            this.componentType = type;
            this.description = descriptionText;
            this.useCases = uses;
        }
    }

    public class ConnectAPI {
        @InvocableVariable
        public String apiName;

        @InvocableVariable
        public String endpoint;

        @InvocableVariable
        public String useCase;

        public ConnectAPI(String name, String endpoint, String useCase) {
            this.apiName = name;
            this.endpoint = endpoint;
            this.useCase = useCase;
        }
    }
}