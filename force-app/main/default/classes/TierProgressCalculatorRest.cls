@RestResource(urlMapping='/pem/tier-progress')
global with sharing class TierProgressCalculatorRest {
    @HttpPost
    global static void invoke() {
        try {
            TierProgressCalculator.Request req = (TierProgressCalculator.Request) PemRestUtil.readRequest(
                TierProgressCalculator.Request.class
            );
            TierProgressCalculator.Result result = TierProgressCalculator.execute(
                new List<TierProgressCalculator.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}