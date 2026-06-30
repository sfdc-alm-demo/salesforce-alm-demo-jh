public with sharing class DealRegistrationHandler {

    @InvocableMethod(
        label='Register Deal'
        description='Creates Opportunity record with auto-approval or escalation based on conflict check result'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;

            // Demo: hardcoded Opportunity ID. Production would insert real Opportunity record.
            String fakeOppId = '006Hu00000PEMd' + String.valueOf(Math.mod(System.now().getTime(), 1000));

            if (req.autoApprovalEligible == true) {
                r.registrationStatus = 'auto_approved';
                r.opportunityId = fakeOppId;
                r.channelManagerNotified = false;
                r.approvalMessage = 'Your deal for ' + req.companyName +
                    ' has been auto-approved! Opportunity ' + fakeOppId +
                    ' has been created and assigned to you. You can now begin your sales process. ' +
                    'Deal Value: $' + req.dealValue.format() + '.';
            } else {
                r.registrationStatus = 'escalated';
                r.opportunityId = fakeOppId;
                r.channelManagerNotified = true;
                r.approvalMessage = 'Your deal for ' + req.companyName +
                    ' has been escalated to your Channel Manager for review. ' +
                    'Reason: ' + (req.dealValue != null && req.dealValue >= 50000
                        ? 'deal value of $' + req.dealValue.format() + ' exceeds the $50,000 auto-approval threshold'
                        : 'a channel conflict was detected') +
                    '. You will receive an email update within 24 hours. Deal Registration ID: ' + fakeOppId + '.';
            }

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable
        public String partnerId;

        @InvocableVariable(required=true)
        public String companyName;

        @InvocableVariable(required=true)
        public Decimal dealValue;

        @InvocableVariable
        public String productInterest;

        @InvocableVariable
        public Boolean autoApprovalEligible;
    }

    public class Result {
        @InvocableVariable
        public String registrationStatus;

        @InvocableVariable
        public String opportunityId;

        @InvocableVariable
        public String approvalMessage;

        @InvocableVariable
        public Boolean channelManagerNotified;

        @InvocableVariable
        public Boolean hasData;
    }
}