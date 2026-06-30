public with sharing class ClassifyTranscription {

    public class Request {
        @InvocableVariable(
            label='Content Description'
            description='Description of the source material to be transcribed'
            required=true
        )
        public String contentDescription;
    }

    public class Result {
        @InvocableVariable(
            label='Transcription Type'
            description='Classified type: medical, legal, technical, or general'
        )
        public String transcriptionType;

        @InvocableVariable(
            label='Confidence'
            description='Classification confidence: high, medium, or low'
        )
        public String confidence;

        @InvocableVariable(
            label='Classification Reasoning'
            description='Explanation of why this classification was chosen'
        )
        public String classificationReasoning;
    }

    @InvocableMethod(
        label='Classify Transcription'
        description='Classifies transcription content into medical, legal, technical, or general based on content description'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            String descText = (req.contentDescription != null) ? req.contentDescription.toLowerCase() : '';

            if (descText.contains('patient') || descText.contains('medical') || descText.contains('diagnosis') ||
                descText.contains('clinical') || descText.contains('hospital') || descText.contains('doctor') ||
                descText.contains('prescription') || descText.contains('surgery') || descText.contains('health')) {
                r.transcriptionType = 'medical';
                r.confidence = 'high';
                r.classificationReasoning = 'Content contains medical terminology such as patient records, clinical notes, or healthcare documentation.';
            } else if (descText.contains('legal') || descText.contains('court') || descText.contains('deposition') ||
                       descText.contains('attorney') || descText.contains('plaintiff') || descText.contains('contract') ||
                       descText.contains('testimony') || descText.contains('law') || descText.contains('trial')) {
                r.transcriptionType = 'legal';
                r.confidence = 'high';
                r.classificationReasoning = 'Content contains legal terminology such as court proceedings, depositions, or legal documentation.';
            } else if (descText.contains('technical') || descText.contains('engineering') || descText.contains('software') ||
                       descText.contains('code') || descText.contains('architecture') || descText.contains('specification') ||
                       descText.contains('api') || descText.contains('database') || descText.contains('server')) {
                r.transcriptionType = 'technical';
                r.confidence = 'high';
                r.classificationReasoning = 'Content contains technical terminology such as engineering specs, software documentation, or technical discussions.';
            } else {
                r.transcriptionType = 'general';
                r.confidence = 'medium';
                r.classificationReasoning = 'Content does not match specialized domains. Classified as general transcription for broad-scope processing.';
            }
            results.add(r);
        }
        return results;
    }
}