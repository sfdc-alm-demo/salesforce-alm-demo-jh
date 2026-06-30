// 01/28 - CP: disabling this for now. Asked Analytics team if anybody knows what this is used for
// and nobody did. So disabling, if nobody complains then it can be deleted later.
trigger SDO_Service_AI_CaseSentimentTrigger on Case (after insert) {
    if(System.isBatch()) return;
    SDO_Service_AI_SvcCloudPredictionHelper.caseSubjectSentiment(trigger.new[0].id);
}