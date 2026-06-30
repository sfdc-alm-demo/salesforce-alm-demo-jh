@RestResource(urlMapping='/pem/mdf-submit')
global with sharing class MdfRequestSubmitterRest {
    @HttpPost
    global static void invoke() {
        try {
            MdfRequestSubmitter.Request req = (MdfRequestSubmitter.Request) PemRestUtil.readRequest(
                MdfRequestSubmitter.Request.class
            );
            MdfRequestSubmitter.Result result = MdfRequestSubmitter.execute(
                new List<MdfRequestSubmitter.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}