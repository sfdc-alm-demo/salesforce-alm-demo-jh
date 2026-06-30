/**
 * Shared utility methods for Mock Data Generator
 *
 * Responsibilities:
 * - LLM API calls and response cleaning
 * - Field type conversion utilities
 * - Date/time parsing helpers
 * - Merge field resolution
 * - Object type extraction from IDs
 * - Common validation helpers
 * - Parent record data retrieval (including related records for context)
 *
 * Design Principles Applied:
 * - DRY (Don't Repeat Yourself): Centralizes common utility functions
 * - Single Responsibility: Each method has one clear purpose
 * - Reusability: All methods are static and stateless for easy reuse
 * - Defensive Programming: Handles missing objects/fields gracefully
 * - Security: Respects field-level security (isAccessible checks)
 */
public with sharing class MockDataGeneratorUtils {

    // ========================================================================
    // Constants
    // ========================================================================

    // Default LLM model for data generation
    private static final String DEFAULT_LLM_MODEL = 'sfdc_ai__DefaultVertexAIGemini25Flash001';

    /**
     * Custom exception class
     */
    public class MockDataGeneratorException extends Exception {}

    // ========================================================================
    // LLM and JSON Utilities
    // ========================================================================

    /**
     * Generate content using LLM with the provided prompt
     */
    public static String generateWithLLM(String prompt, String modelName) {
        try {
            aiplatform.ModelsAPI.createGenerations_Request request =
                new aiplatform.ModelsAPI.createGenerations_Request();

            request.modelName = String.isNotBlank(modelName) ? modelName : DEFAULT_LLM_MODEL;

            aiplatform.ModelsAPI_GenerationRequest requestBody =
                new aiplatform.ModelsAPI_GenerationRequest();
            request.body = requestBody;
            requestBody.prompt = prompt;

            aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response =
                modelsAPI.createGenerations(request);

            String responseText = response.Code200.generation.generatedText;
            System.debug('LLM Response (raw): ' + responseText);

            responseText = cleanJsonResponse(responseText);
            return responseText;

        } catch(aiplatform.ModelsAPI.createGenerations_ResponseException e) {
            System.debug(LoggingLevel.ERROR, 'LLM API Error - Response code: ' + e.responseCode);
            System.debug(LoggingLevel.ERROR, 'Exception: ' + e.getMessage());
            throw new MockDataGeneratorException('Failed to generate data from LLM (API Error): ' + e.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected error calling LLM: ' + e.getMessage());
            throw new MockDataGeneratorException('Failed to generate data from LLM: ' + e.getMessage());
        }
    }

    /**
     * Clean JSON response by removing markdown code blocks
     */
    public static String cleanJsonResponse(String responseText) {
        if (String.isBlank(responseText)) {
            throw new MockDataGeneratorException('LLM returned empty response');
        }

        responseText = responseText.trim();

        if (responseText.startsWith('```json')) {
            responseText = responseText.substring(7);
        }
        if (responseText.startsWith('```')) {
            responseText = responseText.substring(3);
        }
        if (responseText.endsWith('```')) {
            responseText = responseText.substring(0, responseText.length() - 3);
        }

        return responseText.trim();
    }

    // ========================================================================
    // Field Type Conversion Utilities
    // ========================================================================

    /**
     * Convert JSON field value to appropriate Salesforce field type
     */
    public static Object convertFieldValue(Object value, Schema.DisplayType fieldType, String fieldName) {
        try {
            if (value == null) {
                return null;
            }

            String valueStr = String.valueOf(value).trim();

            if (String.isBlank(valueStr)) {
                return null;
            }

            switch on fieldType {
                when DATE {
                    return Date.valueOf(valueStr);
                }
                when DATETIME {
                    return parseDatetime(valueStr);
                }
                when TIME {
                    return parseTime(valueStr);
                }
                when BOOLEAN {
                    if (value instanceof Boolean) {
                        return value;
                    }
                    String lowerVal = valueStr.toLowerCase();
                    return lowerVal == 'true' || lowerVal == '1' || lowerVal == 'yes';
                }
                when INTEGER {
                    if (value instanceof Integer) {
                        return value;
                    }
                    return Integer.valueOf(valueStr);
                }
                when LONG {
                    if (value instanceof Long) {
                        return value;
                    }
                    return Long.valueOf(valueStr);
                }
                when DOUBLE, CURRENCY, PERCENT {
                    if (value instanceof Decimal) {
                        return value;
                    }
                    if (value instanceof Double) {
                        return value;
                    }
                    return Decimal.valueOf(valueStr);
                }
                when else {
                    return valueStr;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting field ' + fieldName + ' to ' + fieldType + ': ' + e.getMessage());
            return null;
        }
    }

    /**
     * Parse datetime string with support for multiple formats
     */
    public static Datetime parseDatetime(String datetimeStr) {
        try {
            datetimeStr = datetimeStr.replace('Z', '');

            if (datetimeStr.contains('T')) {
                datetimeStr = datetimeStr.replace('T', ' ');

                if (datetimeStr.contains('.')) {
                    datetimeStr = datetimeStr.substringBefore('.');
                }

                return Datetime.valueOf(datetimeStr);
            }

            return Datetime.valueOf(datetimeStr);

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error parsing datetime: ' + datetimeStr + ' - ' + e.getMessage());
            try {
                Date d = Date.valueOf(datetimeStr);
                return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
            } catch (Exception ex) {
                throw new MockDataGeneratorException('Unable to parse datetime: ' + datetimeStr);
            }
        }
    }

    /**
     * Parse time string in format HH:MM:SS or HH:MM:SS.mmm
     */
    public static Time parseTime(String timeStr) {
        try {
            if (String.isBlank(timeStr)) {
                return Time.newInstance(9, 0, 0, 0);
            }

            timeStr = timeStr.trim();
            List<String> parts = timeStr.split(':');

            if (parts.size() >= 2) {
                Integer hours = Integer.valueOf(parts[0]);
                Integer minutes = Integer.valueOf(parts[1]);
                Integer seconds = 0;
                Integer milliseconds = 0;

                if (parts.size() >= 3) {
                    String secondsPart = parts[2];
                    if (secondsPart.contains('.')) {
                        List<String> secParts = secondsPart.split('\\.');
                        seconds = Integer.valueOf(secParts[0]);
                        if (secParts.size() > 1) {
                            milliseconds = Integer.valueOf(secParts[1].substring(0, Math.min(3, secParts[1].length())));
                        }
                    } else {
                        seconds = Integer.valueOf(secondsPart);
                    }
                }

                return Time.newInstance(hours, minutes, seconds, milliseconds);
            }

            throw new MockDataGeneratorException('Invalid time format: ' + timeStr);

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error parsing time: ' + timeStr + ' - ' + e.getMessage());
            return Time.newInstance(9, 0, 0, 0);
        }
    }

    // ========================================================================
    // Schema Analysis Utilities
    // ========================================================================

    /**
     * Helper class for object field analysis
     */
    public class ObjectFieldInfo {
        public String fieldName;
        public String fieldLabel;
        public String fieldType;
    }

    /**
     * Extract relevant fields from an object for example structure
     * Includes: text, date/time, numeric, and boolean fields
     */
    public static List<ObjectFieldInfo> getFieldsForObject(String objectApiName) {
        List<ObjectFieldInfo> fields = new List<ObjectFieldInfo>();

        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                return fields;
            }

            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            // Field types to include for example data
            Set<Schema.DisplayType> includedTypes = new Set<Schema.DisplayType>{
                // Text-based
                Schema.DisplayType.STRING,
                Schema.DisplayType.TEXTAREA,
                Schema.DisplayType.EMAIL,
                Schema.DisplayType.PHONE,
                Schema.DisplayType.URL,
                Schema.DisplayType.PICKLIST,
                Schema.DisplayType.MULTIPICKLIST,
                // Date/Time
                Schema.DisplayType.DATE,
                Schema.DisplayType.DATETIME,
                Schema.DisplayType.TIME,
                // Numeric
                Schema.DisplayType.INTEGER,
                Schema.DisplayType.DOUBLE,
                Schema.DisplayType.CURRENCY,
                Schema.DisplayType.PERCENT,
                // Boolean
                Schema.DisplayType.BOOLEAN
            };

            for (String fieldName : fieldsMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();

                // Only include specified field types
                if (!includedTypes.contains(fieldDescribe.getType())) {
                    continue;
                }

                // Skip read-only fields (formula, auto-number, roll-up summary, etc.)
                if (!fieldDescribe.isCreateable()) {
                    continue;
                }

                // Skip system fields
                if (!fieldDescribe.isCustom() && (
                    fieldName.endsWith('Id') ||
                    fieldName == 'CreatedDate' ||
                    fieldName == 'LastModifiedDate' ||
                    fieldName == 'SystemModstamp' ||
                    fieldName == 'IsDeleted' ||
                    fieldName == 'CreatedById' ||
                    fieldName == 'LastModifiedById'
                )) {
                    continue;
                }

                // Skip formula and system-calculated fields (additional safeguard)
                if (fieldDescribe.isCalculated()) {
                    continue;
                }

                ObjectFieldInfo fieldInfo = new ObjectFieldInfo();
                fieldInfo.fieldName = fieldDescribe.getName();
                fieldInfo.fieldLabel = fieldDescribe.getLabel();
                fieldInfo.fieldType = String.valueOf(fieldDescribe.getType());
                fields.add(fieldInfo);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting fields for ' + objectApiName + ': ' + e.getMessage());
        }

        return fields;
    }

    /**
     * Find relationship fields that point to allowed parent objects
     * Returns a map of parentObjectApiName -> fieldApiName
     */
    public static Map<String, String> getRelationshipFields(String objectApiName, String allowedParentObjectsStr) {
        Map<String, String> relationshipFields = new Map<String, String>();

        try {
            if (String.isBlank(allowedParentObjectsStr)) {
                return relationshipFields;
            }

            // Parse allowed parent objects
            Set<String> allowedParents = new Set<String>();
            for (String parentObj : allowedParentObjectsStr.split(',')) {
                String trimmed = parentObj.trim();
                if (!String.isBlank(trimmed) && trimmed != '_standalone') {
                    allowedParents.add(trimmed);
                }
            }

            if (allowedParents.isEmpty()) {
                return relationshipFields;
            }

            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                return relationshipFields;
            }

            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            for (Schema.SObjectField field : fieldsMap.values()) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                // Check if it's a reference field (lookup or master-detail)
                if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
                    List<Schema.SObjectType> referenceTypes = fieldDescribe.getReferenceTo();
                    for (Schema.SObjectType refType : referenceTypes) {
                        String refTypeName = refType.getDescribe().getName();
                        if (allowedParents.contains(refTypeName)) {
                            relationshipFields.put(refTypeName, fieldDescribe.getName());
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting relationship fields for ' + objectApiName + ': ' + e.getMessage());
        }

        return relationshipFields;
    }

    // ========================================================================
    // Rule Management
    // ========================================================================

    /**
     * Rule cache wrapper class - used internally by validator and other components
     */
    public class RuleCache {
        public Map<String, Demo_Assist_Mock_Data_Generator_Rule__c> rulesByName;
        public String rulesJson;

        public RuleCache(Map<String, Demo_Assist_Mock_Data_Generator_Rule__c> rulesByName, String rulesJson) {
            this.rulesByName = rulesByName;
            this.rulesJson = rulesJson;
        }
    }

    /**
     * Load all active rules and build cache with JSON for AI/LLM use
     *
     * This method is used internally by the validator and other components
     * that need access to the full rule cache.
     *
     * @return RuleCache containing map of rules and JSON representation
     */
    public static RuleCache loadAndCacheRules() {
        List<Demo_Assist_Mock_Data_Generator_Rule__c> allRules = [
            SELECT Name, Rule_Description__c, ObjectToGenerate__c,
                   AllowedParentObjects__c, IsActive__c, DefaultCount__c,
                   ObjectDescription__c, ExampleJsonData__c
            FROM Demo_Assist_Mock_Data_Generator_Rule__c
            WHERE IsActive__c = true
        ];

        Map<String, Demo_Assist_Mock_Data_Generator_Rule__c> rulesByName = new Map<String, Demo_Assist_Mock_Data_Generator_Rule__c>();
        List<Map<String, Object>> ruleList = new List<Map<String, Object>>();

        for (Demo_Assist_Mock_Data_Generator_Rule__c rule : allRules) {
            rulesByName.put(rule.Name, rule);

            // Build minimal JSON for AI - include Name, ObjectToGenerate, Rule_Description, and DefaultCount
            Map<String, Object> ruleMap = new Map<String, Object>();
            ruleMap.put('Name', rule.Name);
            ruleMap.put('ObjectToGenerate', rule.ObjectToGenerate__c);
            ruleMap.put('Rule_Description', rule.Rule_Description__c);
            ruleMap.put('DefaultCount', rule.DefaultCount__c);
            ruleList.add(ruleMap);
        }

        String rulesJson = JSON.serialize(ruleList);
        return new RuleCache(rulesByName, rulesJson);
    }

    /**
     * Request class for Get Available Rules invocable method
     */
    public class GetAvailableRulesRequest {
        @InvocableVariable(
            label='Parent Record ID'
            description='Optional: The ID of a parent record to show compatible rules (leave blank to show all rules)'
            required=false
        )
        public String parentRecordId;
    }

    /**
     * Response class for Get Available Rules invocable method
     */
    public class GetAvailableRulesResponse {
        @InvocableVariable(
            label='Available Rules JSON'
            description='JSON array containing all available mock data generation rules with their descriptions'
        )
        public String rulesJson;

        @InvocableVariable(
            label='Rule Count'
            description='Total number of available active rules'
        )
        public Integer ruleCount;

        @InvocableVariable(
            label='Supported Objects'
            description='Comma-separated list of objects that can be generated'
        )
        public String supportedObjects;

        public GetAvailableRulesResponse(String rulesJson, Integer ruleCount, String supportedObjects) {
            this.rulesJson = rulesJson;
            this.ruleCount = ruleCount;
            this.supportedObjects = supportedObjects;
        }
    }

    /**
     * Get available mock data generation rules - designed for agent/flow access
     *
     * This invocable method allows agents and flows to query what objects
     * the mock data generator can create, helping answer questions like:
     * - "What objects can you generate?"
     * - "What data types are supported?"
     * - "Show me available rules"
     *
     * If parentRecordId is provided, each rule will include an "IsCompatibleWithParent"
     * field indicating whether the rule supports that parent object type.
     *
     * @param requests List of GetAvailableRulesRequest with optional parentRecordId
     * @return List of GetAvailableRulesResponse with rule information
     */
    @InvocableMethod(
        label='Get Available Mock Data Rules'
        description='Returns all available mock data generation rules so user can know what objects can be generated/supported'
    )
    public static List<GetAvailableRulesResponse> getAvailableRules(List<GetAvailableRulesRequest> requests) {
        GetAvailableRulesRequest req = requests.isEmpty() ? new GetAvailableRulesRequest() : requests[0];
        RuleCache cache = loadAndCacheRules();

        // Determine parent object type if parentRecordId is provided
        String parentObjectType = null;
        if (String.isNotBlank(req.parentRecordId)) {
            try {
                parentObjectType = getObjectType(req.parentRecordId);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Could not determine parent object type: ' + e.getMessage());
            }
        }

        // Build enhanced rule list with compatibility indicator
        List<Map<String, Object>> ruleList = new List<Map<String, Object>>();
        Set<String> objectSet = new Set<String>();

        for (Demo_Assist_Mock_Data_Generator_Rule__c rule : cache.rulesByName.values()) {
            Map<String, Object> ruleMap = new Map<String, Object>();
            ruleMap.put('Name', rule.Name);
            ruleMap.put('ObjectToGenerate', rule.ObjectToGenerate__c);
            ruleMap.put('Rule_Description', rule.Rule_Description__c);
            ruleMap.put('DefaultCount', rule.DefaultCount__c);

            // Add compatibility indicator if parent context is provided
            if (String.isNotBlank(parentObjectType)) {
                Boolean isCompatible = isParentObjectAllowedForRule(rule, parentObjectType);
                ruleMap.put('IsCompatibleWithParent', isCompatible);
            }

            ruleList.add(ruleMap);

            // Collect unique objects
            if (String.isNotBlank(rule.ObjectToGenerate__c)) {
                objectSet.add(rule.ObjectToGenerate__c);
            }
        }

        List<String> objectList = new List<String>(objectSet);
        objectList.sort();
        String supportedObjects = String.join(objectList, ', ');
        String rulesJson = JSON.serialize(ruleList);

        GetAvailableRulesResponse response = new GetAvailableRulesResponse(
            rulesJson,
            cache.rulesByName.size(),
            supportedObjects
        );

        return new List<GetAvailableRulesResponse>{ response };
    }

    /**
     * Helper method to check if a rule allows a specific parent object type
     */
    private static Boolean isParentObjectAllowedForRule(Demo_Assist_Mock_Data_Generator_Rule__c rule, String parentObjectType) {
        if (String.isBlank(rule.AllowedParentObjects__c)) {
            return false;
        }

        try {
            Map<String, Object> allowedParentsMap = (Map<String, Object>)
                JSON.deserializeUntyped(rule.AllowedParentObjects__c);
            return allowedParentsMap.containsKey(parentObjectType);
        } catch (Exception e) {
            return false;
        }
    }

    // ========================================================================
    // Validation Helpers
    // ========================================================================

    /**
     * Get the object type from a record ID
     */
    public static String getObjectType(String recordId) {
        Id recordIdAsId = recordId;
        return recordIdAsId.getSObjectType().getDescribe().getName();
    }

    /**
     * Get parent field name from rule for given parent object type
     *
     * @param rule The Mock Data Generator Rule
     * @param parentObjectType The parent object type (e.g., 'Account', 'Contact')
     * @return The field name on the child object that references the parent
     */
    public static String getParentFieldName(Demo_Assist_Mock_Data_Generator_Rule__c rule, String parentObjectType) {
        try {
            Map<String, Object> allowedParentsMap = (Map<String, Object>)
                JSON.deserializeUntyped(rule.AllowedParentObjects__c);

            Object fieldNameObj = allowedParentsMap.get(parentObjectType);
            if (fieldNameObj == null) {
                return null;
            }
            return String.valueOf(fieldNameObj);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not parse parent field name: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Validate if parent record ID is not blank
     *
     * @param parentRecordId The parent record ID to validate
     * @return True if parent record ID is not null and not blank
     */
    public static Boolean isValidParentRecordId(String parentRecordId) {
        return parentRecordId != null && String.isNotBlank(String.valueOf(parentRecordId));
    }

    // ========================================================================
    // Parent Record Data Retrieval
    // ========================================================================

    /**
     * Query parent record data including related records for better context
     *
     * This method retrieves standard text fields from a parent record and enriches
     * the data with related records (e.g., Contacts for Accounts) to provide
     * rich context for LLM prompt generation.
     *
     * @param recordId The ID of the parent record
     * @param objectType The API name of the parent object type
     * @return Map containing parent record field values and related records
     */
    public static Map<String, Object> getParentRecordData(String recordId, String objectType) {
        Map<String, Object> recordData = new Map<String, Object>();

        Id recordIdAsId = recordId;
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectType);
        if (sObjectType == null) {
            return recordData;
        }

        try {
            Schema.DescribeSObjectResult objectDescribe = sObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();

            List<String> fieldsToQuery = new List<String>();

            Set<Schema.DisplayType> textishTypes = new Set<Schema.DisplayType>{
                Schema.DisplayType.String,
                Schema.DisplayType.TextArea,
                Schema.DisplayType.Phone,
                Schema.DisplayType.Email,
                Schema.DisplayType.URL,
                Schema.DisplayType.Picklist,
                Schema.DisplayType.MultiPicklist,
                Schema.DisplayType.Address
            };

            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();

                if (fieldDescribe.isCustom() || !fieldDescribe.isAccessible()) {
                    continue;
                }

                if (textishTypes.contains(fieldDescribe.getType())) {
                    fieldsToQuery.add(fieldDescribe.getName());
                }
            }

            if (!fieldsToQuery.contains('Id')) {
                fieldsToQuery.add('Id');
            }

            if (!fieldsToQuery.isEmpty()) {
                String soqlQuery = 'SELECT ' + String.join(fieldsToQuery, ', ') +
                                   ' FROM ' + String.escapeSingleQuotes(objectType) +
                                   ' WHERE Id = \'' + recordIdAsId + '\'' +
                                   ' LIMIT 1';

                List<SObject> records = Database.query(soqlQuery);
                if (!records.isEmpty()) {
                    SObject record = records[0];
                    for (String fieldName : fieldsToQuery) {
                        Object value = record.get(fieldName);
                        if (value != null && String.valueOf(value).trim() != '') {
                            recordData.put(fieldName, value);
                        }
                    }
                }
            }

            // Add related records context
            addRelatedRecordsContext(recordData, recordIdAsId, objectType);

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error querying parent record data: ' + e.getMessage());
        }

        return recordData;
    }

    /**
     * Add related records to provide richer context for LLM
     *
     * Supports adding:
     * - Contacts for Account parent records
     * - Account for Contact/Opportunity parent records
     */
    private static void addRelatedRecordsContext(Map<String, Object> recordData, Id recordId, String objectType) {
        try {
            if (objectType == 'Account') {
                addRelatedContacts(recordData, recordId);
            } else if (objectType == 'Contact') {
                addRelatedAccount(recordData, recordId, 'AccountId');
            } else if (objectType == 'Opportunity') {
                addRelatedAccount(recordData, recordId, 'AccountId');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error adding related records: ' + e.getMessage());
        }
    }

    private static void addRelatedContacts(Map<String, Object> recordData, Id accountId) {
        try {
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone, Title
                FROM Contact
                WHERE AccountId = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];

            if (!contacts.isEmpty()) {
                List<Map<String, Object>> contactList = new List<Map<String, Object>>();
                for (Contact c : contacts) {
                    Map<String, Object> contactMap = new Map<String, Object>();
                    contactMap.put('Name', c.Name);
                    if (String.isNotBlank(c.Email)) contactMap.put('Email', c.Email);
                    if (String.isNotBlank(c.Phone)) contactMap.put('Phone', c.Phone);
                    if (String.isNotBlank(c.Title)) contactMap.put('Title', c.Title);
                    contactList.add(contactMap);
                }
                recordData.put('RelatedContacts', contactList);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error querying related contacts: ' + e.getMessage());
        }
    }

    private static void addRelatedAccount(Map<String, Object> recordData, Id parentRecordId, String accountFieldName) {
        try {
            String query = 'SELECT ' + String.escapeSingleQuotes(accountFieldName) + ' FROM ' +
                          parentRecordId.getSObjectType().getDescribe().getName() +
                          ' WHERE Id = \'' + parentRecordId + '\' LIMIT 1';

            SObject parentRecord = Database.query(query)[0];
            Id accountId = (Id)parentRecord.get(accountFieldName);

            if (accountId != null) {
                Account acc = [
                    SELECT Id, Name, Industry, Type, Website, Phone, BillingCity, BillingState, BillingCountry
                    FROM Account
                    WHERE Id = :accountId
                    LIMIT 1
                ];

                Map<String, Object> accountMap = new Map<String, Object>();
                accountMap.put('Name', acc.Name);
                if (String.isNotBlank(acc.Industry)) accountMap.put('Industry', acc.Industry);
                if (String.isNotBlank(acc.Type)) accountMap.put('Type', acc.Type);
                if (String.isNotBlank(acc.Website)) accountMap.put('Website', acc.Website);
                if (String.isNotBlank(acc.Phone)) accountMap.put('Phone', acc.Phone);
                if (String.isNotBlank(acc.BillingCity)) accountMap.put('BillingCity', acc.BillingCity);
                if (String.isNotBlank(acc.BillingState)) accountMap.put('BillingState', acc.BillingState);
                if (String.isNotBlank(acc.BillingCountry)) accountMap.put('BillingCountry', acc.BillingCountry);

                recordData.put('RelatedAccount', accountMap);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error querying related account: ' + e.getMessage());
        }
    }

    // ========================================================================
    // Merge Field Resolution
    // ========================================================================

    /**
     * Resolve supported merge fields inside a prompt
     *
     * Supported merge field namespaces:
     * - {!$User.FieldName} - Current user fields (e.g., Email, Name)
     * - {!$Parent.FieldName} - Parent record fields
     *
     * @param input The input string containing merge fields
     * @param parentRecordId The parent record ID (if any)
     * @param parentObjectType The parent object type (if any)
     * @param parentRecordData Map of parent record data
     * @return String with merge fields resolved to actual values
     */
    public static String resolveMergeFields(
        String input,
        String parentRecordId,
        String parentObjectType,
        Map<String, Object> parentRecordData
    ) {
        if (String.isBlank(input)) {
            return input;
        }

        List<String> tokens = new List<String>();
        Integer idx = 0;
        while (true) {
            Integer startPos = input.indexOf('{!', idx);
            if (startPos == -1) break;
            Integer endPos = input.indexOf('}', startPos);
            if (endPos == -1) break;
            String token = input.substring(startPos, endPos + 1);
            tokens.add(token);
            idx = endPos + 1;
        }

        if (tokens.isEmpty()) {
            return input;
        }

        Set<String> uniqueTokens = new Set<String>(tokens);

        Map<String, Set<String>> byNamespace = new Map<String, Set<String>>();
        for (String t : uniqueTokens) {
            String innerToken = t.substring(2, t.length() - 1);
            if (!innerToken.startsWith('$')) {
                continue;
            }
            Integer dotPos = innerToken.indexOf('.');
            if (dotPos == -1) {
                continue;
            }
            String ns = innerToken.substring(0, dotPos);
            String fieldPath = innerToken.substring(dotPos + 1);

            if (!byNamespace.containsKey(ns)) {
                byNamespace.put(ns, new Set<String>());
            }
            byNamespace.get(ns).add(fieldPath);
        }

        Map<String, Map<String, Object>> resolvedByNamespace = new Map<String, Map<String, Object>>();

        if (byNamespace.containsKey('$User')) {
            Map<String, Object> userValues = resolveUserFields(byNamespace.get('$User'));
            if (userValues != null) {
                resolvedByNamespace.put('$User', userValues);
            }
        }

        if (byNamespace.containsKey('$Parent')) {
            Map<String, Object> parentValues = resolveParentFields(byNamespace.get('$Parent'), parentRecordData);
            if (parentValues != null) {
                resolvedByNamespace.put('$Parent', parentValues);
            }
        }

        String output = input;
        for (String t : uniqueTokens) {
            String innerToken2 = (t.length() > 3) ? t.substring(2, t.length() - 1) : null;
            if (innerToken2 == null || !innerToken2.startsWith('$')) continue;

            Integer dotPos2 = innerToken2.indexOf('.');
            if (dotPos2 == -1) continue;

            String ns = innerToken2.substring(0, dotPos2);
            String fieldPath = innerToken2.substring(dotPos2 + 1);

            Map<String, Object> values = resolvedByNamespace.get(ns);
            if (values != null && values.containsKey(fieldPath)) {
                Object v = values.get(fieldPath);
                if (v != null) {
                    output = output.replace(t, String.valueOf(v));
                }
            }
        }

        return output;
    }

    private static Map<String, Object> resolveUserFields(Set<String> requestedFields) {
        Map<String, Object> out = new Map<String, Object>();
        if (requestedFields == null || requestedFields.isEmpty()) {
            return out;
        }

        Set<String> allowed = new Set<String>{
            'Id', 'Name', 'Email', 'Username', 'CompanyName', 'Title', 'Phone', 'LocaleSidKey', 'TimeZoneSidKey', 'Alias'
        };

        List<String> toQuery = new List<String>();
        for (String f : requestedFields) {
            if (String.isBlank(f) || f.contains('.')) {
                continue;
            }
            if (allowed.contains(f)) {
                toQuery.add(f);
            }
        }

        if (toQuery.isEmpty()) {
            return out;
        }

        if (!toQuery.contains('Id')) {
            toQuery.add('Id');
        }

        try {
            String userId = UserInfo.getUserId();
            String soql = 'SELECT ' + String.join(toQuery, ',') + ' FROM User WHERE Id = \'' + userId + '\' LIMIT 1';
            User u = (User) Database.query(soql)[0];

            for (String f : toQuery) {
                Object val = u.get(f);
                if (val != null) {
                    out.put(f, val);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'resolveUserFields query failed: ' + e.getMessage());
        }

        return out;
    }

    private static Map<String, Object> resolveParentFields(Set<String> requestedFields, Map<String, Object> parentRecordData) {
        Map<String, Object> out = new Map<String, Object>();
        if (requestedFields == null || requestedFields.isEmpty() || parentRecordData == null || parentRecordData.isEmpty()) {
            return out;
        }

        for (String f : requestedFields) {
            if (String.isBlank(f) || f.contains('.')) {
                continue;
            }

            if (parentRecordData.containsKey(f)) {
                Object v = parentRecordData.get(f);
                if (v != null) {
                    out.put(f, v);
                }
            }
        }
        return out;
    }
}