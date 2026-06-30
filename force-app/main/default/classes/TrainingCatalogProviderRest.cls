@RestResource(urlMapping='/pem/training-catalog')
global with sharing class TrainingCatalogProviderRest {
    @HttpPost
    global static void invoke() {
        try {
            TrainingCatalogProvider.Request req = (TrainingCatalogProvider.Request) PemRestUtil.readRequest(
                TrainingCatalogProvider.Request.class
            );
            TrainingCatalogProvider.Result result = TrainingCatalogProvider.execute(
                new List<TrainingCatalogProvider.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}