public with sharing class CPQRCAComparator {

    @InvocableMethod(label='Compare CPQ and RCA' description='Competitive positioning: CPQ (legacy) vs RCA (modern)')
    public static List<Response> compareCPQRCA(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded demo data
        res.hasData = true;

        // Generate comparison table
        res.comparisonTable = generateComparisonTable(req.comparisonArea);

        // Key positioning message
        res.keyPositioning = '💡 KEY POSITIONING MESSAGE:\n\n' +
                             '"You\'re moving from a sales tool to a financial system of record. ' +
                             'Staying on legacy CPQ means paying for a product that has reached its functional ceiling."\n\n' +
                             'This resonates with:\n' +
                             '• CFOs (financial system of record = compliance, audit, revenue recognition)\n' +
                             '• CROs (API-first = omnichannel GTM, self-service, partner channels)\n' +
                             '• CIOs (on-core = easier integration, lower tech debt, AI-ready platform)';

        // CPQ to RCA promo
        res.cpqToRCAPromo = '#CPQtoRLMpromo: Convert CPQ Spend to RCA, Keep CPQ at $0\n\n' +
                            'This promotion addresses the #1 objection: "We\'re already paying for CPQ, why pay for RCA too?"\n\n' +
                            '🎯 How It Works:\n' +
                            '• Convert existing CPQ license spend to Revenue Cloud Advanced (RCA) license\n' +
                            '• CPQ license drops to $0 for remainder of contract term\n' +
                            '• Eliminates double-licensing cost during migration period\n' +
                            '• Customer pays same total amount, just reallocated to RCA\n\n' +
                            '📊 Example:\n' +
                            'Customer paying $200K/year for CPQ with 2 years remaining:\n' +
                            '• Without promo: $200K CPQ + $200K RCA = $400K/year (ouch!)\n' +
                            '• With promo: $0 CPQ + $200K RCA = $200K/year (same cost!)\n\n' +
                            '⏰ Urgency: CPQ End-of-Sale (March 2025 for net-new), existing customers can renew ONE more time';

        // Licensing context
        res.licensingContext = '📋 LICENSING CONTEXT (Critical for Objection Handling):\n\n' +
                               '**CPQ Status:**\n' +
                               '• End-of-Sale: March 2025 for net-new customers\n' +
                               '• NOT End-of-Life: Existing customers can renew ONE more time\n' +
                               '• R&D Investment: $0 - No new features, only critical bug fixes\n' +
                               '• Support: Continues for existing customers through renewal period\n\n' +
                               '**RCA Licensing:**\n' +
                               '• RCA License: Revenue Cloud Advanced platform license\n' +
                               '• Does NOT include Agentforce: Common misconception!\n' +
                               '• Agentforce Separate: Requires "Agentforce for Revenue" license OR Flex Credits\n' +
                               '• Pricing Model: Per-user or consumption-based (depends on SKU)\n\n' +
                               '**Agentforce for Revenue:**\n' +
                               '• Prerequisite: RCA MUST be deployed before Agentforce agents can be activated\n' +
                               '• Licensing: Separate from RCA license\n' +
                               '• Options: Named user license OR Flex Credits (usage-based)\n' +
                               '• Agents: Quoting Agent, Pricing Agent, Renewal Agent, etc.\n\n' +
                               '🚨 Blocker: Legacy CPQ cannot support Agentforce (managed package limitation)';

        // Agentforce blocker
        res.agentforceBlocker = '🤖 AGENTFORCE BLOCKER - Most Powerful Forcing Function Right Now:\n\n' +
                                'Legacy Salesforce CPQ CANNOT support Agentforce agents due to managed package architecture limitations.\n\n' +
                                'Why This Matters:\n' +
                                '• Every customer wants AI agents for sales automation\n' +
                                '• Quoting Agent delivers 75% time reduction for quote creation\n' +
                                '• Pricing Agent provides intelligent pricing recommendations\n' +
                                '• Renewal Agent automates proactive customer outreach\n\n' +
                                'The Reality Check:\n' +
                                '"If you want AI agents for your quote-to-cash process, you MUST migrate to RCA. ' +
                                'There is no path to Agentforce on legacy CPQ. Period."\n\n' +
                                'This is the forcing function driving migrations in 2026. ' +
                                'Customers who were hesitant about RCA migration are now moving forward because ' +
                                'they see competitors using AI agents and don\'t want to be left behind.';

        return new List<Response>{ res };
    }

    private static List<Comparison> generateComparisonTable(String comparisonArea) {
        List<Comparison> comparisons = new List<Comparison>();

        // Architecture comparison
        if (String.isBlank(comparisonArea) || comparisonArea.equalsIgnoreCase('architecture') || comparisonArea.equalsIgnoreCase('all')) {
            comparisons.add(new Comparison(
                'Architecture',
                'Managed package (separate object model, namespace overhead)',
                'On-core (native Salesforce platform, no managed package)'
            ));

            comparisons.add(new Comparison(
                'Data Model',
                'Contract-centric (tracks contracts, not what customer owns)',
                'Asset-centric (tracks customer ownership state for amendments/renewals)'
            ));

            comparisons.add(new Comparison(
                'Integration',
                'Limited API access due to managed package boundaries',
                'API-first with full standard object access and Connect APIs'
            ));
        }

        // Pricing comparison
        if (String.isBlank(comparisonArea) || comparisonArea.equalsIgnoreCase('pricing') || comparisonArea.equalsIgnoreCase('all')) {
            comparisons.add(new Comparison(
                'Pricing Engine',
                'JavaScript/Apex custom price rules (code-heavy)',
                'Declarative Pricing Procedure designer (drag-and-drop price waterfall)'
            ));

            comparisons.add(new Comparison(
                'Price Waterfall',
                'No visual waterfall - rules executed in code',
                'Visual price waterfall: List → Volume → Promo → Partner → Final'
            ));

            comparisons.add(new Comparison(
                'Pricing Maintenance',
                'Requires developer to modify JavaScript rules',
                'Business users maintain pricing via declarative UI'
            ));
        }

        // Agentforce comparison
        if (String.isBlank(comparisonArea) || comparisonArea.equalsIgnoreCase('agentforce') || comparisonArea.equalsIgnoreCase('all')) {
            comparisons.add(new Comparison(
                'Agentforce Support',
                'Cannot support Agentforce (managed package limitation)',
                'Agentforce-ready (prerequisite for AI agents)'
            ));

            comparisons.add(new Comparison(
                'AI Capabilities',
                'Limited to Einstein features available in managed package',
                'Full AI platform: Agentforce agents, Einstein GPT, Prompt Builder'
            ));

            comparisons.add(new Comparison(
                'Quoting Automation',
                'Manual quote entry required',
                'Natural language quoting via Quoting Agent (75% time reduction)'
            ));
        }

        // Channel/GTM comparison
        if (String.isBlank(comparisonArea) || comparisonArea.equalsIgnoreCase('all')) {
            comparisons.add(new Comparison(
                'Go-To-Market Channels',
                'Built for sales reps only (Salesforce UI)',
                'Omnichannel: Direct sales, self-service portal, partner channel, API-driven'
            ));

            comparisons.add(new Comparison(
                'Headless Commerce',
                'Not designed for headless use cases',
                'Connect Commerce APIs for headless pricing (B2C storefronts, partner portals)'
            ));
        }

        // Investment comparison (always include)
        comparisons.add(new Comparison(
            'Product Investment',
            'End-of-Sale: $0 R&D investment, critical bug fixes only',
            '100% of Salesforce Revenue Cloud R&D investment'
        ));

        comparisons.add(new Comparison(
            'Innovation Velocity',
            'Feature-frozen (no new capabilities)',
            'Continuous innovation: New features in every release'
        ));

        comparisons.add(new Comparison(
            'Roadmap',
            'Maintenance mode only',
            'Active roadmap: Multi-dimensional pricing, expanded AI, enhanced asset lifecycle'
        ));

        return comparisons;
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable
        public String comparisonArea;
    }

    public class Response {
        @InvocableVariable
        public List<Comparison> comparisonTable;

        @InvocableVariable
        public String keyPositioning;

        @InvocableVariable
        public String cpqToRCAPromo;

        @InvocableVariable
        public String licensingContext;

        @InvocableVariable
        public String agentforceBlocker;

        @InvocableVariable
        public Boolean hasData;
    }

    public class Comparison {
        @InvocableVariable
        public String feature;

        @InvocableVariable
        public String cpqValue;

        @InvocableVariable
        public String rcaValue;

        public Comparison(String feature, String cpq, String rca) {
            this.feature = feature;
            this.cpqValue = cpq;
            this.rcaValue = rca;
        }
    }
}