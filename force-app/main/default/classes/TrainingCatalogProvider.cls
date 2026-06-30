public with sharing class TrainingCatalogProvider {

    @InvocableMethod(
        label='Get Training Catalog'
        description='Returns available training modules filtered by partner tier'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;
            r.trainings = buildTrainings(req.partnerTier, req.trainingCategory);
            r.trainingCount = r.trainings.size();
            results.add(r);
        }

        return results;
    }

    private static List<TrainingModule> buildTrainings(String tier, String category) {
        List<TrainingModule> all = new List<TrainingModule>();

        // Bronze-tier trainings (always visible)
        all.add(new TrainingModule(
            'Partner Onboarding 101',
            'product',
            '2 hours',
            'Bronze',
            'https://learn.acme.com/courses/onboarding-101',
            'Required onboarding for all new partners covering portal, support, and resources'
        ));
        all.add(new TrainingModule(
            'Sales Basics: Acme Product Family',
            'sales',
            '3 hours',
            'Bronze',
            'https://learn.acme.com/courses/sales-basics',
            'Foundational sales training on positioning, value props, and competitive landscape'
        ));
        all.add(new TrainingModule(
            'Product Overview: Core Suite',
            'product',
            '90 minutes',
            'Bronze',
            'https://learn.acme.com/courses/product-overview',
            'High-level product walkthrough with demos and feature highlights'
        ));

        if (tier == 'Silver' || tier == 'Gold') {
            all.add(new TrainingModule(
                'Advanced Selling Techniques',
                'sales',
                '4 hours',
                'Silver',
                'https://learn.acme.com/courses/advanced-selling',
                'Multi-stakeholder selling, MEDDIC qualification, and objection handling'
            ));
            all.add(new TrainingModule(
                'Deal Registration Best Practices',
                'sales',
                '1 hour',
                'Silver',
                'https://learn.acme.com/courses/deal-reg',
                'How to register clean deals, avoid conflicts, and accelerate approval'
            ));
            all.add(new TrainingModule(
                'ROI Justification Workshop',
                'sales',
                '2 hours',
                'Silver',
                'https://learn.acme.com/courses/roi-workshop',
                'Build customer-facing ROI cases with real templates and customer examples'
            ));
        }

        if (tier == 'Gold') {
            all.add(new TrainingModule(
                'Enterprise Sales Strategies',
                'sales',
                '8 hours',
                'Gold',
                'https://learn.acme.com/courses/enterprise-sales',
                'Executive engagement, complex deal navigation, and $500K+ deal strategies'
            ));
            all.add(new TrainingModule(
                'Technical Deep Dive: Architecture and APIs',
                'technical',
                '12 hours',
                'Gold',
                'https://learn.acme.com/courses/technical-deep-dive',
                'Complete technical architecture, API integration patterns, and custom extensibility'
            ));
            all.add(new TrainingModule(
                'Executive Sponsor Program',
                'sales',
                'Ongoing',
                'Gold',
                'https://learn.acme.com/programs/exec-sponsor',
                'Direct executive engagement program with quarterly business reviews and joint planning'
            ));
        }

        if (String.isNotBlank(category) && !category.equalsIgnoreCase('all')) {
            List<TrainingModule> filtered = new List<TrainingModule>();
            for (TrainingModule t : all) {
                if (t.category.equalsIgnoreCase(category)) {
                    filtered.add(t);
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
        public String trainingCategory;
    }

    public class Result {
        @InvocableVariable
        public List<TrainingModule> trainings;

        @InvocableVariable
        public Decimal trainingCount;

        @InvocableVariable
        public Boolean hasData;
    }

    public class TrainingModule {
        @InvocableVariable
        public String trainingTitle;

        @InvocableVariable
        public String category;

        @InvocableVariable
        public String duration;

        @InvocableVariable
        public String tierRequired;

        @InvocableVariable
        public String url;

        @InvocableVariable
        public String trainingDescription;

        public TrainingModule(String title, String cat, String dur, String tier, String urlVal, String descText) {
            this.trainingTitle = title;
            this.category = cat;
            this.duration = dur;
            this.tierRequired = tier;
            this.url = urlVal;
            this.trainingDescription = descText;
        }
    }
}