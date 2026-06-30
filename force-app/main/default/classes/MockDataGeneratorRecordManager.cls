/**
 * Manages persistence of generated mock data records
 *
 * Responsibilities:
 * - Parse generated JSON into SObjects
 * - Apply pre-processing (object-specific transformations before insert)
 * - Insert records into Salesforce with proper error handling
 * - Apply post-processing (object-specific operations after insert)
 * - Handle rollback on failure
 * - Return detailed results with record IDs
 *
 * Security Note:
 * This class uses 'with sharing' to enforce record-level security and sharing
 * rules when inserting records, ensuring users can only create records they
 * have permission to create.
 *
 * Design Principles Applied:
 * - Single Responsibility: Focuses solely on record persistence
 * - Open/Closed: Pre/post processing extensible via rule types
 * - Bulkification: All operations handle multiple records efficiently
 * - Transactional Integrity: Uses savepoint and rollback for data consistency
 */
public with sharing class MockDataGeneratorRecordManager {

    /**
     * Request class for saving generated records
     */
    public class Request {
        @InvocableVariable(
            label='Generated Records JSON'
            description='JSON array of generated mock data records from the generation step'
            required=true
        )
        public String generatedRecordsJson;

        @InvocableVariable(
            label='Rule JSON'
            description='Serialized Demo_Assist_Mock_Data_Generator_Rule__c record containing object type and processing rules'
            required=true
        )
        public String ruleJson;

        @InvocableVariable(
            label='Parent Record ID'
            description='The ID of the parent record to link generated records to (null for standalone generation)'
            required=false
        )
        public String parentRecordId;

        @InvocableVariable(
            label='Follow Records'
            description='If true, automatically follow the records created from this request'
            required=false
        )
        public Boolean isFollow;

        @InvocableVariable(
            label='Favorite Records'
            description='If true, add the created records to the invoking user\'s favorites'
            required=false
        )
        public Boolean isFavorite;

        @InvocableVariable(
            label='Mark as Recently Viewed'
            description='If true, add the created records to the invoking user\'s recently viewed list'
            required=false
        )
        public Boolean isRecentViewed;
    }

    /**
     * Response class for save operation
     */
    public class Response {
        @InvocableVariable(
            label='Success'
            description='Whether the records were saved successfully'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='Success or error message with details about the save operation'
        )
        public String message;

        @InvocableVariable(
            label='Records Created'
            description='Number of records successfully created in Salesforce'
        )
        public Integer recordsCreated;

        @InvocableVariable(
            label='Record Details JSON'
            description='JSON array containing details of created records with their Salesforce IDs'
        )
        public String recordDetailsJson;
    }

    /**
     * Main invocable method for saving generated records
     */
    @InvocableMethod(
        label='Save Generated Mock Data'
        description='Saves generated mock data records to Salesforce with pre/post processing'
    )
    public static List<Response> saveRecords(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.success = false;
            res.recordsCreated = 0;

            try {
                // Deserialize rule
                Demo_Assist_Mock_Data_Generator_Rule__c rule =
                    (Demo_Assist_Mock_Data_Generator_Rule__c) JSON.deserialize(
                        req.ruleJson,
                        Demo_Assist_Mock_Data_Generator_Rule__c.class
                    );

                // Parse and insert records
                InsertResult insertResult = parseAndInsertRecords(
                    req.generatedRecordsJson,
                    rule,
                    req.parentRecordId
                );

                // Apply user list actions OUTSIDE the transaction (after DML completes)
                // This is required because HTTP callouts cannot be made with uncommitted work
                applyUserListActions(
                    insertResult.insertedRecords,
                    req.isFollow,
                    req.isFavorite,
                    req.isRecentViewed
                );

                res.success = true;
                res.recordsCreated = insertResult.recordsCreated;
                res.recordDetailsJson = insertResult.recordDetailsJson;
                res.message = 'Successfully saved ' + insertResult.recordsCreated + ' record(s).';

            } catch (Exception e) {
                res.success = false;
                res.message = 'Error saving records: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'RecordManager Error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            }

            results.add(res);
        }

        return results;
    }

    /**
     * Result wrapper for parseAndInsertRecords
     */
    private class InsertResult {
        public Integer recordsCreated;
        public String recordDetailsJson;
        public List<SObject> insertedRecords;

        public InsertResult(Integer recordsCreated, String recordDetailsJson, List<SObject> insertedRecords) {
            this.recordsCreated = recordsCreated;
            this.recordDetailsJson = recordDetailsJson;
            this.insertedRecords = insertedRecords;
        }
    }

    /**
     * Parse JSON response and insert records into Salesforce
     */
    private static InsertResult parseAndInsertRecords(
        String jsonResponse,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId
    ) {
        Savepoint sp = Database.setSavepoint();

        try {
            // Parse JSON array
            List<Object> recordsList = (List<Object>)JSON.deserializeUntyped(jsonResponse);

            if (recordsList == null || recordsList.isEmpty()) {
                throw new MockDataGeneratorUtils.MockDataGeneratorException('Empty or invalid JSON array');
            }

            System.debug('Parsed ' + recordsList.size() + ' records from JSON');

            // Get object type and parent info
            String objectType = rule.ObjectToGenerate__c;
            String parentObjectType = null;
            String parentFieldName = null;

            if (MockDataGeneratorUtils.isValidParentRecordId(parentRecordId)) {
                Id parentRecordIdAsId = parentRecordId;
                parentObjectType = parentRecordIdAsId.getSObjectType().getDescribe().getName();
                parentFieldName = MockDataGeneratorUtils.getParentFieldName(rule, parentObjectType);
            } else {
                parentObjectType = '_standalone';
            }

            System.debug('Object Type: ' + objectType);
            System.debug('Parent Object Type: ' + parentObjectType);
            System.debug('Parent Field Name: ' + parentFieldName);

            // Step 1: Apply pre-processing
            recordsList = applyPreProcessing(recordsList, rule, parentRecordId, parentObjectType);
            System.debug('After pre-processing: ' + recordsList.size() + ' records');

            // Step 2: Build list of SObjects to insert
            List<SObject> recordsToInsert = new List<SObject>();
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectType);

            if (sObjectType == null) {
                throw new MockDataGeneratorUtils.MockDataGeneratorException('Invalid object type: ' + objectType);
            }

            Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

            for (Object recordObj : recordsList) {
                Map<String, Object> recordMap = (Map<String, Object>)recordObj;
                SObject record = sObjectType.newSObject();

                // Set parent relationship
                if (String.isNotBlank(parentFieldName) &&
                    MockDataGeneratorUtils.isValidParentRecordId(parentRecordId) &&
                    !recordMap.containsKey(parentFieldName)) {
                    record.put(parentFieldName, parentRecordId);
                }

                // Map fields from JSON to SObject
                for (String fieldName : recordMap.keySet()) {
                    Object fieldValue = recordMap.get(fieldName);

                    if (fieldValue == null) {
                        continue;
                    }

                    try {
                        Schema.SObjectField field = fieldMap.get(fieldName.toLowerCase());
                        if (field != null) {
                            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                            if (fieldDescribe.isCreateable()) {
                                Object convertedValue = MockDataGeneratorUtils.convertFieldValue(
                                    fieldValue,
                                    fieldDescribe.getType(),
                                    fieldName
                                );
                                if (convertedValue != null) {
                                    record.put(fieldName, convertedValue);
                                }
                            } else {
                                System.debug(LoggingLevel.WARN, 'Field ' + fieldName + ' is not createable, skipping');
                            }
                        } else {
                            System.debug(LoggingLevel.WARN, 'Field ' + fieldName + ' does not exist on ' + objectType);
                        }
                    } catch (Exception e) {
                        System.debug(LoggingLevel.WARN, 'Could not set field ' + fieldName + ': ' + e.getMessage());
                    }
                }

                recordsToInsert.add(record);
            }

            if (recordsToInsert.isEmpty()) {
                throw new MockDataGeneratorUtils.MockDataGeneratorException('No valid records to insert after processing JSON');
            }

            System.debug('Attempting to insert ' + recordsToInsert.size() + ' records');

            // Step 3: Insert records
            Database.SaveResult[] results = Database.insert(recordsToInsert, false);

            Integer successCount = 0;
            List<String> errors = new List<String>();
            List<SObject> insertedRecords = new List<SObject>();

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successCount++;
                    recordsToInsert[i].Id = results[i].getId();
                    insertedRecords.add(recordsToInsert[i]);
                    System.debug('Successfully inserted record ' + i + ' with ID: ' + results[i].getId());
                } else {
                    String errorMsg = 'Record ' + i + ' failed: ';
                    for (Database.Error err : results[i].getErrors()) {
                        errorMsg += err.getStatusCode() + ' - ' + err.getMessage() + '; ';
                    }
                    errors.add(errorMsg);
                    System.debug(LoggingLevel.ERROR, errorMsg);
                }
            }

            if (successCount == 0) {
                Database.rollback(sp);
                throw new MockDataGeneratorUtils.MockDataGeneratorException(
                    'Failed to insert any records. Errors: ' + String.join(errors, ' | ')
                );
            }

            if (successCount < results.size()) {
                System.debug(LoggingLevel.WARN,
                    'Partial success: ' + successCount + ' of ' + results.size() + ' records inserted');
            }

            // Step 4: Apply post-processing
            applyPostProcessing(insertedRecords, rule, parentRecordId, parentObjectType);
            System.debug('Post-processing completed successfully');

            // Step 5: Build record details JSON
            String recordDetailsJson = enrichRecordsWithIds(recordsList, insertedRecords);

            // Note: User list actions (follow/favorite/recently viewed) are now handled
            // OUTSIDE this transaction in the saveRecords method to avoid callout errors

            return new InsertResult(successCount, recordDetailsJson, insertedRecords);

        } catch (JSONException e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'JSON parsing error: ' + e.getMessage());
            throw new MockDataGeneratorUtils.MockDataGeneratorException('Failed to parse JSON response: ' + e.getMessage());
        } catch (MockDataGeneratorUtils.MockDataGeneratorException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'Error inserting records: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            throw new MockDataGeneratorUtils.MockDataGeneratorException('Failed to insert records: ' + e.getMessage());
        }
    }

    /**
     * Enrich original records with assigned Salesforce IDs
     */
    private static String enrichRecordsWithIds(List<Object> recordsList, List<SObject> insertedRecords) {
        if (insertedRecords == null || insertedRecords.isEmpty()) {
            return '[]';
        }

        List<Map<String, Object>> enrichedRecords = new List<Map<String, Object>>();

        for (Integer i = 0; i < insertedRecords.size(); i++) {
            SObject insertedRecord = insertedRecords[i];

            Map<String, Object> originalRecord;
            if (i < recordsList.size()) {
                originalRecord = (Map<String, Object>)recordsList[i];
            } else {
                originalRecord = new Map<String, Object>();
            }

            Map<String, Object> enrichedRecord = new Map<String, Object>(originalRecord);
            enrichedRecord.put('Id', insertedRecord.Id);

            enrichedRecords.add(enrichedRecord);
        }

        return JSON.serialize(enrichedRecords);
    }


    /**
     * Apply pre-processing to records based on rule type
     */
    private static List<Object> applyPreProcessing(
        List<Object> recordsList,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId,
        String parentObjectType
    ) {
        String ruleType = rule.Name;
        System.debug('Applying pre-processing for rule type: ' + ruleType);

        // General preprocessing: Handle External_ID__c if present
        recordsList = applyExternalIdProcessing(recordsList, rule.ObjectToGenerate__c);

        // Rule-specific preprocessing
        if (ruleType == 'email') {
            return preProcessEmail(recordsList, rule, parentRecordId, parentObjectType);
        } else if (ruleType == 'event') {
            return preProcessEvent(recordsList, rule, parentRecordId, parentObjectType);
        } else if (ruleType == 'contact') {
            return preProcessContact(recordsList, rule, parentRecordId, parentObjectType);
        }

        return recordsList;
    }

    /**
     * Check if object has External_ID__c field marked as external ID and populate it
     */
    private static List<Object> applyExternalIdProcessing(List<Object> recordsList, String objectApiName) {
        try {
            // Check if object has External_ID__c field that is an external ID
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjectType == null) {
                return recordsList;
            }

            Map<String, Schema.SObjectField> fieldsMap = sObjectType.getDescribe().fields.getMap();
            Schema.SObjectField externalIdField = fieldsMap.get('external_id__c');

            if (externalIdField == null) {
                System.debug('No External_ID__c field found on ' + objectApiName);
                return recordsList;
            }

            Schema.DescribeFieldResult fieldDescribe = externalIdField.getDescribe();
            if (!fieldDescribe.isExternalId()) {
                System.debug('External_ID__c exists but is not marked as external ID on ' + objectApiName);
                return recordsList;
            }

            System.debug('Found External_ID__c field on ' + objectApiName + ', generating auto-numbers');

            // Get the next sequence number
            Integer nextSequence = getNextExternalIdSequence(objectApiName);

            // Populate External_ID__c for each record
            for (Object recordObj : recordsList) {
                Map<String, Object> recordMap = (Map<String, Object>) recordObj;
                String externalId = 'AI_' + objectApiName + '.' + String.valueOf(nextSequence).leftPad(4, '0');
                recordMap.put('External_ID__c', externalId);
                System.debug('Generated External ID: ' + externalId);
                nextSequence++;
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error processing External_ID__c: ' + e.getMessage());
        }

        return recordsList;
    }

    /**
     * Query existing records to find the highest External_ID__c number and return next sequence
     */
    private static Integer getNextExternalIdSequence(String objectApiName) {
        try {
            String prefix = 'AI_' + objectApiName + '.';
            String soql = 'SELECT External_ID__c FROM ' + String.escapeSingleQuotes(objectApiName) +
                         ' WHERE External_ID__c LIKE \'' + String.escapeSingleQuotes(prefix) + '%\'' +
                         ' ORDER BY External_ID__c DESC LIMIT 1';

            List<SObject> records = Database.query(soql);

            if (records.isEmpty()) {
                System.debug('No existing External_ID__c records found, starting from 1');
                return 1;
            }

            String lastExternalId = (String) records[0].get('External_ID__c');
            System.debug('Last External ID found: ' + lastExternalId);

            // Extract the number part after the dot
            if (lastExternalId.contains('.')) {
                String numberPart = lastExternalId.substringAfter('.');
                try {
                    Integer lastNumber = Integer.valueOf(numberPart);
                    Integer nextNumber = lastNumber + 1;
                    System.debug('Next sequence number: ' + nextNumber);
                    return nextNumber;
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Could not parse number from External ID: ' + lastExternalId);
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error querying for existing External IDs: ' + e.getMessage());
        }

        // Default to 1 if any error occurs
        return 1;
    }

    private static List<Object> preProcessEmail(
        List<Object> recordsList,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId,
        String parentObjectType
    ) {
        System.debug('Pre-processing EmailMessage records for parent type: ' + parentObjectType);
        return recordsList;
    }

    private static List<Object> preProcessEvent(
        List<Object> recordsList,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId,
        String parentObjectType
    ) {
        System.debug('Pre-processing Event records for parent type: ' + parentObjectType);

        for (Object recordObj : recordsList) {
            Map<String, Object> recordMap = (Map<String, Object>)recordObj;

            if (recordMap.containsKey('startDateTime') && recordMap.containsKey('endDateTime')) {
                String startDateTimeStr = String.valueOf(recordMap.get('startDateTime'));
                String endDateTimeStr = String.valueOf(recordMap.get('endDateTime'));

                try {
                    Datetime startDt = MockDataGeneratorUtils.parseDatetime(startDateTimeStr);
                    Datetime endDt = MockDataGeneratorUtils.parseDatetime(endDateTimeStr);

                    if (endDt <= startDt) {
                        System.debug(LoggingLevel.WARN, 'EndDateTime is not after StartDateTime, fixing...');
                        Integer duration = recordMap.containsKey('durationInMinutes') ?
                            (Integer)recordMap.get('durationInMinutes') : 60;
                        recordMap.put('endDateTime', startDt.addMinutes(duration).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                    }

                    if (!recordMap.containsKey('activityDate')) {
                        recordMap.put('activityDate', startDt.format('yyyy-MM-dd'));
                    }

                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Error processing Event date/time fields: ' + e.getMessage());
                }
            }
            else if (recordMap.containsKey('activityDate') && recordMap.containsKey('durationInMinutes')) {
                try {
                    String activityDateStr = String.valueOf(recordMap.get('activityDate'));
                    Integer duration = (Integer)recordMap.get('durationInMinutes');

                    Time startTime = Time.newInstance(9, 0, 0, 0);
                    if (recordMap.containsKey('startTime')) {
                        String startTimeStr = String.valueOf(recordMap.get('startTime'));
                        startTime = MockDataGeneratorUtils.parseTime(startTimeStr);
                    }

                    Date activityDate = Date.valueOf(activityDateStr);
                    Datetime startDt = Datetime.newInstance(activityDate, startTime);
                    Datetime endDt = startDt.addMinutes(duration);

                    recordMap.put('startDateTime', startDt.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                    recordMap.put('endDateTime', endDt.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));

                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Error calculating Event DateTime fields: ' + e.getMessage());
                }
            }
        }

        return recordsList;
    }

    private static List<Object> preProcessContact(
        List<Object> recordsList,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId,
        String parentObjectType
    ) {
        System.debug('Pre-processing Contact records for parent type: ' + parentObjectType);

        for (Object recordObj : recordsList) {
            Map<String, Object> recordMap = (Map<String, Object>)recordObj;

            for (String fieldName : new List<String>{'firstName', 'lastName', 'title', 'email', 'phone', 'description'}) {
                if (recordMap.containsKey(fieldName) && recordMap.get(fieldName) != null) {
                    String fieldValue = String.valueOf(recordMap.get(fieldName));
                    fieldValue = fieldValue
                        .replaceAll('[\u00A0\u2007\u202F]', ' ')
                        .replaceAll('[\u2018\u2019]', '\'')
                        .replaceAll('[\u201C\u201D]', '"')
                        .trim();
                    recordMap.put(fieldName, fieldValue);
                }
            }
        }

        return recordsList;
    }

    /**
     * Apply post-processing after records are inserted
     */
    private static void applyPostProcessing(
        List<SObject> insertedRecords,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId,
        String parentObjectType
    ) {
        String ruleType = rule.Name;
        System.debug('Applying post-processing for rule type: ' + ruleType);

        if (ruleType == 'email') {
            postProcessEmail(insertedRecords, rule, parentRecordId, parentObjectType);
        }
    }

    /**
     * Post-process EmailMessage records
     */
    private static void postProcessEmail(
        List<SObject> emailMessages,
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentRecordId,
        String parentObjectType
    ) {
        if (emailMessages == null || emailMessages.isEmpty()) {
            System.debug('No EmailMessage records provided for post-processing');
            return;
        }

        System.debug('Post-processing ' + emailMessages.size() + ' EmailMessage records for parent type: ' + parentObjectType);

        try {
            String currentUserEmail = UserInfo.getUserEmail();
            Id currentUserId = UserInfo.getUserId();

            Id parentRecordIdAsId = null;
            if (MockDataGeneratorUtils.isValidParentRecordId(parentRecordId)) {
                parentRecordIdAsId = parentRecordId;
            }

            Boolean isContactOrLead = (parentObjectType == 'Contact' || parentObjectType == 'Lead');

            Map<Id, Boolean> emailIncomingMap = new Map<Id, Boolean>();
            List<Id> emailMessageIds = new List<Id>();

            for (SObject record : emailMessages) {
                Id emailId = record.Id;
                Boolean incoming = (Boolean)record.get('Incoming');
                emailIncomingMap.put(emailId, incoming);
                emailMessageIds.add(emailId);
            }

            List<EmailMessageRelation> relations = [
                SELECT Id, EmailMessageId, RelationId, RelationType, RelationAddress
                FROM EmailMessageRelation
                WHERE EmailMessageId IN :emailMessageIds
                AND RelationType IN ('FromAddress', 'ToAddress')
            ];

            if (relations.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No EmailMessageRelation records found');
                return;
            }

            List<EmailMessageRelation> relationsToUpdate = new List<EmailMessageRelation>();

            for (EmailMessageRelation rel : relations) {
                Boolean isIncoming = emailIncomingMap.get(rel.EmailMessageId);
                String relationAddress = rel.RelationAddress;

                Boolean shouldUpdate = false;
                Id newRelationId = null;

                if (isIncoming != null && isIncoming == true) {
                    if (isContactOrLead && rel.RelationType == 'FromAddress') {
                        shouldUpdate = true;
                        newRelationId = parentRecordIdAsId;
                    } else if (rel.RelationType == 'ToAddress' && relationAddress == currentUserEmail) {
                        shouldUpdate = true;
                        newRelationId = currentUserId;
                    }
                } else if (isIncoming != null && isIncoming == false) {
                    if (isContactOrLead && rel.RelationType == 'ToAddress') {
                        shouldUpdate = true;
                        newRelationId = parentRecordIdAsId;
                    } else if (rel.RelationType == 'FromAddress' && relationAddress == currentUserEmail) {
                        shouldUpdate = true;
                        newRelationId = currentUserId;
                    }
                }

                if (shouldUpdate && newRelationId != null) {
                    rel.RelationId = newRelationId;
                    relationsToUpdate.add(rel);
                }
            }

            if (!relationsToUpdate.isEmpty()) {
                update relationsToUpdate;
                System.debug('Successfully updated ' + relationsToUpdate.size() + ' EmailMessageRelation records');
            }

        } catch (Exception e) {
            throw new MockDataGeneratorUtils.MockDataGeneratorException(
                'Unexpected error in email post-processing: ' + e.getMessage()
            );
        }
    }

    /**
     * Apply user-specific actions after records are inserted based on request flags
     */
    private static void applyUserListActions(
        List<SObject> insertedRecords,
        Boolean followRecords,
        Boolean favoriteRecords,
        Boolean recentViewedRecords
    ) {
        if (insertedRecords == null || insertedRecords.isEmpty()) {
            return;
        }

        List<Id> recordIds = new List<Id>();
        for (SObject record : insertedRecords) {
            if (record != null && record.Id != null) {
                recordIds.add(record.Id);
            }
        }

        if (recordIds.isEmpty()) {
            return;
        }

        if (followRecords == true) {
            followGeneratedRecords(recordIds);
        }

        if (favoriteRecords == true) {
            // Extract record info for future method (must be serializable)
            List<String> recordIdsForFavorite = new List<String>();
            List<String> recordNamesForFavorite = new List<String>();

            for (SObject record : insertedRecords) {
                recordIdsForFavorite.add(record.Id);
                recordNamesForFavorite.add(getRecordName(record));
            }

            favoriteGeneratedRecordsFuture(recordIdsForFavorite, recordNamesForFavorite);
        }

        if (recentViewedRecords == true) {
            addGeneratedRecordsToRecentItems(recordIds);
        }
    }

    private static void followGeneratedRecords(List<Id> recordIds) {
        try {
            Set<Id> uniqueIds = new Set<Id>(recordIds);
            if (uniqueIds.isEmpty()) {
                return;
            }

            Id currentUserId = UserInfo.getUserId();
            List<EntitySubscription> subscriptions = new List<EntitySubscription>();

            for (Id recordId : uniqueIds) {
                subscriptions.add(new EntitySubscription(
                    SubscriberId = currentUserId,
                    ParentId = recordId
                ));
            }

            if (subscriptions.isEmpty()) {
                return;
            }

            Database.SaveResult[] followResults = Database.insert(subscriptions, false);
            for (Integer i = 0; i < followResults.size(); i++) {
                if (!followResults[i].isSuccess()) {
                    String errorMsg = 'Failed to follow record ' + subscriptions[i].ParentId + ': ';
                    for (Database.Error err : followResults[i].getErrors()) {
                        errorMsg += err.getStatusCode() + ' - ' + err.getMessage() + '; ';
                    }
                    System.debug(LoggingLevel.WARN, errorMsg);
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Unable to create follow subscriptions: ' + e.getMessage());
        }
    }

    /**
     * Future method to add records to favorites via HTTP callout
     * Must be @future(callout=true) because HTTP callouts cannot be made in same transaction as DML
     */
    @future(callout=true)
    private static void favoriteGeneratedRecordsFuture(List<String> recordIds, List<String> recordNames) {
        try {
            if (recordIds == null || recordIds.isEmpty()) {
                return;
            }

            // Get the org's endpoint and session ID
            String sessionId = UserInfo.getSessionId();
            String endpoint = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v65.0/ui-api/favorites';

            Integer successCount = 0;
            Integer failureCount = 0;

            // Make HTTP callout for each record to add it to favorites
            for (Integer i = 0; i < recordIds.size(); i++) {
                try {
                    String recordId = recordIds[i];
                    String recordName = i < recordNames.size() ? recordNames[i] : recordId;

                    // Build the request payload
                    Map<String, Object> payload = new Map<String, Object>{
                        'name' => recordName,
                        'sortOrder' => 1,
                        'target' => recordId,
                        'targetType' => 'Record'
                    };

                    // Create HTTP request
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(endpoint);
                    req.setMethod('POST');
                    req.setHeader('Authorization', 'Bearer ' + sessionId);
                    req.setHeader('Content-Type', 'application/json');
                    req.setBody(JSON.serialize(payload));
                    req.setTimeout(60000);

                    // Send request
                    Http http = new Http();
                    HttpResponse res = http.send(req);

                    if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                        successCount++;
                        System.debug('Successfully added record ' + recordId + ' to favorites');
                    } else {
                        failureCount++;
                        System.debug(LoggingLevel.WARN, 'Failed to favorite record ' + recordId +
                                    '. Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
                    }

                } catch (Exception e) {
                    failureCount++;
                    System.debug(LoggingLevel.WARN, 'Error favoriting record ' + recordIds[i] + ': ' + e.getMessage());
                }
            }

            System.debug('Favorites operation completed: ' + successCount + ' succeeded, ' + failureCount + ' failed');

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Unable to add favorites: ' + e.getMessage());
        }
    }

    /**
     * Helper method to get a record's name for favorites
     */
    private static String getRecordName(SObject record) {
        Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();

        for(String fieldName: new List<String>{'Name', 'Subject', 'Title'}) {
            if (populatedFields.containsKey(fieldName)) {
                return String.valueOf(populatedFields.get(fieldName));
            }
        }

        return '';
    }

    private static void addGeneratedRecordsToRecentItems(List<Id> recordIds) {
        try {
            Set<Id> uniqueIds = new Set<Id>(recordIds);
            if (uniqueIds.isEmpty()) {
                return;
            }

            // Use a workaround: perform a query on each record to trigger Salesforce's automatic
            // recently viewed tracking. This is more reliable than ConnectApi which may not be available.
            Map<Id, Schema.SObjectType> idToTypeMap = new Map<Id, Schema.SObjectType>();
            for (Id recordId : uniqueIds) {
                idToTypeMap.put(recordId, recordId.getSObjectType());
            }

            // Group records by object type for efficient querying
            Map<Schema.SObjectType, List<Id>> typeToIdsMap = new Map<Schema.SObjectType, List<Id>>();
            for (Id recordId : uniqueIds) {
                Schema.SObjectType objType = idToTypeMap.get(recordId);
                if (!typeToIdsMap.containsKey(objType)) {
                    typeToIdsMap.put(objType, new List<Id>());
                }
                typeToIdsMap.get(objType).add(recordId);
            }

            // Query records grouped by type to trigger recently viewed tracking
            for (Schema.SObjectType objType : typeToIdsMap.keySet()) {
                try {
                    String objectName = objType.getDescribe().getName();
                    List<Id> idsForType = typeToIdsMap.get(objType);
                    String soql = 'SELECT Id FROM ' + String.escapeSingleQuotes(objectName) +
                                 ' WHERE Id IN :idsForType LIMIT ' + idsForType.size() + ' FOR VIEW';
                    List<SObject> queriedRecords = Database.query(soql);
                    System.debug('Triggered recently viewed tracking for ' + queriedRecords.size() + ' ' + objectName + ' records');
                } catch (Exception innerEx) {
                    System.debug(LoggingLevel.WARN, 'Unable to add records to recent items for type ' + objType + ': ' + innerEx.getMessage());
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Recent items processing failed: ' + e.getMessage());
        }
    }
}