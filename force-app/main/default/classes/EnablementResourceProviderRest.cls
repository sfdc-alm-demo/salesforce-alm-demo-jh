@RestResource(urlMapping='/pem/enablement-resources')
global with sharing class EnablementResourceProviderRest {
    @HttpPost
    global static void invoke() {
        try {
            EnablementResourceProvider.Request req = (EnablementResourceProvider.Request) PemRestUtil.readRequest(
                EnablementResourceProvider.Request.class
            );
            EnablementResourceProvider.Result result = EnablementResourceProvider.execute(
                new List<EnablementResourceProvider.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}