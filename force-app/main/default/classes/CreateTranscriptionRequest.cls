public with sharing class CreateTranscriptionRequest {

    public class Request {
        @InvocableVariable(
            label='Transcription Type'
            description='Type of transcription: medical, legal, technical, or general'
            required=true
        )
        public String transcriptionType;

        @InvocableVariable(
            label='Source Description'
            description='Description of the source material'
            required=true
        )
        public String sourceDescription;

        @InvocableVariable(
            label='Source Language'
            description='Language of the source material'
            required=true
        )
        public String sourceLanguage;

        @InvocableVariable(
            label='Urgency Level'
            description='Urgency level: standard, rush, or critical'
            required=true
        )
        public String urgencyLevel;

        @InvocableVariable(
            label='Special Instructions'
            description='Special instructions for the transcription'
            required=false
        )
        public String specialInstructions;
    }

    public class Result {
        @InvocableVariable(
            label='Request ID'
            description='Generated request ID'
        )
        public String requestId;

        @InvocableVariable(
            label='Assigned Team'
            description='Name of the team assigned to the request'
        )
        public String assignedTeam;

        @InvocableVariable(
            label='Estimated Completion'
            description='Estimated turnaround time'
        )
        public String estimatedCompletion;

        @InvocableVariable(
            label='Confirmation Message'
            description='Human-readable confirmation message'
        )
        public String confirmationMessage;
    }

    @InvocableMethod(
        label='Create Transcription Request'
        description='Creates a transcription handoff request and assigns to the appropriate specialized team'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();

            String reqNum = String.valueOf(Math.round(Math.random() * 89999 + 10000));
            r.requestId = 'TR-2026-' + reqNum;

            Map<String, String> teamMap = new Map<String, String>{
                'medical' => 'Medical Transcription Services',
                'legal' => 'Legal Documentation Team',
                'technical' => 'Technical Writing & Transcription',
                'general' => 'General Transcription Pool'
            };
            r.assignedTeam = teamMap.containsKey(req.transcriptionType)
                ? teamMap.get(req.transcriptionType)
                : 'General Transcription Pool';

            Map<String, String> turnaroundMap = new Map<String, String>{
                'critical' => '4-6 hours',
                'rush' => '24 hours',
                'standard' => '3-5 business days'
            };
            r.estimatedCompletion = turnaroundMap.containsKey(req.urgencyLevel)
                ? turnaroundMap.get(req.urgencyLevel)
                : '3-5 business days';

            r.confirmationMessage = 'Transcription request ' + r.requestId +
                ' has been created and assigned to ' + r.assignedTeam +
                '. Source language: ' + req.sourceLanguage +
                '. Urgency: ' + req.urgencyLevel +
                '. Estimated completion: ' + r.estimatedCompletion + '.';

            results.add(r);
        }
        return results;
    }
}