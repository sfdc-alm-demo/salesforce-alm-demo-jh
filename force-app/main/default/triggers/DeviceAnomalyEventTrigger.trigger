trigger DeviceAnomalyEventTrigger on Device_Anomaly__e (after insert) {
    List<AnomalyTriageActions.TriageRequest> requests = new List<AnomalyTriageActions.TriageRequest>();
    for (Device_Anomaly__e e : Trigger.New) {
        AnomalyTriageActions.TriageRequest req = new AnomalyTriageActions.TriageRequest();
        req.correlationId = e.Replay_Correlation_Id__c;
        req.deviceSerial = e.Device_Serial__c;
        req.anomalyCode = e.Anomaly_Code__c;
        req.anomalyCategory = e.Anomaly_Category__c;
        req.severitySignal = e.Severity_Signal__c;
        req.telemetryPayload = e.Telemetry_Payload__c;
        req.patternHash = e.Pattern_Hash__c;
        req.confidenceScore = e.Confidence_Score__c;
        req.sourceSystem = e.Source_System__c;
        req.siteCode = e.Site_Code__c;
        requests.add(req);
    }
    AnomalyTriageActions.triage(requests);
}