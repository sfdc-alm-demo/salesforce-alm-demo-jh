public with sharing class GetRequestStatus {

    public class Request {
        @InvocableVariable(
            label='Request ID'
            description='The transcription request ID to look up'
            required=true
        )
        public String requestId;
    }

    public class Result {
        @InvocableVariable(
            label='Request ID'
            description='Echo of the request ID'
        )
        public String requestId;

        @InvocableVariable(
            label='Status'
            description='Current status: queued, in_progress, review, or completed'
        )
        public String status;

        @InvocableVariable(
            label='Transcription Type'
            description='Type of transcription'
        )
        public String transcriptionType;

        @InvocableVariable(
            label='Assigned Team'
            description='Team handling the request'
        )
        public String assignedTeam;

        @InvocableVariable(
            label='Estimated Completion'
            description='Estimated completion time'
        )
        public String estimatedCompletion;

        @InvocableVariable(
            label='Progress Notes'
            description='Latest progress notes'
        )
        public String progressNotes;
    }

    @InvocableMethod(
        label='Get Request Status'
        description='Retrieves status details for a transcription request by ID'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            r.requestId = req.requestId;

            if (req.requestId != null && req.requestId.startsWith('TR-')) {
                r.status = 'in_progress';
                r.transcriptionType = 'medical';
                r.assignedTeam = 'Medical Transcription Services';
                r.estimatedCompletion = '24 hours';
                r.progressNotes = 'Audio file received and assigned to transcriptionist. Initial review complete, full transcription 60% done. Expected delivery on schedule.';
            } else {
                r.status = 'queued';
                r.transcriptionType = 'general';
                r.assignedTeam = 'General Transcription Pool';
                r.estimatedCompletion = '3-5 business days';
                r.progressNotes = 'Request received and queued for assignment. A transcriptionist will be assigned within 2 hours.';
            }
            results.add(r);
        }
        return results;
    }
}