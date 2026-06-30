@RestResource(urlMapping='/pem/training-enroll')
global with sharing class TrainingEnrollmentHandlerRest {
    @HttpPost
    global static void invoke() {
        try {
            TrainingEnrollmentHandler.Request req = (TrainingEnrollmentHandler.Request) PemRestUtil.readRequest(
                TrainingEnrollmentHandler.Request.class
            );
            TrainingEnrollmentHandler.Result result = TrainingEnrollmentHandler.execute(
                new List<TrainingEnrollmentHandler.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}