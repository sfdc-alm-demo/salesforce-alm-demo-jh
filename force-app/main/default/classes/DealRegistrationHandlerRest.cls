@RestResource(urlMapping='/pem/deal-register')
global with sharing class DealRegistrationHandlerRest {
    @HttpPost
    global static void invoke() {
        try {
            DealRegistrationHandler.Request req = (DealRegistrationHandler.Request) PemRestUtil.readRequest(
                DealRegistrationHandler.Request.class
            );
            DealRegistrationHandler.Result result = DealRegistrationHandler.execute(
                new List<DealRegistrationHandler.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}