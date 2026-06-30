/**
 * Invocable Apex class for Agentforce custom actions
 * 
 * Enables AI agents to query revenue insights via natural language:
 * - "Check deal risk for this quote"
 * - "What's the risk score for quote Q-12345?"
 * - "Find similar deals to this order"
 */
public with sharing class RevenueInsightsController {
    
    /**
     * Invocable method for Agentforce - Get revenue insights for one or more transactions
     * 
     * @param requests List of RevenueInsightRequest objects containing transaction IDs
     * @return List of RevenueInsightResponse objects with insights
     */
    @InvocableMethod(label='Get Revenue Insights' description='Get AI-generated revenue intelligence insights for quotes/orders')
    public static List<RevenueInsightResponse> getInsights(List<RevenueInsightRequest> requests) {
        List<RevenueInsightResponse> responses = new List<RevenueInsightResponse>();
        
        for (RevenueInsightRequest req : requests) {
            RevenueInsightResponse response = new RevenueInsightResponse();
            response.transactionId = req.transactionId;
            
            try {
                RevenueInsightsService.RevenueInsightResult result = RevenueInsightsService.getInsights(req.transactionId);
                
                if (result != null) {
                    response.riskScore = result.riskScore;
                    response.similarDealId = result.similarDealId;
                    response.recommendationText = result.recommendationText;
                    response.hasInsights = true;
                    
                    // Format similar deals for agent response
                    if (result.similarDeals != null && !result.similarDeals.isEmpty()) {
                        List<String> similarDealIds = new List<String>();
                        for (RevenueInsightsService.SimilarDealInfo deal : result.similarDeals) {
                            similarDealIds.add(deal.transactionId + ' (similarity: ' + deal.similarityScore.setScale(2) + ')');
                        }
                        response.similarDealsSummary = String.join(similarDealIds, ', ');
                    }
                } else {
                    response.hasInsights = false;
                    response.message = 'No insights found for transaction ' + req.transactionId + '. Transaction may be closed or not found.';
                }
            } catch (Exception e) {
                response.hasInsights = false;
                response.errorMessage = 'Error getting insights: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'RevenueInsightsController error: ' + e.getMessage());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    /**
     * Input wrapper for InvocableMethod
     */
    public class RevenueInsightRequest {
        @InvocableVariable(label='Transaction ID' description='Salesforce Quote or Order ID' required=true)
        public String transactionId;
    }
    
    /**
     * Output wrapper for InvocableMethod
     */
    public class RevenueInsightResponse {
        @InvocableVariable(label='Transaction ID')
        public String transactionId;
        
        @InvocableVariable(label='Has Insights')
        public Boolean hasInsights;
        
        @InvocableVariable(label='Risk Score')
        public Decimal riskScore;
        
        @InvocableVariable(label='Similar Deal ID')
        public String similarDealId;
        
        @InvocableVariable(label='Recommendation Text')
        public String recommendationText;
        
        @InvocableVariable(label='Similar Deals Summary')
        public String similarDealsSummary;
        
        @InvocableVariable(label='Message')
        public String message;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}