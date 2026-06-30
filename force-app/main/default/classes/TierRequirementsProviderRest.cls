@RestResource(urlMapping='/pem/tier-requirements')
global with sharing class TierRequirementsProviderRest {
    @HttpPost
    global static void invoke() {
        try {
            TierRequirementsProvider.Request req = (TierRequirementsProvider.Request) PemRestUtil.readRequest(
                TierRequirementsProvider.Request.class
            );
            TierRequirementsProvider.Result result = TierRequirementsProvider.execute(
                new List<TierRequirementsProvider.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}