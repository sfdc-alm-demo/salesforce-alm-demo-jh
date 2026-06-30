public with sharing class TrainingEnrollmentHandler {

    @InvocableMethod(
        label='Enroll Training'
        description='Enrolls partner in a training module and returns access link'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.hasData = true;

            // Demo: hardcoded success. Production: insert Training_Enrollment__c record.
            r.enrollmentSuccess = true;
            r.enrollmentMessage = 'You are now enrolled in "' + req.trainingTitle + '". ' +
                'You can access the training using the link below. Your progress will be tracked automatically ' +
                'and counted toward your tier certification requirements.';
            r.trainingUrl = 'https://learn.acme.com/my-enrollments/' +
                req.trainingTitle.replaceAll('[^a-zA-Z0-9]', '-').toLowerCase();

            results.add(r);
        }

        return results;
    }

    public class Request {
        @InvocableVariable
        public String partnerId;

        @InvocableVariable(required=true)
        public String trainingTitle;
    }

    public class Result {
        @InvocableVariable
        public Boolean enrollmentSuccess;

        @InvocableVariable
        public String enrollmentMessage;

        @InvocableVariable
        public String trainingUrl;

        @InvocableVariable
        public Boolean hasData;
    }
}