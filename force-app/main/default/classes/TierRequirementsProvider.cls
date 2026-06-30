public with sharing class TierRequirementsProvider {

    @InvocableMethod(
        label='Get Tier Requirements'
        description='Returns requirements to progress from current tier to next tier'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;
            r.requirements = new List<TierRequirement>();

            String tier = String.isNotBlank(req.currentTier) ? req.currentTier : 'Bronze';

            if (tier.equalsIgnoreCase('Bronze')) {
                r.nextTier = 'Silver';
                r.estimatedTimeframe = '3-6 months';
                r.requirements.add(new TierRequirement(
                    'Closed Deals',
                    'Successfully close at least 5 deals through deal registration',
                    '2',
                    '5',
                    false
                ));
                r.requirements.add(new TierRequirement(
                    'Certified Sales Reps',
                    'Have 2 sales reps complete the Acme Sales Certification',
                    '1',
                    '2',
                    false
                ));
                r.requirements.add(new TierRequirement(
                    'Annual Partner Revenue',
                    'Generate $100K in annual partner revenue',
                    '$45K',
                    '$100K',
                    false
                ));
            } else if (tier.equalsIgnoreCase('Silver')) {
                r.nextTier = 'Gold';
                r.estimatedTimeframe = '6-12 months';
                r.requirements.add(new TierRequirement(
                    'Closed Deals',
                    'Successfully close at least 15 deals through deal registration',
                    '11',
                    '15',
                    false
                ));
                r.requirements.add(new TierRequirement(
                    'Certified Sales Reps',
                    'Have 5 sales reps complete the Acme Sales Certification',
                    '4',
                    '5',
                    false
                ));
                r.requirements.add(new TierRequirement(
                    'Technical Specialists',
                    'Have at least 1 technical specialist certified on Acme architecture',
                    '0',
                    '1',
                    false
                ));
                r.requirements.add(new TierRequirement(
                    'Annual Partner Revenue',
                    'Generate $500K in annual partner revenue',
                    '$340K',
                    '$500K',
                    false
                ));
            } else {
                r.nextTier = 'None';
                r.estimatedTimeframe = 'N/A';
                r.requirements.add(new TierRequirement(
                    'Highest Tier Achieved',
                    'You have reached the highest partner tier - Gold. Maintain by hitting annual targets.',
                    'Gold',
                    'Gold',
                    true
                ));
            }

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable
        public String currentTier;
    }

    public class Result {
        @InvocableVariable
        public String nextTier;

        @InvocableVariable
        public List<TierRequirement> requirements;

        @InvocableVariable
        public String estimatedTimeframe;

        @InvocableVariable
        public Boolean hasData;
    }

    public class TierRequirement {
        @InvocableVariable
        public String requirementName;

        @InvocableVariable
        public String requirementDescription;

        @InvocableVariable
        public String currentValue;

        @InvocableVariable
        public String targetValue;

        @InvocableVariable
        public Boolean isMet;

        public TierRequirement(String name, String descText, String current, String target, Boolean met) {
            this.requirementName = name;
            this.requirementDescription = descText;
            this.currentValue = current;
            this.targetValue = target;
            this.isMet = met;
        }
    }
}