@RestResource(urlMapping='/pem/partner-tier')
global with sharing class PartnerTierCheckerRest {
    @HttpPost
    global static void invoke() {
        try {
            PartnerTierChecker.Request req = (PartnerTierChecker.Request) PemRestUtil.readRequest(
                PartnerTierChecker.Request.class
            );
            PartnerTierChecker.Result result = PartnerTierChecker.execute(
                new List<PartnerTierChecker.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}