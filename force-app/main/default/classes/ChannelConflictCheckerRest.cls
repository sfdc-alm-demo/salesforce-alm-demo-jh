@RestResource(urlMapping='/pem/channel-conflict')
global with sharing class ChannelConflictCheckerRest {
    @HttpPost
    global static void invoke() {
        try {
            ChannelConflictChecker.Request req = (ChannelConflictChecker.Request) PemRestUtil.readRequest(
                ChannelConflictChecker.Request.class
            );
            ChannelConflictChecker.Result result = ChannelConflictChecker.execute(
                new List<ChannelConflictChecker.Request>{ req }
            )[0];
            PemRestUtil.writeResult(result);
        } catch (Exception e) {
            PemRestUtil.writeError(e);
        }
    }
}