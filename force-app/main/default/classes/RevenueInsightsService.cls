/**
 * Service class for calling Revenue Intelligence Engine FastAPI via App Link Named Credential
 * 
 * This class handles HTTP calls to the Heroku FastAPI service using App Link authentication.
 * The App Link Service Mesh handles all authentication - no manual JWT validation needed.
 */
public with sharing class RevenueInsightsService {
    
    // Named Credential endpoint name (configured in Setup → Named Credentials)
    private static final String NAMED_CREDENTIAL = 'Revenue_Intelligence_Engine';
    
    /**
     * Get revenue insights for a transaction (Quote/Order ID)
     * Calls FastAPI endpoint: POST /transactions/{transaction_id}/insights
     * 
     * @param transactionId Salesforce Quote/Order ID
     * @return RevenueInsightResult with risk score, recommendation, and similar deals
     */
    @AuraEnabled(cacheable=false)
    public static RevenueInsightResult getInsights(String transactionId) {
        if (String.isBlank(transactionId)) {
            throw new IllegalArgumentException('Transaction ID is required');
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/transactions/' + transactionId + '/insights');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000); // 30 second timeout
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return parseInsightResponse(responseMap);
        } else if (res.getStatusCode() == 404) {
            // Transaction not found or closed - return null
            return null;
        } else {
            // Log error and throw exception
            System.debug(LoggingLevel.ERROR, 'Revenue Insights API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            throw new CalloutException('Failed to get revenue insights: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
    
    /**
     * Parse FastAPI response into RevenueInsightResult
     */
    private static RevenueInsightResult parseInsightResponse(Map<String, Object> responseMap) {
        RevenueInsightResult result = new RevenueInsightResult();
        result.transactionId = (String) responseMap.get('transaction_id');
        result.riskScore = (Decimal) responseMap.get('risk_score');
        result.similarDealId = (String) responseMap.get('similar_deal_id');
        result.recommendationText = (String) responseMap.get('recommendation_text');
        result.dealSummary = (String) responseMap.get('deal_summary');
        result.lineCount = (Integer) responseMap.get('line_count');
        result.totalValue = (Decimal) responseMap.get('total_value');
        
        // Parse signals array
        if (responseMap.containsKey('signals')) {
            List<Object> signalsList = (List<Object>) responseMap.get('signals');
            result.signals = new List<String>();
            for (Object s : signalsList) {
                result.signals.add(String.valueOf(s));
            }
        }
        
        // Parse top products array
        if (responseMap.containsKey('top_products')) {
            List<Object> topProductsList = (List<Object>) responseMap.get('top_products');
            result.topProducts = new List<String>();
            for (Object p : topProductsList) {
                result.topProducts.add(String.valueOf(p));
            }
        }
        
        // Parse similar deals array
        if (responseMap.containsKey('similar_deals')) {
            List<Object> similarDealsList = (List<Object>) responseMap.get('similar_deals');
            result.similarDeals = new List<SimilarDealInfo>();
            
            for (Object dealObj : similarDealsList) {
                Map<String, Object> dealMap = (Map<String, Object>) dealObj;
                SimilarDealInfo dealInfo = new SimilarDealInfo();
                dealInfo.transactionId = (String) dealMap.get('transaction_id');
                dealInfo.similarityScore = (Decimal) dealMap.get('similarity_score');
                dealInfo.summary = (String) dealMap.get('summary');
                
                // Fetch Order Name or Quote Name for display
                dealInfo.transactionName = getTransactionName(dealInfo.transactionId);
                
                result.similarDeals.add(dealInfo);
            }
        }
        
        // Fetch Order Name for the most similar deal
        if (String.isNotBlank(result.similarDealId)) {
            result.similarDealName = getTransactionName(result.similarDealId);
        }
        
        // Fetch Product Names for top products
        if (result.topProducts != null && !result.topProducts.isEmpty()) {
            result.topProductNames = getProductNames(result.topProducts);
        }
        
        return result;
    }
    
    /**
     * Helper method to get transaction name (Order Number or Quote Name)
     */
    private static String getTransactionName(String transactionId) {
        if (String.isBlank(transactionId)) {
            return null;
        }
        
        String idPrefix = transactionId.length() >= 3 ? transactionId.substring(0, 3) : '';
        
        try {
            if (idPrefix == '801') {
                // Order
                List<Order> orders = [
                    SELECT OrderNumber 
                    FROM Order 
                    WHERE Id = :transactionId 
                    LIMIT 1
                ];
                if (!orders.isEmpty()) {
                    return orders[0].OrderNumber;
                }
            } else if (idPrefix == '0Q0') {
                // Standard Quote
                List<Quote> quotes = [
                    SELECT Name 
                    FROM Quote 
                    WHERE Id = :transactionId 
                    LIMIT 1
                ];
                if (!quotes.isEmpty()) {
                    return quotes[0].Name;
                }
            } else {
                // Try SBQQ Quote
                try {
                    List<SObject> sbqqQuotes = Database.query(
                        'SELECT Name FROM SBQQ__Quote__c WHERE Id = :transactionId LIMIT 1'
                    );
                    if (!sbqqQuotes.isEmpty()) {
                        return (String) sbqqQuotes[0].get('Name');
                    }
                } catch (Exception e) {
                    // SBQQ not available
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.DEBUG, 'Error fetching transaction name: ' + e.getMessage());
        }
        
        return null; // Fallback to ID if name not found
    }
    
    /**
     * Helper method to get product names from product IDs
     */
    private static Map<String, String> getProductNames(List<String> productIds) {
        Map<String, String> productNameMap = new Map<String, String>();
        
        if (productIds == null || productIds.isEmpty()) {
            return productNameMap;
        }
        
        try {
            // Query products by ID
            List<Product2> products = [
                SELECT Id, Name 
                FROM Product2 
                WHERE Id IN :productIds
            ];
            
            for (Product2 p : products) {
                productNameMap.put(p.Id, p.Name);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.DEBUG, 'Error fetching product names: ' + e.getMessage());
        }
        
        return productNameMap;
    }
    
    /**
     * Wrapper class for insight results
     */
    public class RevenueInsightResult {
        @AuraEnabled public String transactionId;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public String similarDealId;
        @AuraEnabled public String similarDealName;
        @AuraEnabled public String recommendationText;
        @AuraEnabled public List<SimilarDealInfo> similarDeals;
        @AuraEnabled public String dealSummary;
        @AuraEnabled public Integer lineCount;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public List<String> signals;
        @AuraEnabled public List<String> topProducts;
        @AuraEnabled public Map<String, String> topProductNames;
    }
    
    /**
     * Wrapper class for similar deal information
     */
    public class SimilarDealInfo {
        @AuraEnabled public String transactionId;
        @AuraEnabled public String transactionName;
        @AuraEnabled public Decimal similarityScore;
        @AuraEnabled public String summary;
    }
    
    /**
     * Get Quote data including line items for pricing calculation
     * Supports both standard Quote and Revenue Cloud SBQQ__Quote__c objects
     * 
     * @param quoteId Salesforce Quote ID
     * @return QuoteDataResult with quote info and line items
     */
    @AuraEnabled(cacheable=false)
    public static QuoteDataResult getQuoteData(String quoteId) {
        if (String.isBlank(quoteId)) {
            throw new IllegalArgumentException('Quote ID is required');
        }
        
        QuoteDataResult result = new QuoteDataResult();
        
        // Determine object type by ID prefix: 0Q0 = Quote, 801 = Order, 0Q0 = SBQQ__Quote__c
        String idPrefix = quoteId.length() >= 3 ? quoteId.substring(0, 3) : '';
        
        // Try Order first if ID starts with 801
        if (idPrefix == '801') {
            try {
                List<Order> orders = [
                    SELECT Id, OrderNumber, AccountId, Account.Name, Status, Account.Type
                    FROM Order 
                    WHERE Id = :quoteId 
                    LIMIT 1
                ];
                
                if (!orders.isEmpty()) {
                    Order o = orders[0];
                    result.quoteId = o.Id;
                    result.accountId = o.AccountId;
                    result.status = o.Status;
                    
                    // Get Order Products
                    List<OrderItem> lineItems = [
                        SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, 
                               Quantity, UnitPrice, Discount
                        FROM OrderItem 
                        WHERE OrderId = :quoteId
                    ];
                    
                    result.lineItems = new List<QuoteLineItemData>();
                    for (OrderItem li : lineItems) {
                        QuoteLineItemData item = new QuoteLineItemData();
                        item.productCode = li.Product2?.ProductCode;
                        item.productName = li.Product2?.Name; // Store product name
                        item.quantity = li.Quantity;
                        item.unitPrice = li.UnitPrice;
                        item.discount = li.Discount;
                        if (String.isNotBlank(item.productCode) && item.quantity != null) {
                            result.lineItems.add(item);
                        }
                    }
                    return result;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error querying Order: ' + e.getMessage());
            }
        }
        
        // Try standard Quote first, then SBQQ__Quote__c for Revenue Cloud
        try {
            // Query Quote with Account info (using dynamic SOQL to handle optional custom fields)
            String quoteQuery = 'SELECT Id, AccountId, Account.Name, Status, Account.Type FROM Quote WHERE Id = :quoteId LIMIT 1';
            List<Quote> quotes = Database.query(quoteQuery);
            
            if (quotes.isEmpty()) {
                // Try Revenue Cloud Quote object (SBQQ__Quote__c)
                try {
                    // Use dynamic SOQL to avoid compile errors if custom fields don't exist
                    String sbqqQuery = 'SELECT Id, AccountId__c, AccountId__r.Name, Status__c, AccountId__r.Type FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1';
                    List<SObject> sbqqQuotes = Database.query(sbqqQuery);
                    
                    if (sbqqQuotes.isEmpty()) {
                        // Try Order as last resort
                        List<Order> orders = [
                            SELECT Id, OrderNumber, AccountId, Status
                            FROM Order 
                            WHERE Id = :quoteId 
                            LIMIT 1
                        ];
                        if (orders.isEmpty()) {
                            throw new IllegalArgumentException('Quote or Order not found: ' + quoteId);
                        }
                        
                        // Handle Order
                        Order o = orders[0];
                        result.quoteId = o.Id;
                        result.accountId = o.AccountId;
                        result.status = o.Status;
                        
                        // Get Order Products
                        List<OrderItem> lineItems = [
                            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, 
                                   Quantity, UnitPrice, Discount
                            FROM OrderItem 
                            WHERE OrderId = :quoteId
                        ];
                        
                        result.lineItems = new List<QuoteLineItemData>();
                        for (OrderItem li : lineItems) {
                            QuoteLineItemData item = new QuoteLineItemData();
                            item.productCode = li.Product2?.ProductCode;
                            item.productName = li.Product2?.Name;
                            item.quantity = li.Quantity;
                            item.unitPrice = li.UnitPrice;
                            item.discount = li.Discount;
                            if (String.isNotBlank(item.productCode) && item.quantity != null) {
                                result.lineItems.add(item);
                            }
                        }
                        return result;
                    }
                    
                    SObject q = sbqqQuotes[0];
                    result.quoteId = (String) q.get('Id');
                    result.accountId = (String) q.get('AccountId__c');
                    result.status = (String) q.get('Status__c');
                    
                    // Try to get custom fields if they exist
                    try {
                        Map<String, Schema.SObjectField> fieldMap = q.getSObjectType().getDescribe().fields.getMap();
                        if (fieldMap.containsKey('Payment_Terms__c')) {
                            result.paymentTerms = (String) q.get('Payment_Terms__c');
                        }
                        SObject accountObj = q.getSObject('AccountId__r');
                        if (accountObj != null) {
                            Map<String, Schema.SObjectField> accFieldMap = accountObj.getSObjectType().getDescribe().fields.getMap();
                            if (accFieldMap.containsKey('Customer_Tier__c')) {
                                result.customerTier = (String) accountObj.get('Customer_Tier__c');
                            }
                        }
                    } catch (Exception e) {
                        // Custom fields don't exist, continue without them
                        System.debug(LoggingLevel.DEBUG, 'Custom fields not available: ' + e.getMessage());
                    }
                    
                    // Get SBQQ Quote Line Items
                    List<SObject> lineItems = Database.query(
                        'SELECT Id, Product2Id__c, Product2Id__r.ProductCode, Product2Id__r.Name, ' +
                        'Quantity__c, UnitPrice__c, Discount__c ' +
                        'FROM SBQQ__QuoteLine__c ' +
                        'WHERE SBQQ__Quote__c = :quoteId'
                    );
                    
                    result.lineItems = new List<QuoteLineItemData>();
                    for (SObject li : lineItems) {
                        QuoteLineItemData item = new QuoteLineItemData();
                        SObject product = li.getSObject('Product2Id__r');
                        item.productCode = (String) product?.get('ProductCode');
                        item.productName = (String) product?.get('Name'); // Store product name
                        item.quantity = (Decimal) li.get('Quantity__c');
                        item.unitPrice = (Decimal) li.get('UnitPrice__c');
                        item.discount = (Decimal) li.get('Discount__c');
                        if (String.isNotBlank(item.productCode) && item.quantity != null) {
                            result.lineItems.add(item);
                        }
                    }
                } catch (QueryException qe) {
                    // SBQQ objects don't exist in this org, re-throw original error
                    throw new IllegalArgumentException('Quote not found: ' + quoteId);
                }
            } else {
                Quote q = quotes[0];
                result.quoteId = q.Id;
                result.accountId = q.AccountId;
                result.status = q.Status;
                
                // Custom fields are optional - if they don't exist, they'll be null
                // Payment_Terms__c and Customer_Tier__c may not exist in all orgs
                // The API will work without them
                
                // Get Quote Line Items
                List<QuoteLineItem> lineItems = [
                    SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, 
                           Quantity, UnitPrice, Discount
                    FROM QuoteLineItem 
                    WHERE QuoteId = :quoteId
                ];
                
                result.lineItems = new List<QuoteLineItemData>();
                for (QuoteLineItem li : lineItems) {
                    QuoteLineItemData item = new QuoteLineItemData();
                    item.productCode = li.Product2?.ProductCode;
                    item.productName = li.Product2?.Name; // Store product name
                    item.quantity = li.Quantity;
                    item.unitPrice = li.UnitPrice;
                    item.discount = li.Discount;
                    if (String.isNotBlank(item.productCode) && item.quantity != null) {
                        result.lineItems.add(item);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting quote data: ' + e.getMessage());
            throw new CalloutException('Failed to get quote data: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Calculate quote with risk scoring and Ensura pricing
     * Calls FastAPI endpoint: POST /quotes/calculate
     * 
     * @param quoteId Salesforce Quote ID
     * @return QuoteCalculationResult with pricing breakdown and risk score
     */
    @AuraEnabled(cacheable=false)
    public static QuoteCalculationResult calculateQuote(String quoteId) {
        if (String.isBlank(quoteId)) {
            throw new IllegalArgumentException('Quote ID is required');
        }
        
        // Get quote data first
        QuoteDataResult quoteData = getQuoteData(quoteId);
        
        // Build request payload
        Map<String, Object> requestPayload = new Map<String, Object>();
        requestPayload.put('transaction_id', quoteData.quoteId);
        requestPayload.put('account_id', quoteData.accountId);
        
        if (String.isNotBlank(quoteData.customerTier)) {
            requestPayload.put('customer_tier', quoteData.customerTier);
        }
        if (String.isNotBlank(quoteData.paymentTerms)) {
            requestPayload.put('payment_terms', quoteData.paymentTerms);
        }
        
        // Build line_items array
        List<Map<String, Object>> lineItemsList = new List<Map<String, Object>>();
        for (QuoteLineItemData item : quoteData.lineItems) {
            Map<String, Object> lineItem = new Map<String, Object>();
            lineItem.put('product_code', item.productCode);
            lineItem.put('quantity', item.quantity);
            
            // Build attributes object
            Map<String, Object> attributes = new Map<String, Object>();
            if (item.discount != null) {
                attributes.put('discount_pct', item.discount);
            }
            if (item.unitPrice != null) {
                attributes.put('unit_price', item.unitPrice);
            }
            if (!attributes.isEmpty()) {
                lineItem.put('attributes', attributes);
            }
            
            lineItemsList.add(lineItem);
        }
        requestPayload.put('line_items', lineItemsList);
        
        // Call API
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/quotes/calculate');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestPayload));
        req.setTimeout(30000); // 30 second timeout
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return parseQuoteCalculationResponse(responseMap);
        } else {
            System.debug(LoggingLevel.ERROR, 'Quote Calculation API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            throw new CalloutException('Failed to calculate quote: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
    
    /**
     * Get base price from Ensura Pricing Engine
     * Calls FastAPI endpoint: POST /pricing/base-price
     * 
     * @param productCode Product code identifier
     * @param quantity Quantity of the product
     * @param region Optional region (NA, EMEA, APAC)
     * @param termMonths Optional contract term in months
     * @return BasePriceResult with pricing information
     */
    @AuraEnabled(cacheable=false)
    public static BasePriceResult getBasePrice(String productCode, Decimal quantity, String region, Integer termMonths) {
        if (String.isBlank(productCode) || quantity == null) {
            throw new IllegalArgumentException('Product code and quantity are required');
        }
        
        // Build request payload
        Map<String, Object> requestPayload = new Map<String, Object>();
        requestPayload.put('product_code', productCode);
        requestPayload.put('quantity', quantity);
        
        if (String.isNotBlank(region)) {
            requestPayload.put('region', region);
        }
        if (termMonths != null) {
            requestPayload.put('term_months', termMonths);
        }
        
        // Call API
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/pricing/base-price');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestPayload));
        req.setTimeout(30000); // 30 second timeout
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return parseBasePriceResponse(responseMap);
        } else {
            System.debug(LoggingLevel.ERROR, 'Base Price API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            throw new CalloutException('Failed to get base price: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
    
    /**
     * Parse quote calculation response
     */
    private static QuoteCalculationResult parseQuoteCalculationResponse(Map<String, Object> responseMap) {
        QuoteCalculationResult result = new QuoteCalculationResult();
        result.transactionId = (String) responseMap.get('transaction_id');
        result.accountId = (String) responseMap.get('account_id');
        result.riskScore = (Decimal) responseMap.get('risk_score');
        result.quoteTotal = (Decimal) responseMap.get('quote_total');
        result.recommendationText = (String) responseMap.get('recommendation_text');
        
        // Parse base_pricing object
        if (responseMap.containsKey('base_pricing')) {
            Map<String, Object> basePricingMap = (Map<String, Object>) responseMap.get('base_pricing');
            result.basePricing = new Map<String, Decimal>();
            for (String key : basePricingMap.keySet()) {
                result.basePricing.put(key, (Decimal) basePricingMap.get(key));
            }
        }
        
        // Parse risk_adjusted_pricing object
        if (responseMap.containsKey('risk_adjusted_pricing')) {
            Map<String, Object> adjustedPricingMap = (Map<String, Object>) responseMap.get('risk_adjusted_pricing');
            result.riskAdjustedPricing = new Map<String, Decimal>();
            for (String key : adjustedPricingMap.keySet()) {
                result.riskAdjustedPricing.put(key, (Decimal) adjustedPricingMap.get(key));
            }
        }
        
        // Parse calculation_metadata
        if (responseMap.containsKey('calculation_metadata')) {
            Map<String, Object> metadataMap = (Map<String, Object>) responseMap.get('calculation_metadata');
            result.calculationMetadata = new CalculationMetadata();
            result.calculationMetadata.cpuTimeMs = (Decimal) metadataMap.get('cpu_time_ms');
            result.calculationMetadata.simulationIterations = (Integer) metadataMap.get('simulation_iterations');
            result.calculationMetadata.ensuraPricingTimeMs = (Decimal) metadataMap.get('ensura_pricing_time_ms');
        }
        
        return result;
    }
    
    /**
     * Parse base price response
     */
    private static BasePriceResult parseBasePriceResponse(Map<String, Object> responseMap) {
        BasePriceResult result = new BasePriceResult();
        result.productCode = (String) responseMap.get('product_code');
        result.basePrice = (Decimal) responseMap.get('base_price');
        result.unitPrice = (Decimal) responseMap.get('unit_price');
        result.totalPrice = (Decimal) responseMap.get('total_price');
        
        // Parse pricing_rules_applied array
        if (responseMap.containsKey('pricing_rules_applied')) {
            List<Object> rulesList = (List<Object>) responseMap.get('pricing_rules_applied');
            result.pricingRulesApplied = new List<String>();
            for (Object rule : rulesList) {
                result.pricingRulesApplied.add(String.valueOf(rule));
            }
        }
        
        return result;
    }
    
    /**
     * Wrapper class for quote data
     */
    public class QuoteDataResult {
        @AuraEnabled public String quoteId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String status;
        @AuraEnabled public String customerTier;
        @AuraEnabled public String paymentTerms;
        @AuraEnabled public List<QuoteLineItemData> lineItems;
    }
    
    /**
     * Wrapper class for quote line item data
     */
    public class QuoteLineItemData {
        @AuraEnabled public String productCode;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal discount;
    }
    
    /**
     * Wrapper class for quote calculation results
     */
    public class QuoteCalculationResult {
        @AuraEnabled public String transactionId;
        @AuraEnabled public String accountId;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public Map<String, Decimal> basePricing;
        @AuraEnabled public Map<String, Decimal> riskAdjustedPricing;
        @AuraEnabled public Decimal quoteTotal;
        @AuraEnabled public String recommendationText;
        @AuraEnabled public CalculationMetadata calculationMetadata;
    }
    
    /**
     * Wrapper class for base price results
     */
    public class BasePriceResult {
        @AuraEnabled public String productCode;
        @AuraEnabled public Decimal basePrice;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public List<String> pricingRulesApplied;
    }
    
    /**
     * Wrapper class for calculation metadata
     */
    public class CalculationMetadata {
        @AuraEnabled public Decimal cpuTimeMs;
        @AuraEnabled public Integer simulationIterations;
        @AuraEnabled public Decimal ensuraPricingTimeMs;
    }
}