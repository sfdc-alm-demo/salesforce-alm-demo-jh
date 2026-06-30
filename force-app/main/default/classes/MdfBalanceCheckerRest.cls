@RestResource(urlMapping='/pem/mdf-balance')
global with sharing class MdfBalanceCheckerRest {
    @HttpPost
    global static void invoke() {
        try {
            MdfBalanceChecker.Request req = (MdfBalanceChecker.Request) PemRestUtil.readRequest(
                MdfBalanceChecker.Request.class
            );
            MdfBalanceChecker.Result result = MdfBalanceChecker.execute(
                new List<MdfBalanceChecker.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}