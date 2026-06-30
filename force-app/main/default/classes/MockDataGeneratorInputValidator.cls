/**
 * Validates user input and determines which Mock Data Generator rule to use
 *
 * Responsibilities:
 * - Validate user request inputs (instructions, dataTypeToGenerate, count, recordId)
 * - Load and cache available rules
 * - Use AI validator for ambiguous/missing inputs
 * - Check parent object compatibility
 * - Return ValidationResult with selected rule and context
 *
 * Security Note:
 * This class uses 'with sharing' to respect the running user's record-level
 * security when loading rules and validating parent records.
 *
 * Design Principles Applied:
 * - Single Responsibility: Focuses solely on input validation
 * - Dependency Inversion: Returns abstraction (serialized rule) to decouple from generator
 * - Fail Fast: Validates all inputs before passing to generator
 */
public with sharing class MockDataGeneratorInputValidator {

    /**
     * Request class for validation
     */
    public class Request {
        @InvocableVariable(
            label='Parent Record ID'
            description='The ID of the parent record to which generated data will be related (optional for standalone generation)'
            required=false
        )
        public String recordId;

        @InvocableVariable(
            label='User Instructions'
            description='Natural language instructions describing what data to generate (include industry context, specifics, language preferences, etc.). The AI will determine the data type and count from these instructions.'
            required=true
        )
        public String userInstructions;
    }

    /**
     * Validation result wrapper class
     */
    public class ValidationResult {
        @InvocableVariable(
            label='Is Valid'
            description='Whether the validation passed successfully'
        )
        public Boolean isValid;

        @InvocableVariable(
            label='Error Message'
            description='Error message if validation failed (null if successful)'
        )
        public String errorMessage;

        @InvocableVariable(
            label='Rule JSON'
            description='Serialized Demo_Assist_Mock_Data_Generator_Rule__c record to pass to the generation step'
        )
        public String ruleJson;

        @InvocableVariable(
            label='Parent Object Type'
            description='API name of the parent object type or "_standalone" for standalone generation'
        )
        public String parentObjectType;

        @InvocableVariable(
            label='Sanitized Count'
            description='Validated and sanitized record count to generate'
        )
        public Integer sanitizedCount;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }

        public ValidationResult(
            Demo_Assist_Mock_Data_Generator_Rule__c rule,
            String parentObjectType,
            Integer sanitizedCount
        ) {
            this(rule, parentObjectType, sanitizedCount, new Map<String, Object>());
        }

        public ValidationResult(
            Demo_Assist_Mock_Data_Generator_Rule__c rule,
            String parentObjectType,
            Integer sanitizedCount,
            Map<String, Object> extraInfo
        ) {
            this.isValid = true;
            RuleWithExtraInfo wrapper = new RuleWithExtraInfo(rule, extraInfo);
            this.ruleJson = JSON.serialize(wrapper);
            this.parentObjectType = parentObjectType;
            this.sanitizedCount = sanitizedCount;
        }
    }

    /**
     * Wrapper class to include both rule and extraInfo in JSON
     */
    public class RuleWithExtraInfo {
        public Demo_Assist_Mock_Data_Generator_Rule__c rule;
        public Map<String, Object> extraInfo;

        public RuleWithExtraInfo(Demo_Assist_Mock_Data_Generator_Rule__c rule, Map<String, Object> extraInfo) {
            this.rule = rule;
            this.extraInfo = extraInfo;
        }
    }

    /**
     * AI Validator response class
     */
    private class AIValidatorResponse {
        public String ruleToUse;
        public Integer count;
        public Boolean success;
        public Map<String, Object> extraInfo;
    }

    /**
     * Main validation method - validates request and returns selected rule with context
     */
    @InvocableMethod(
        label='Validate Mock Data Request'
        description='Validates user request and determines which rule to use for mock data generation'
    )
    public static List<ValidationResult> validate(List<Request> requests) {
        List<ValidationResult> results = new List<ValidationResult>();

        for (Request req : requests) {
            results.add(validateRequest(req));
        }

        return results;
    }

    /**
     * Validate the request inputs and load rule using AI
     */
    private static ValidationResult validateRequest(Request req) {
        // Step 1: Validate basic inputs
        if (String.isBlank(req.userInstructions)) {
            return new ValidationResult(false, 'Error: User Instructions is required');
        }

        // Step 2: Get parent object type from record ID (or use _standalone for null/blank)
        String parentObjectType;
        if (req.recordId == null || String.isBlank(String.valueOf(req.recordId))) {
            parentObjectType = '_standalone';
            System.debug('Standalone mode: no parent record provided');
        } else {
            parentObjectType = MockDataGeneratorUtils.getObjectType(req.recordId);
            System.debug('Parent Object Type: ' + parentObjectType);
        }

        // Step 3: Query all available rules once and build cache
        MockDataGeneratorUtils.RuleCache ruleCache = MockDataGeneratorUtils.loadAndCacheRules();
        System.debug('Available Rules JSON: ' + ruleCache.rulesJson);

        // Step 4: Use AI to determine data type and count from user instructions
        AIValidatorResponse validatorResponse = callAIValidator(
            ruleCache.rulesJson,
            parentObjectType,
            req.userInstructions
        );

        if (validatorResponse == null || validatorResponse.success == false) {
            return new ValidationResult(false,
                'Error: Unable to determine the data type and count from your instructions. ' +
                'Please provide clearer instructions specifying what type of data to generate.');
        }

        // Step 5: Use AI-determined values
        String ruleName = validatorResponse.ruleToUse;
        Integer count = validatorResponse.count;

        System.debug('AI Determined Rule: ' + ruleName);
        System.debug('AI Determined Count: ' + count);

        // Step 6: Get rule from cache
        Demo_Assist_Mock_Data_Generator_Rule__c rule = ruleCache.rulesByName.get(ruleName);

        if (rule == null) {
            return new ValidationResult(false,
                'Error: No rule found for "' + ruleName +
                '". Please ensure Demo_Assist_Mock_Data_Generator_Rule__c record exists.');
        }

        if (!rule.IsActive__c) {
            return new ValidationResult(false,
                'Error: Rule "' + ruleName +
                '" is currently disabled. Please activate it in Setup.');
        }

        // Step 7: Special validation for "rule" rule - validate the new rule's metadata structure
        if (ruleName == 'rule' && validatorResponse.extraInfo != null && !validatorResponse.extraInfo.isEmpty()) {
            ValidationResult metadataValidation = validateRuleMetadata(validatorResponse.extraInfo);
            if (metadataValidation != null) {
                // Validation failed, return the error
                return metadataValidation;
            }
            System.debug('Rule metadata validation passed for new rule: ' + validatorResponse.extraInfo);
        }

        // Step 8: Check if rule supports standalone only
        Boolean isStandaloneOnly = isRuleStandaloneOnly(rule);

        // If rule is standalone-only and recordId was provided, override to standalone mode
        if (isStandaloneOnly && parentObjectType != '_standalone') {
            System.debug('Rule ' + ruleName + ' is standalone-only, ignoring provided recordId and switching to standalone mode');
            parentObjectType = '_standalone';
            req.recordId = null;
        }

        // Step 9: Validate parent object is allowed
        if (!isParentObjectAllowed(rule, parentObjectType)) {
            String allowedParentsDisplay = getParentObjectDisplayString(rule);
            String errorMsg = 'Error: Cannot generate ' + rule.ObjectToGenerate__c + ' records ';
            if (parentObjectType == '_standalone') {
                errorMsg += 'without a parent record. This object type requires a parent record. ';
            } else {
                errorMsg += 'for ' + parentObjectType + ' records. ';
            }
            errorMsg += 'Allowed parent types: ' + allowedParentsDisplay + '. ';
            errorMsg += 'Please provide a valid parent record ID or navigate to a supported parent record page and try again.';

            return new ValidationResult(false, errorMsg);
        }

        // Validation successful - return rule, parent object type, count, and extraInfo
        Map<String, Object> extraInfo = validatorResponse.extraInfo != null ?
            validatorResponse.extraInfo : new Map<String, Object>();
        return new ValidationResult(rule, parentObjectType, count, extraInfo);
    }

    /**
     * Call AI validator to determine which rule to use and how many records from user instructions
     */
    private static AIValidatorResponse callAIValidator(
        String availableRulesJson,
        String parentObjectType,
        String userInstructions
    ) {
        try {
            List<String> p = new List<String>();
            p.add('# Task\n');
            p.add('You are an AI assistant that analyzes user instructions to determine which Salesforce mock data generation rule to use and how many records to generate.\n\n');

            p.add('## Context\n');
            p.add('- Parent Object Type: ' + parentObjectType + '\n');
            p.add('- User Instructions: """' + (String.isBlank(userInstructions) ? '' : userInstructions) + '"""\n\n');

            p.add('## Available Rules\n');
            p.add('Each rule has:\n');
            p.add('- Name: The canonical identifier to return (e.g., "contact", "email", "event")\n');
            p.add('- ObjectToGenerate: The Salesforce object API name (e.g., "Contact", "EmailMessage", "Event")\n');
            p.add('- Rule_Description: Describes in what situation this rule should be used\n');
            p.add('- DefaultCount: Default number of records if user doesn\'t specify a count\n\n');
            p.add(availableRulesJson);
            p.add('\n\n');

            p.add('## Your Task\n');
            p.add('1. Analyze the user instructions to determine:\n');
            p.add('   - Which rule best matches the user\'s intent (use Name, ObjectToGenerate, and Rule_Description)\n');
            p.add('   - How many records the user wants (extract from instructions or use DefaultCount)\n');
            p.add('2. Return ONLY a JSON object: {"success":true,"ruleToUse":"<rule_name>","count":<number>,"extraInfo":{...}}\n');
            p.add('3. If you cannot determine a valid match, return: {"success":false,"ruleToUse":"","count":0,"extraInfo":{}}\n\n');

            p.add('## Rules\n');
            p.add('- ruleToUse must be one of the availableRules[].Name values\n');
            p.add('- count must be > 0 (extract from user instructions or use DefaultCount)\n');
            p.add('- If count is mentioned in instructions, use that value\n');
            p.add('- User might mention the count in more subtle ways, such as "an account", "two contacts", "a couple of emails", etc. Make sure to extract the numeric count from the instructions\n');
            p.add('- If count is not mentioned in instructions, use the rule\'s DefaultCount\n');
            p.add('- Match based on keywords and context in instructions\n');
            p.add('- SPECIAL RULE: If the matched rule generates Demo_Assist_Mock_Data_Generator_Rule__c records (rule for extending tool capabilities), ALWAYS set count to 1, regardless of user input. Tool extensions must be done one at a time for safety.\n');
            p.add('- extraInfo handling:\n');
            p.add('  * For most rules: extraInfo should be an empty object {}\n');
            p.add('  * For "rule" rule ONLY (when ruleToUse="rule" and ObjectToGenerate="Demo_Assist_Mock_Data_Generator_Rule__c"):\n');
            p.add('    - Extract from user instructions what new object they want to add support for\n');
            p.add('    - Extract what parent objects should be allowed\n');
            p.add('    - Set extraInfo to: {"ObjectToGenerate":"<API_NAME>","AllowedParentObjects":"<PARENT_API_NAME>"}\n');
            p.add('    - Use Salesforce API names (e.g., "Account", "Contact", "CustomObject__c")\n');
            p.add('    - AllowedParentObjects can be comma-separated list if multiple parents mentioned\n');
            p.add('    - IMPORTANT: If user does NOT mention parent objects OR mentions standalone/no parent needed, use "_standalone"\n');
            p.add('    - If user mentions both specific parents AND standalone, include "_standalone" in the comma-separated list\n');
            p.add('    - Examples: "_standalone" OR "Account,Contact" OR "Account,_standalone"\n');
            p.add('- Return ONLY the JSON object, no markdown code blocks, no explanation\n\n');

            p.add('## Examples\n');
            p.add('User: "Generate 5 contacts for this account"\n');
            p.add('Output: {"success":true,"ruleToUse":"contact","count":5,"extraInfo":{}}\n\n');
            p.add('User: "Create some emails"\n');
            p.add('Output: {"success":true,"ruleToUse":"email","count":3,"extraInfo":{}}\n\n');
            p.add('User: "I need opportunities"\n');
            p.add('Output: {"success":true,"ruleToUse":"opportunity","count":3,"extraInfo":{}}\n\n');
            p.add('User: "Add support for Task object with Event as parent"\n');
            p.add('Output: {"success":true,"ruleToUse":"rule","count":1,"extraInfo":{"ObjectToGenerate":"Task","AllowedParentObjects":"Event"}}\n\n');
            p.add('User: "Generate rule for Order_Item__c that works with Account and Opportunity"\n');
            p.add('Output: {"success":true,"ruleToUse":"rule","count":1,"extraInfo":{"ObjectToGenerate":"Order_Item__c","AllowedParentObjects":"Account,Opportunity"}}\n\n');
            p.add('User: "Create rule for Custom Object MyObject__c"\n');
            p.add('Output: {"success":true,"ruleToUse":"rule","count":1,"extraInfo":{"ObjectToGenerate":"MyObject__c","AllowedParentObjects":"_standalone"}}\n\n');
            p.add('User: "Add support for Case object, it can be standalone or related to Account"\n');
            p.add('Output: {"success":true,"ruleToUse":"rule","count":1,"extraInfo":{"ObjectToGenerate":"Case","AllowedParentObjects":"_standalone,Account"}}\n');

            String prompt = String.join(p, '');
            String llmText = MockDataGeneratorUtils.generateWithLLM(prompt, null);
            String cleaned = MockDataGeneratorUtils.cleanJsonResponse(llmText);

            // Use deserializeUntyped to handle Map<String, Object> in extraInfo
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

            if (responseMap == null) {
                return failureResponse();
            }

            // Manually construct AIValidatorResponse from map
            AIValidatorResponse parsed = new AIValidatorResponse();
            parsed.success = (Boolean) responseMap.get('success');
            parsed.ruleToUse = (String) responseMap.get('ruleToUse');
            parsed.count = (Integer) responseMap.get('count');

            // Handle extraInfo as Map<String, Object>
            if (responseMap.containsKey('extraInfo') && responseMap.get('extraInfo') != null) {
                parsed.extraInfo = (Map<String, Object>) responseMap.get('extraInfo');
            } else {
                parsed.extraInfo = new Map<String, Object>();
            }

            System.debug('Parsed Response: success=' + parsed.success + ', ruleToUse=' + parsed.ruleToUse + ', count=' + parsed.count);

            if (parsed == null || parsed.success == null) {
                return failureResponse();
            }
            if (parsed.success == false) {
                return parsed;
            }
            if (String.isBlank(parsed.ruleToUse) || parsed.count == null || parsed.count <= 0) {
                return failureResponse();
            }

            return parsed;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AI validator (LLM) error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            return failureResponse();
        }
    }

    private static AIValidatorResponse failureResponse() {
        AIValidatorResponse r = new AIValidatorResponse();
        r.success = false;
        r.ruleToUse = '';
        r.count = 0;
        r.extraInfo = new Map<String, Object>();
        return r;
    }

    /**
     * Check if rule only supports standalone mode
     */
    private static Boolean isRuleStandaloneOnly(Demo_Assist_Mock_Data_Generator_Rule__c rule) {
        try {
            Map<String, Object> allowedParentsMap = (Map<String, Object>)
                JSON.deserializeUntyped(rule.AllowedParentObjects__c);
            return allowedParentsMap.size() == 1 && allowedParentsMap.containsKey('_standalone');
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Check if the parent object type is allowed for this rule
     */
    private static Boolean isParentObjectAllowed(Demo_Assist_Mock_Data_Generator_Rule__c rule, String parentObjectType) {
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

    /**
     * Get user-friendly display string for allowed parent objects
     */
    private static String getParentObjectDisplayString(Demo_Assist_Mock_Data_Generator_Rule__c rule) {
        try {
            Map<String, Object> allowedParentsMap = (Map<String, Object>)
                JSON.deserializeUntyped(rule.AllowedParentObjects__c);
            List<String> allowedTypes = new List<String>(allowedParentsMap.keySet());

            for (Integer i = 0; i < allowedTypes.size(); i++) {
                if (allowedTypes[i] == '_standalone') {
                    allowedTypes[i] = 'standalone (no parent record)';
                }
            }
            return String.join(allowedTypes, ', ');
        } catch (Exception e) {
            return rule.AllowedParentObjects__c;
        }
    }

    /**
     * Validate that the new rule's metadata structure exists in the org
     * This is called when user wants to create a new rule (ruleToUse='rule')
     */
    private static ValidationResult validateRuleMetadata(Map<String, Object> extraInfo) {
        // Extract ObjectToGenerate and AllowedParentObjects from extraInfo
        String objectToGenerate = (String) extraInfo.get('ObjectToGenerate');
        String allowedParentObjectsStr = (String) extraInfo.get('AllowedParentObjects');

        if (String.isBlank(objectToGenerate)) {
            return new ValidationResult(false,
                'Error: Cannot determine which object to generate. Please specify the object name in your instructions (e.g., "Add support for Task object").');
        }

        // Check if the object exists in the org
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Schema.SObjectType objectType = globalDescribe.get(objectToGenerate);

        if (objectType == null) {
            return new ValidationResult(false,
                'Error: Object "' + objectToGenerate + '" does not exist in this org. Please check the object API name and try again.');
        }

        // If no parent objects specified, validation passes (standalone object)
        if (String.isBlank(allowedParentObjectsStr)) {
            System.debug('Validation passed: Object "' + objectToGenerate + '" exists and no parent relationships required.');
            return null; // null means validation passed
        }

        // Parse the comma-separated list of allowed parent objects
        List<String> allowedParentObjects = allowedParentObjectsStr.split(',');
        Set<String> parentObjectsToFind = new Set<String>();
        for (String parentObj : allowedParentObjects) {
            if (!String.isBlank(parentObj)) {
                String trimmedParent = parentObj.trim();
                // Skip "_standalone" as it doesn't require relationship validation
                if (trimmedParent != '_standalone') {
                    parentObjectsToFind.add(trimmedParent);
                }
            }
        }

        // If only "_standalone" was specified, or all entries were "_standalone", validation passes
        if (parentObjectsToFind.isEmpty()) {
            System.debug('Validation passed: Object "' + objectToGenerate + '" exists and only _standalone or no parent relationships required.');
            return null; // null means validation passed
        }

        // Get all fields of the target object
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        Map<String, Schema.SObjectField> fieldsMap = objectDescribe.fields.getMap();

        // Find lookup/master-detail relationships
        Set<String> foundParentObjects = new Set<String>();
        for (Schema.SObjectField field : fieldsMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

            // Check if it's a lookup or master-detail field
            if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
                List<Schema.SObjectType> referenceTypes = fieldDescribe.getReferenceTo();
                for (Schema.SObjectType refType : referenceTypes) {
                    String refTypeName = refType.getDescribe().getName();
                    if (parentObjectsToFind.contains(refTypeName)) {
                        foundParentObjects.add(refTypeName);
                    }
                }
            }
        }

        // Check if all required parent objects have relationships
        Set<String> missingParentObjects = new Set<String>(parentObjectsToFind);
        missingParentObjects.removeAll(foundParentObjects);

        if (!missingParentObjects.isEmpty()) {
            List<String> missingList = new List<String>(missingParentObjects);
            String errorMsg = 'Error: Object "' + objectToGenerate + '" does not have lookup or master-detail relationships to the following parent objects: ' +
                String.join(missingList, ', ') + '. ';

            if (foundParentObjects.isEmpty()) {
                errorMsg += 'No relationships found to any specified parent objects.';
            } else {
                List<String> foundList = new List<String>(foundParentObjects);
                errorMsg += 'Found relationships only to: ' + String.join(foundList, ', ') + '.';
            }

            return new ValidationResult(false, errorMsg);
        }

        System.debug('Validation passed: Object "' + objectToGenerate + '" has all required relationships to: ' + String.join(new List<String>(foundParentObjects), ', '));
        return null; // null means validation passed
    }
}