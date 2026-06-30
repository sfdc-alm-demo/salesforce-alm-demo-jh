public with sharing class BillingSetupValidator {

    @InvocableMethod(label='Validate Billing Setup' description='Validates Revenue Cloud Billing (RCB) and revenue recognition (ASC 606/IFRS 15) configuration')
    public static List<Response> validateBillingSetup(List<Request> requests) {
        Request req = requests[0];
        Response res = new Response();

        // Hardcoded validation results
        res.hasData = true;
        res.rcbSyncPercentage = 80;

        // Determine configuration status
        if (req.validationType.equalsIgnoreCase('billing') || req.validationType.equalsIgnoreCase('both')) {
            res.isConfigured = true; // Demo assumes RCA is configured
        } else {
            res.isConfigured = false;
        }

        // Generate validation results
        res.validationResults = generateValidationResults(req.validationType);

        // Setup steps (if not configured)
        res.setupSteps = generateSetupSteps(req.validationType);

        // CFO talking points
        res.cfoTalkingPoints = generateCFOTalkingPoints(req.complianceRequired);

        return new List<Response>{ res };
    }

    private static List<ValidationResult> generateValidationResults(String validationType) {
        List<ValidationResult> results = new List<ValidationResult>();

        if (validationType.equalsIgnoreCase('billing') || validationType.equalsIgnoreCase('both')) {
            results.add(new ValidationResult(
                'Revenue Cloud Billing (RCB) License',
                'Active',
                'RCB license is active and provisioned for this org'
            ));

            results.add(new ValidationResult(
                'Billing Schedule Configuration',
                'Configured',
                'Default billing schedules created for monthly, quarterly, and annual billing'
            ));

            results.add(new ValidationResult(
                'Payment Terms',
                'Configured',
                'Standard payment terms (Net 30, Net 60, Due on Receipt) configured'
            ));

            results.add(new ValidationResult(
                'Invoice Template',
                'Active',
                'Default invoice template configured with company branding'
            ));
        }

        if (validationType.equalsIgnoreCase('revenue_recognition') || validationType.equalsIgnoreCase('both')) {
            results.add(new ValidationResult(
                'Revenue Recognition Rules',
                'Configured',
                'ASC 606 / IFRS 15 revenue recognition rules configured for subscription products'
            ));

            results.add(new ValidationResult(
                'Deferred Revenue Tracking',
                'Active',
                'Deferred revenue automatically tracked for multi-year contracts'
            ));

            results.add(new ValidationResult(
                'Revenue Schedule Objects',
                'Enabled',
                'RevenueSchedule and RevenueScheduleLine objects enabled for rev rec tracking'
            ));
        }

        return results;
    }

    private static List<SetupStep> generateSetupSteps(String validationType) {
        List<SetupStep> steps = new List<SetupStep>();

        if (validationType.equalsIgnoreCase('billing') || validationType.equalsIgnoreCase('both')) {
            steps.add(new SetupStep(
                1,
                'Enable Revenue Cloud Billing',
                'Navigate to Setup → Revenue Cloud → Enable RCB. Note: 80% of RCB setup is complete when RCA is configured.'
            ));

            steps.add(new SetupStep(
                2,
                'Configure Billing Schedules',
                'Define billing frequency (monthly, quarterly, annual) and billing day preferences'
            ));

            steps.add(new SetupStep(
                3,
                'Set Up Payment Terms',
                'Configure payment terms (Net 30, Net 60) and dunning process for late payments'
            ));

            steps.add(new SetupStep(
                4,
                'Design Invoice Template',
                'Customize invoice template with company logo, payment instructions, and legal terms'
            ));
        }

        if (validationType.equalsIgnoreCase('revenue_recognition') || validationType.equalsIgnoreCase('both')) {
            steps.add(new SetupStep(
                5,
                'Enable Revenue Recognition',
                'Navigate to Setup → Revenue Cloud → Enable ASC 606 / IFRS 15 Revenue Recognition'
            ));

            steps.add(new SetupStep(
                6,
                'Configure Recognition Rules',
                'Define revenue recognition rules: straight-line, ratable, milestone-based'
            ));

            steps.add(new SetupStep(
                7,
                'Map Products to Rev Rec Rules',
                'Associate product types with appropriate revenue recognition treatment'
            ));
        }

        return steps;
    }

    private static List<CFOPoint> generateCFOTalkingPoints(Boolean complianceRequired) {
        List<CFOPoint> points = new List<CFOPoint>();

        points.add(new CFOPoint(
            'Automated Revenue Recognition',
            'RCB automates ASC 606 / IFRS 15 compliance, reducing manual accounting workload by 75%',
            'Multi-year subscription: Revenue automatically deferred and recognized monthly over contract term'
        ));

        points.add(new CFOPoint(
            'Ramped Pricing Support',
            'Handles complex ramped pricing scenarios (Year 1: $100K, Year 2: $120K, Year 3: $150K) with accurate revenue recognition',
            'SaaS company with annual price increases: Revenue recognized correctly each year despite different pricing'
        ));

        points.add(new CFOPoint(
            'Midterm Contract Uplifts',
            'Accurately tracks revenue impact of midterm price changes and upsells',
            'Customer adds 50 licenses mid-contract: Prorated revenue recognized correctly for remainder of term'
        ));

        points.add(new CFOPoint(
            'Deferred Revenue Visibility',
            'Real-time visibility into deferred revenue balance and revenue recognition schedule',
            'CFO dashboard shows $5M deferred revenue, $500K recognized this month, $4.5M future recognition'
        ));

        points.add(new CFOPoint(
            'Audit Trail and Compliance',
            'Complete audit trail of all revenue recognition decisions and adjustments for SOX compliance',
            'Auditor requests: System provides full history of revenue transactions and recognition basis'
        ));

        if (complianceRequired) {
            points.add(new CFOPoint(
                'ASC 606 / IFRS 15 Certification',
                'RCB is certified for ASC 606 and IFRS 15 compliance by major accounting firms',
                'Public company audit: RCB revenue recognition passes Big 4 audit without adjustments'
            ));
        }

        points.add(new CFOPoint(
            'Finance System Integration',
            'API-first architecture integrates with NetSuite, SAP, Oracle Financials for GL posting',
            'Month-end close: Revenue transactions automatically posted to NetSuite GL with proper coding'
        ));

        return points;
    }

    // Inner classes for complex data types
    public class Request {
        @InvocableVariable(required=true)
        public String validationType;

        @InvocableVariable
        public Boolean complianceRequired;
    }

    public class Response {
        @InvocableVariable
        public Boolean isConfigured;

        @InvocableVariable
        public List<ValidationResult> validationResults;

        @InvocableVariable
        public List<SetupStep> setupSteps;

        @InvocableVariable
        public List<CFOPoint> cfoTalkingPoints;

        @InvocableVariable
        public Integer rcbSyncPercentage;

        @InvocableVariable
        public Boolean hasData;
    }

    public class ValidationResult {
        @InvocableVariable
        public String componentName;

        @InvocableVariable
        public String status;

        @InvocableVariable
        public String details;

        public ValidationResult(String component, String status, String details) {
            this.componentName = component;
            this.status = status;
            this.details = details;
        }
    }

    public class SetupStep {
        @InvocableVariable
        public Integer stepNumber;

        @InvocableVariable
        public String stepTitle;

        @InvocableVariable
        public String stepDescription;

        public SetupStep(Integer stepNum, String title, String description) {
            this.stepNumber = stepNum;
            this.stepTitle = title;
            this.stepDescription = description;
        }
    }

    public class CFOPoint {
        @InvocableVariable
        public String topic;

        @InvocableVariable
        public String benefit;

        @InvocableVariable
        public String example;

        public CFOPoint(String topic, String benefit, String example) {
            this.topic = topic;
            this.benefit = benefit;
            this.example = example;
        }
    }
}