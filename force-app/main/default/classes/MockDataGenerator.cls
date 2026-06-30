/**
 * Main generator class for creating mock data using AI/LLM
 *
 * Responsibilities:
 * - Accept validated rule and user instructions from InputValidator
 * - Query parent record data for context (if not standalone)
 * - Build comprehensive AI prompt with examples and context
 * - Call LLM to generate mock data JSON
 * - Return generated JSON for user preview (does NOT insert records)
 *
 * Architecture:
 * InputValidator → MockDataGenerator → RecordManager
 *
 * Security Note:
 * This class uses 'without sharing' to allow the AI/LLM to access parent record
 * data needed for context, regardless of the running user's sharing access.
 * This is intentional as the generated data is only returned for preview and
 * not automatically inserted. The actual record insertion is handled by
 * RecordManager which uses 'with sharing' for proper security enforcement.
 *
 * Design Principles Applied:
 * - Single Responsibility: Focuses solely on data generation
 * - Dependency Inversion: Depends on abstraction (rule configuration)
 * - Separation of Concerns: Generation logic separate from validation and persistence
 */

/**
 * TO DO:
 * - Add UI support, to allow users to generate mock data from the UI
 * - Add UI support, to allow users to extend rules from the UI
 */
 public without sharing class MockDataGenerator {

    private static final String DEFAULT_LLM_MODEL = 'sfdc_ai__DefaultVertexAIGemini25Flash001';

    /**
     * Request class for generation
     */
    public class Request {
        @InvocableVariable(
            label='Rule JSON'
            description='Serialized Demo_Assist_Mock_Data_Generator_Rule__c record from validation step'
            required=true
        )
        public String ruleJson;

        @InvocableVariable(
            label='Parent Object Type'
            description='API name of the parent object type (e.g., Account, Contact) or "_standalone" for standalone generation. Optional - will be derived from parentRecordId if not provided.'
            required=false
        )
        public String parentObjectType;

        @InvocableVariable(
            label='Record Count'
            description='Number of mock data records to generate'
            required=true
        )
        public Integer recordCount;

        @InvocableVariable(
            label='User Instructions'
            description='Natural language instructions describing what data to generate (include industry context, specifics, language preferences, etc.)'
            required=true
        )
        public String userInstructions;

        @InvocableVariable(
            label='Parent Record ID'
            description='The ID of the parent record to which generated data will be related (optional for standalone generation)'
            required=false
        )
        public String parentRecordId;
    }

    /**
     * Response class for generation
     */
    public class Response {
        @InvocableVariable(
            label='Success'
            description='Whether the data generation completed successfully'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='Success or error message with details about the generation operation'
        )
        public String message;

        @InvocableVariable(
            label='Generated Records JSON'
            description='JSON array containing the generated mock data records for preview (not yet inserted into Salesforce)'
        )
        public String generatedRecordsJson;

        @InvocableVariable(
            label='Parent Record Details JSON'
            description='JSON object containing details of the parent record used for context (empty string for standalone generation)'
        )
        public String parentRecordDetailsJson;
    }

    /**
     * Main invocable method for generating mock data
     */
    @InvocableMethod(
        label='Generate Mock Data'
        description='Generates mock data JSON using AI based on validated rule and user instructions'
    )
    public static List<Response> generate(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.success = false;

            try {
                // Deserialize rule with extraInfo wrapper
                Map<String, Object> ruleWrapper = (Map<String, Object>) JSON.deserializeUntyped(req.ruleJson);
                Map<String, Object> extraInfo = new Map<String, Object>();

                Demo_Assist_Mock_Data_Generator_Rule__c rule;
                if (ruleWrapper.containsKey('rule')) {
                    // New format with RuleWithExtraInfo wrapper
                    rule = (Demo_Assist_Mock_Data_Generator_Rule__c) JSON.deserialize(
                        JSON.serialize(ruleWrapper.get('rule')),
                        Demo_Assist_Mock_Data_Generator_Rule__c.class
                    );
                    if (ruleWrapper.containsKey('extraInfo') && ruleWrapper.get('extraInfo') != null) {
                        extraInfo = (Map<String, Object>) ruleWrapper.get('extraInfo');
                    }
                } else {
                    // Legacy format - direct rule object
                    rule = (Demo_Assist_Mock_Data_Generator_Rule__c) JSON.deserialize(
                        req.ruleJson,
                        Demo_Assist_Mock_Data_Generator_Rule__c.class
                    );
                }

                System.debug('Generating mock data for rule: ' + rule.Name);

                // Determine parent object type if not provided
                if (String.isBlank(req.parentObjectType)) {
                    if (MockDataGeneratorUtils.isValidParentRecordId(req.parentRecordId)) {
                        // Derive from parentRecordId
                        req.parentObjectType = MockDataGeneratorUtils.getObjectType(req.parentRecordId);
                        System.debug('Derived Parent Object Type from recordId: ' + req.parentObjectType);
                    } else {
                        // Default to standalone if no parent record provided
                        req.parentObjectType = '_standalone';
                        System.debug('No parent record provided, defaulting to standalone mode');
                    }
                }

                System.debug('Parent Object Type: ' + req.parentObjectType);
                System.debug('Record Count: ' + req.recordCount);

                // Fetch parent record data if not standalone
                Map<String, Object> parentRecordData = new Map<String, Object>();
                if (req.parentObjectType != '_standalone' &&
                    MockDataGeneratorUtils.isValidParentRecordId(req.parentRecordId)) {

                    parentRecordData = MockDataGeneratorUtils.getParentRecordData(
                        req.parentRecordId,
                        req.parentObjectType
                    );
                    System.debug('Parent Record Data: ' + JSON.serialize(parentRecordData));
                }

                // Generate prompt with context
                String prompt = generatePrompt(
                    rule,
                    req.recordCount,
                    req.userInstructions,
                    req.parentObjectType,
                    req.parentRecordId,
                    parentRecordData,
                    extraInfo
                );

                System.debug('Generated Prompt Length: ' + prompt.length());

                // Call LLM to generate data
                String llmResponse = MockDataGeneratorUtils.generateWithLLM(prompt, DEFAULT_LLM_MODEL);
                System.debug('LLM Response Length: ' + llmResponse.length());

                // Clean JSON response
                String cleanedJson = MockDataGeneratorUtils.cleanJsonResponse(llmResponse);
                System.debug('Cleaned JSON Length: ' + cleanedJson.length());

                // Validate JSON is an array
                List<Object> recordsList = (List<Object>)JSON.deserializeUntyped(cleanedJson);
                if (recordsList == null || recordsList.isEmpty()) {
                    throw new MockDataGeneratorUtils.MockDataGeneratorException(
                        'LLM returned empty or invalid JSON array'
                    );
                }

                System.debug('Successfully generated ' + recordsList.size() + ' records');

                // Post-processing: If generating rules, force AllowedParentObjects to be standalone only
                if (rule.ObjectToGenerate__c == 'Demo_Assist_Mock_Data_Generator_Rule__c') {
                    for (Object recordObj : recordsList) {
                        Map<String, Object> recordMap = (Map<String, Object>) recordObj;
                        // Overwrite AllowedParentObjects to ensure rules are standalone only
                        recordMap.put('AllowedParentObjects__c', '{"_standalone":""}');
                    }
                    cleanedJson = JSON.serialize(recordsList);
                    System.debug('Post-processed rule records: forced AllowedParentObjects to standalone only');
                }

                // Build success response
                res.success = true;
                res.generatedRecordsJson = cleanedJson;
                res.parentRecordDetailsJson = JSON.serialize(parentRecordData);
                res.message = 'Successfully generated ' + recordsList.size() + ' record(s). Please review and confirm.';

                new XDO_Tool_TrackingEventReporting.Conversion()
                    .setMinutesSaved(10 * recordsList.size())
                    .setAction('Generate Mock Data - ' + rule.ObjectToGenerate__c)
                    .setAssetIdentifier('Demo Assist | Mock Data Generator')
                    .setSource('Brix-6-xDO-MockDataGenerator')
                    .publish();


            } catch (Exception e) {
                res.success = false;
                res.message = 'Error generating mock data: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Generator Error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            }

            results.add(res);
        }

        return results;
    }

    /**
     * Generate comprehensive AI prompt with context
     */
    private static String generatePrompt(
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        Integer recordCount,
        String userInstructions,
        String parentObjectType,
        String parentRecordId,
        Map<String, Object> parentRecordData,
        Map<String, Object> extraInfo
    ) {
        List<String> p = new List<String>();

        // Header
        p.add('# Task: Generate Mock Data for Salesforce Demo\n\n');

        // Special preprocessing for rule generation
        Boolean isRuleGeneration = (rule.ObjectToGenerate__c == 'Demo_Assist_Mock_Data_Generator_Rule__c');
        String targetObjectApiName = null;
        String targetAllowedParents = null;
        Map<String, String> relationshipFieldsMap = new Map<String, String>();
        List<MockDataGeneratorUtils.ObjectFieldInfo> targetObjectFields = new List<MockDataGeneratorUtils.ObjectFieldInfo>();

        if (isRuleGeneration && extraInfo != null && !extraInfo.isEmpty()) {
            targetObjectApiName = (String) extraInfo.get('ObjectToGenerate');
            targetAllowedParents = (String) extraInfo.get('AllowedParentObjects');

            System.debug('Rule generation detected for object: ' + targetObjectApiName);
            System.debug('Allowed parents: ' + targetAllowedParents);

            if (String.isNotBlank(targetObjectApiName)) {
                // Get fields for example structure (text, date/time, numeric, boolean)
                targetObjectFields = MockDataGeneratorUtils.getFieldsForObject(targetObjectApiName);
                System.debug('Found ' + targetObjectFields.size() + ' fields for ' + targetObjectApiName);

                // Get relationship fields
                if (String.isNotBlank(targetAllowedParents)) {
                    relationshipFieldsMap = MockDataGeneratorUtils.getRelationshipFields(targetObjectApiName, targetAllowedParents);
                    System.debug('Found ' + relationshipFieldsMap.size() + ' relationship fields');
                }
            }
        }

        // Context
        p.add('## Context & Purpose\n');
        p.add('You are creating compelling demo data for a Salesforce product demonstration. ');
        p.add('This data will be used by Salesforce solution engineers to demo Salesforce capabilities to prospective customers. ');
        p.add('The demo data should showcase how THE CUSTOMER COMPANY (e.g., Sony, Acme Corp) uses Salesforce ');
        p.add('to sell their products/services to THEIR customers (other businesses or consumers).\n\n');
        p.add('**IMPORTANT**: Generated data should represent the customer company\'s business operations, NOT Salesforce selling to the customer company.\n');
        p.add('- Example: If generating emails for Sony, show Sony sales reps communicating with Sony\'s customers about Sony products.\n');
        p.add('- Example: If generating accounts for a healthcare company, show the healthcare company\'s patient/client accounts.\n');
        p.add('- Example: If generating opportunities, show the customer company\'s sales deals with their end customers.\n\n');
        p.add('**Key Objective**: Generate realistic, business-value-focused data that demonstrates how the customer company ');
        p.add('can use Salesforce to drive their own sales growth, improve their customer relationships, and boost their team productivity.\n\n');
        p.add('**Technical Specifications**:\n');
        p.add('- Object Type: ' + rule.ObjectToGenerate__c + '\n');
        p.add('- Number of Records: ' + recordCount + '\n');
        p.add('- Current Date: ' + System.today() + '\n');
        p.add(parentRecordId != null && String.isNotBlank(String.valueOf(parentRecordId)) ? '- Parent Object Type: ' + parentObjectType + '\n' : '- Generation Mode: Standalone (no parent record)\n');
        p.add('\n');

        // Add special context for rule generation
        if (isRuleGeneration && String.isNotBlank(targetObjectApiName)) {
            p.add('## IMPORTANT: Rule Generation Context\n');
            p.add('You are generating a rule configuration for the object: ' + targetObjectApiName + '\n');
            p.add('This is a meta-task: you are creating configuration data that will enable future data generation for this object.\n\n');

            p.add('### Rule Naming Convention\n');
            p.add('The "Name" field must follow these rules:\n');
            p.add('- If ObjectToGenerate is a STANDARD object (does NOT end with __c):\n');
            p.add('  * Convert to lowercase, human-friendly identifier\n');
            p.add('  * Examples: "Asset" → "asset", "EmailMessage" → "email", "Task" → "task"\n');
            p.add('- If ObjectToGenerate is a CUSTOM object (ends with __c):\n');
            p.add('  * Use the exact API name as-is\n');
            p.add('  * Examples: "Order_Item__c" → "Order_Item__c", "Custom_Asset__c" → "Custom_Asset__c"\n');
            p.add('IMPORTANT: The Name field is NOT just "rule" - it must represent the target object.\n\n');

            // Add target object field information
            if (!targetObjectFields.isEmpty()) {
                p.add('### Target Object Field Structure (' + targetObjectApiName + ')\n');
                p.add('The following fields are available on ' + targetObjectApiName + ' (text, date/time, numeric, boolean):\n');
                for (MockDataGeneratorUtils.ObjectFieldInfo fieldInfo : targetObjectFields) {
                    p.add('- ' + fieldInfo.fieldName + ' (' + fieldInfo.fieldLabel + ') - Type: ' + fieldInfo.fieldType + '\n');
                }
                p.add('\n');

                // Create example JSON structure
                p.add('### Example JSON Structure for ' + targetObjectApiName + '\n');
                p.add('When generating the ExampleJsonData__c field, use this structure as a guide:\n');
                p.add('```json\n{\n');
                Integer fieldCount = 0;
                Integer maxFields = 5; // Limit to first 5 fields for example
                for (MockDataGeneratorUtils.ObjectFieldInfo fieldInfo : targetObjectFields) {
                    if (fieldCount >= maxFields) break;
                    // Provide type-appropriate example values
                    String exampleValue = 'example value';
                    if (fieldInfo.fieldType.contains('DATE') || fieldInfo.fieldType.contains('TIME')) {
                        exampleValue = '2024-01-15';
                    } else if (fieldInfo.fieldType.contains('INTEGER') || fieldInfo.fieldType.contains('DOUBLE') ||
                               fieldInfo.fieldType.contains('CURRENCY') || fieldInfo.fieldType.contains('PERCENT')) {
                        exampleValue = '100';
                    } else if (fieldInfo.fieldType.contains('BOOLEAN')) {
                        exampleValue = 'true';
                    }
                    p.add('  "' + fieldInfo.fieldName + '": "' + exampleValue + '"');
                    if (fieldCount < Math.min(targetObjectFields.size(), maxFields) - 1) {
                        p.add(',');
                    }
                    p.add('\n');
                    fieldCount++;
                }
                p.add('}\n```\n\n');
            }

            // Add relationship field information
            if (!relationshipFieldsMap.isEmpty()) {
                p.add('### Parent Object Relationship Fields\n');
                p.add('The following relationship fields connect ' + targetObjectApiName + ' to parent objects:\n');
                for (String parentObj : relationshipFieldsMap.keySet()) {
                    String fieldApiName = relationshipFieldsMap.get(parentObj);
                    p.add('- Parent: ' + parentObj + ' → Field API Name: ' + fieldApiName + '\n');
                }
                p.add('\n');

                // Build AllowedParentObjects JSON structure
                p.add('### AllowedParentObjects__c Field Format\n');
                p.add('For the AllowedParentObjects__c field, use this JSON structure:\n');
                p.add('```json\n{\n');
                Integer parentCount = 0;
                for (String parentObj : relationshipFieldsMap.keySet()) {
                    String fieldApiName = relationshipFieldsMap.get(parentObj);
                    p.add('  "' + parentObj + '": "' + fieldApiName + '"');
                    if (parentCount < relationshipFieldsMap.size() - 1) {
                        p.add(',');
                    }
                    p.add('\n');
                    parentCount++;
                }
                // Add _standalone if mentioned in allowed parents
                if (String.isNotBlank(targetAllowedParents) && targetAllowedParents.contains('_standalone')) {
                    if (!relationshipFieldsMap.isEmpty()) {
                        p.add(',\n');
                    }
                    p.add('  "_standalone": ""\n');
                } else {
                    p.add('\n');
                }
                p.add('}\n```\n\n');
            } else if (String.isNotBlank(targetAllowedParents) && targetAllowedParents == '_standalone') {
                // Standalone only
                p.add('### AllowedParentObjects__c Field Format\n');
                p.add('This object is standalone only. Use this JSON structure:\n');
                p.add('```json\n{\n  "_standalone": ""\n}\n```\n\n');
            }

            p.add('IMPORTANT: Use the field structure and relationship information above to populate the rule configuration accurately.\n\n');
        }

        // User instructions
        p.add('## User Requirements (HIGHEST PRIORITY)\n');
        p.add(userInstructions + '\n\n');

        p.add('### CRITICAL: User Requirements Take Absolute Priority\n');
        p.add('The user requirements above are the HIGHEST PRIORITY and must be followed exactly.\n\n');
        p.add('**If user provides specific context, use it**:\n');
        p.add('- If user says "generate emails inviting to our onsite launch party next week" → Generate emails about the launch party invitation, NOT generic business emails\n');
        p.add('- If user says "schedule an event to watch the movie Avengers 42" → Generate an event about watching that movie, NOT a generic business meeting\n');
        p.add('- If user says "create contacts from a trade show in Germany" → Generate contacts related to that trade show context\n');
        p.add('- If user provides ANY specific scenario, story, or context → Follow it exactly\n\n');
        p.add('**Balance general guidelines with user specifics**:\n');
        p.add('- Our general guideline suggests business-focused data (sales, customer relationships, etc.)\n');
        p.add('- BUT if the user provides specific non-business context (social events, entertainment, personal scenarios), honor that\n');
        p.add('- User requirements ALWAYS override general guidelines\n');
        p.add('- The goal is to generate data that matches exactly what the user requested\n\n');

        // Language/locale considerations - CRITICAL for multilingual support
        p.add('## CRITICAL: Language and Locale Detection\n');
        p.add('You MUST determine the correct language and locale for generated data using this priority:\n\n');

        p.add('### PRIORITY 1 - Explicit Language Request (Highest Priority):\n');
        p.add('- If user instructions explicitly mention a language/locale (e.g., "in Spanish", "generate French names", "use Japanese")\n');
        p.add('- Generate ALL data in that specified language\n');
        p.add('- Example: "Create contacts in Spanish" → Generate Spanish names, descriptions, etc.\n\n');

        p.add('### PRIORITY 2 - Detect Primary Language from User Instructions:\n');
        p.add('- If no explicit language mentioned, detect the language of the user instructions themselves\n');
        p.add('- Analyze the user instructions to determine the PRIMARY language used:\n');
        p.add('  * If the sentence is mostly Chinese with a few English words, the primary language is Chinese\n');
        p.add('  * If the sentence is mostly Spanish with a few English words, the primary language is Spanish\n');
        p.add('  * The primary language is the one that dominates the user\'s instructions\n');
        p.add('- Example: User writes "创建5个联系人" (Chinese) → Generate Chinese names and data\n');
        p.add('- Example: User writes "Crear 5 contactos" (Spanish) → Generate Spanish names and data\n\n');

        p.add('### PRIORITY 3 - Parent Record Context:\n');
        p.add('- Check parent record fields for locale indicators:\n');
        p.add('  * BillingCountry, BillingState, BillingCity in Account records\n');
        p.add('  * Address fields indicating geographic region\n');
        p.add('- Generate culturally appropriate data for that region\n');
        p.add('- Example: BillingCountry = "Japan" → Generate Japanese names and business context\n\n');

        p.add('### PRIORITY 4 - Default to English:\n');
        p.add('- If none of the above apply, use English as default\n');
        p.add('- Use diverse international names even in English\n\n');

        p.add('### Cultural & Geographic Authenticity (Applies to ALL Priorities):\n');
        p.add('Once you determine the language/locale from ANY of the priorities above, apply these rules:\n\n');
        p.add('1. **Generate ALL Data in Detected Language**:\n');
        p.add('   - Names must match the cultural style of the language\n');
        p.add('   - Addresses must match the geographic style of the language\n');
        p.add('   - Job titles, descriptions, and all text fields must be in the language\n\n');

        p.add('2. **Language-Specific Examples**:\n');
        p.add('   - Chinese: Use Chinese names (姓名), Chinese addresses (中国地址), Chinese company names, Chinese job titles\n');
        p.add('   - Spanish: Use Spanish names, Spanish-speaking country addresses, Spanish company names, Spanish job titles\n');
        p.add('   - French: Use French names, French addresses, French company names, French job titles\n');
        p.add('   - Japanese: Use Japanese names, Japanese addresses, Japanese company names, Japanese job titles\n');
        p.add('   - And so on for all languages\n\n');

        p.add('3. **Apply Consistently Across All Fields**:\n');
        p.add('   - Names (first names, last names appropriate for the culture)\n');
        p.add('   - Company names and business terminology\n');
        p.add('   - Email addresses (use culturally appropriate domains)\n');
        p.add('   - Phone number formats for the region\n');
        p.add('   - Address formats and conventions\n');
        p.add('   - Job titles and business roles\n');
        p.add('   - Any text fields like descriptions or notes\n\n');

        p.add('4. **Do NOT Mix Languages**:\n');
        p.add('   - Unless explicitly requested, do NOT mix languages in generated data\n');
        p.add('   - If language is Chinese, ALL data should be in Chinese (not Chinese + English mix)\n');
        p.add('   - If language is Spanish, ALL data should be in Spanish (not Spanish + English mix)\n');
        p.add('   - Consistency is critical for authentic demo data\n\n');

        // Object description
        if (String.isNotBlank(rule.ObjectDescription__c)) {
            p.add('## Object Description\n');
            p.add(rule.ObjectDescription__c + '\n\n');
        }

        // Parent context
        if (parentObjectType != '_standalone' && !parentRecordData.isEmpty()) {
            p.add('## Parent Record Context\n');
            p.add('Parent Object Type: ' + parentObjectType + '\n');
            p.add('Parent Record Details:\n');
            p.add(JSON.serializePretty(parentRecordData) + '\n\n');
            p.add('IMPORTANT: Use the parent record context to generate realistic, contextually relevant data.\n');
            p.add('For example, if the parent is a technology company, generate data appropriate for that industry.\n\n');
        }

        // Example JSON structure
        if (String.isNotBlank(rule.ExampleJsonData__c)) {
            p.add('## Example Record Structure\n');
            p.add('```json\n');
            p.add(rule.ExampleJsonData__c + '\n');
            p.add('```\n\n');
        }

        // Output requirements
        p.add('## Output Requirements\n');
        p.add('1. Return ONLY a valid JSON array of ' + recordCount + ' object(s)\n');
        p.add('2. Each object must be a valid JSON object with appropriate field names\n');
        p.add('3. Field names must match Salesforce API names (e.g., "firstName", "lastName", "email")\n');
        p.add('4. Do NOT include:\n');
        p.add('   - Markdown code fences (```json or ```)\n');
        p.add('   - Explanatory text before or after the JSON\n');
        p.add('   - Comments within the JSON\n');
        p.add('   - System fields like Id, CreatedDate, LastModifiedDate\n');

        // Parent relationship field handling
        if (parentObjectType != '_standalone') {
            String parentFieldName = MockDataGeneratorUtils.getParentFieldName(rule, parentObjectType);
            if (String.isNotBlank(parentFieldName)) {
                p.add('   - DO NOT include the parent relationship field "' + parentFieldName + '" (it will be set automatically)\n');
            }
        }

        p.add('5. Data quality requirements:\n');
        p.add('   - Generate realistic, diverse data appropriate for demos\n');
        p.add('   - Use proper data types (strings, numbers, booleans, dates)\n');
        p.add('   - Dates in ISO 8601 format: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.SSSZ\n');
        p.add('   - Email addresses must be valid format\n');
        p.add('   - Phone numbers should be realistic (but can be fake)\n');
        p.add('   - Names should be diverse and realistic\n');

        // Merge field support
        p.add('6. Merge field support:\n');
        p.add('   - You can use merge fields like {!$User.Email} for current user email\n');
        p.add('   - You can use {!$Parent.FieldName} to reference parent record fields\n');
        p.add('   - These will be resolved at runtime\n\n');

        // Quality guidelines with business focus
        p.add('## Quality Guidelines for Demo Data\n\n');
        p.add('### Business Value Requirements:\n');
        p.add('1. **Sales-Oriented**: Generate data that shows clear business value, deal progression, and revenue opportunities\n');
        p.add('2. **Customer Success Stories**: Include positive outcomes, success metrics, and concrete business results\n');
        p.add('3. **Engagement Indicators**: Show active relationships, regular touchpoints, and meaningful interactions\n');
        p.add('4. **Industry Relevance**: Use industry-specific terminology, realistic scenarios, and relatable business challenges\n');
        p.add('5. **Measurable Impact**: Include specific numbers, percentages, dollar amounts, and quantifiable results where appropriate\n\n');

        p.add('### Demo Best Practices:\n');
        p.add('- Make data impressive but believable (realistic numbers, not exaggerated)\n');
        p.add('- Show progress and momentum (recent dates, active status, upcoming activities)\n');
        p.add('- Demonstrate ROI potential (cost savings, revenue growth, efficiency gains)\n');
        p.add('- Include specific details that make scenarios memorable and relatable\n');
        p.add('- Create data that tells a coherent, compelling business narrative\n');
        p.add('- Vary the content - avoid repetitive patterns, use diverse scenarios\n\n');

        p.add('### Date Generation Guidelines:\n');
        p.add('- Use the Current Date (' + System.today() + ') as your reference point\n');
        p.add('- For historical data: Generate dates within the past 3-12 months to show recent activity\n');
        p.add('- For future data: Generate dates within the next 1-6 months to show upcoming opportunities\n');
        p.add('- Show progression: Earlier dates for initial contact, more recent dates for follow-ups\n');
        p.add('- Make dates realistic: business days, appropriate intervals between activities\n\n');

        // Example output format
        p.add('## Example Output Format\n');
        p.add('[\n');
        p.add('  {\n');
        p.add('    "fieldName1": "value1",\n');
        p.add('    "fieldName2": "value2",\n');
        p.add('    "fieldName3": 123\n');
        p.add('  },\n');
        p.add('  {\n');
        p.add('    "fieldName1": "value1",\n');
        p.add('    "fieldName2": "value2",\n');
        p.add('    "fieldName3": 456\n');
        p.add('  }\n');
        p.add(']\n\n');

        p.add('Now generate the ' + recordCount + ' ' + rule.ObjectToGenerate__c + ' record(s):\n');

        String fullPrompt = String.join(p, '');

        // Resolve merge fields
        fullPrompt = MockDataGeneratorUtils.resolveMergeFields(
            fullPrompt,
            parentRecordId,
            parentObjectType,
            parentRecordData
        );

        return fullPrompt;
    }


    /**
     * Debug method for testing generation without invocable context
     */
    public static Response debugGenerate(
        Demo_Assist_Mock_Data_Generator_Rule__c rule,
        String parentObjectType,
        Integer recordCount,
        String userInstructions,
        String parentRecordId
    ) {
        Request req = new Request();
        req.ruleJson = JSON.serialize(rule);
        req.parentObjectType = parentObjectType;
        req.recordCount = recordCount;
        req.userInstructions = userInstructions;
        req.parentRecordId = parentRecordId;

        List<Response> responses = generate(new List<Request>{ req });
        return responses[0];
    }

}