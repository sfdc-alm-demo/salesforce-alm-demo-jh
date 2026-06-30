global with sharing class PemRestUtil {

    global class ErrorResponse {
        global String error;
        global String message;
        global ErrorResponse(String error, String message) {
            this.error = error;
            this.message = message;
        }
    }

    global static Object readRequest(Type requestType) {
        String body = RestContext.request.requestBody == null
            ? null
            : RestContext.request.requestBody.toString();
        if (String.isBlank(body)) {
            return requestType.newInstance();
        }
        return JSON.deserialize(body, requestType);
    }

    global static void writeResult(Object result) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
        RestContext.response.statusCode = 200;
    }

    global static void writeError(Exception e) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.statusCode = 500;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(
            new ErrorResponse(e.getTypeName(), e.getMessage())
        ));
    }
}