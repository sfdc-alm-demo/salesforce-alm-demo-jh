import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInsights from '@salesforce/apex/RevenueInsightsService.getInsights';
import calculateQuote from '@salesforce/apex/RevenueInsightsService.calculateQuote';
import getBasePrice from '@salesforce/apex/RevenueInsightsService.getBasePrice';

export default class RevenueInsights extends LightningElement {
    @api recordId; // Quote or Order ID from the record page
    
    isLoading = false;
    hasError = false;
    errorMessage = '';
    hasInsights = false;
    hasNoInsights = false;
    
    // Insight data
    riskScore = 0;
    recommendationText = '';
    similarDealId = '';
    similarDealName = '';
    similarDeals = [];
    dealSummary = '';
    signals = [];
    topProducts = [];
    topProductNames = {}; // Map of product ID -> product name
    lineCount = null;
    totalValue = null;
    
    // Pricing calculator data
    isCalculatingPricing = false;
    hasPricingData = false;
    basePricing = {}; // Map of product_code -> price
    riskAdjustedPricing = {}; // Map of product_code -> price
    baseTotal = 0;
    riskAdjustedTotal = 0;
    riskAdjustmentPercent = 0;
    calculationMetadata = null;
    pricingLineItems = []; // Array of {productCode, basePrice, adjustedPrice}
    
    connectedCallback() {
        // Auto-load insights when component is added to page
        if (this.recordId) {
            this.loadInsights();
        }
    }
    
    /**
     * Load insights from FastAPI via Apex
     */
    async loadInsights() {
        if (!this.recordId) {
            this.showError('No record ID available');
            return;
        }
        
        this.isLoading = true;
        this.hasError = false;
        this.hasInsights = false;
        this.hasNoInsights = false;
        
        try {
            const result = await getInsights({ transactionId: this.recordId });
            
            if (result && result.riskScore !== null) {
                this.riskScore = result.riskScore;
                this.recommendationText = result.recommendationText || '';
                this.similarDealId = result.similarDealId || '';
                this.similarDealName = result.similarDealName || '';
                this.dealSummary = result.dealSummary || '';
                this.topProducts = result.topProducts || [];
                this.topProductNames = result.topProductNames || {};
                
                // Process signals to replace product IDs with product names
                const rawSignals = result.signals || [];
                this.signals = rawSignals.map(signal => {
                    // Replace product IDs in signals with product names
                    let processedSignal = signal;
                    if (this.topProductNames && Object.keys(this.topProductNames).length > 0) {
                        for (const [productId, productName] of Object.entries(this.topProductNames)) {
                            // Replace product ID with product name in the signal text
                            processedSignal = processedSignal.replace(new RegExp(productId, 'g'), productName);
                        }
                    }
                    return processedSignal;
                });
                
                this.lineCount = result.lineCount;
                this.totalValue = result.totalValue;
                
                // Process similar deals
                if (result.similarDeals && result.similarDeals.length > 0) {
                    this.similarDeals = result.similarDeals.map(deal => ({
                        transactionId: deal.transactionId,
                        transactionName: deal.transactionName || deal.transactionId, // Use name if available, fallback to ID
                        similarityScore: this.formatDecimal(deal.similarityScore),
                        summary: deal.summary || '',
                        recordUrl: `/lightning/r/${deal.transactionId}/view`
                    }));
                }
                
                this.hasInsights = true;
            } else {
                this.hasNoInsights = true;
            }
        } catch (error) {
            console.error('Error loading insights:', error);
            this.showError('Failed to load insights: ' + (error.body?.message || error.message));
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Handle refresh button click
     */
    handleRefresh() {
        this.loadInsights();
    }
    
    /**
     * Calculate quote pricing with Ensura Pricing Engine
     */
    async calculateQuotePricing() {
        if (!this.recordId) {
            this.showError('No record ID available');
            return;
        }
        
        this.isCalculatingPricing = true;
        this.hasPricingData = false;
        
        try {
            const result = await calculateQuote({ quoteId: this.recordId });
            
            if (result) {
                // Update risk score if provided
                if (result.riskScore != null) {
                    this.riskScore = result.riskScore;
                }
                
                // Store pricing data
                this.basePricing = result.basePricing || {};
                this.riskAdjustedPricing = result.riskAdjustedPricing || {};
                this.riskAdjustedTotal = result.quoteTotal || 0;
                
                // Calculate base total
                this.baseTotal = 0;
                for (let price of Object.values(this.basePricing)) {
                    this.baseTotal += price || 0;
                }
                
                // Calculate risk adjustment percentage
                if (this.baseTotal > 0) {
                    this.riskAdjustmentPercent = ((this.riskAdjustedTotal - this.baseTotal) / this.baseTotal) * 100;
                }
                
                // Build line items array for display
                this.pricingLineItems = [];
                const allProductCodes = new Set([
                    ...Object.keys(this.basePricing),
                    ...Object.keys(this.riskAdjustedPricing)
                ]);
                
                for (let productCode of allProductCodes) {
                    this.pricingLineItems.push({
                        productCode: productCode,
                        basePrice: this.basePricing[productCode] || 0,
                        adjustedPrice: this.riskAdjustedPricing[productCode] || 0,
                        adjustment: (this.riskAdjustedPricing[productCode] || 0) - (this.basePricing[productCode] || 0)
                    });
                }
                
                // Store calculation metadata
                this.calculationMetadata = result.calculationMetadata;
                
                // Update recommendation if provided
                if (result.recommendationText) {
                    this.recommendationText = result.recommendationText;
                }
                
                this.hasPricingData = true;
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Pricing calculated successfully',
                        variant: 'success'
                    })
                );
            }
        } catch (error) {
            console.error('Error calculating quote pricing:', error);
            this.showError('Failed to calculate pricing: ' + (error.body?.message || error.message));
        } finally {
            this.isCalculatingPricing = false;
        }
    }
    
    /**
     * Get base price for a single product (for testing/debugging)
     */
    async getBasePriceForProduct(productCode, quantity) {
        try {
            const result = await getBasePrice({ 
                productCode: productCode, 
                quantity: quantity,
                region: 'NA',
                termMonths: 12
            });
            return result;
        } catch (error) {
            console.error('Error getting base price:', error);
            throw error;
        }
    }
    
    /**
     * Show error message
     */
    showError(message) {
        this.hasError = true;
        this.errorMessage = message;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }
    
    /**
     * Format decimal to 2 decimal places
     */
    formatDecimal(value) {
        if (value == null) return '0.00';
        return parseFloat(value).toFixed(2);
    }
    
    /**
     * Computed properties for risk score display
     */
    get riskScoreLabel() {
        return (this.riskScore * 100).toFixed(0) + '%';
    }
    
    get riskScorePercent() {
        return Math.round(this.riskScore * 100);
    }
    
    get riskScoreClass() {
        if (this.riskScore >= 0.7) return 'slds-badge_destructive';
        if (this.riskScore >= 0.4) return 'slds-badge_warning';
        return 'slds-badge_success';
    }
    
    get riskScoreVariant() {
        if (this.riskScore >= 0.7) return 'error';
        if (this.riskScore >= 0.4) return 'warning';
        return 'success';
    }
    
    get hasSimilarDeals() {
        return this.similarDeals && this.similarDeals.length > 0;
    }
    
    get hasSignals() {
        return this.signals && this.signals.length > 0;
    }
    
    get hasTopProducts() {
        return this.topProducts && this.topProducts.length > 0;
    }
    
    get totalValueLabel() {
        if (this.totalValue == null) return '';
        try {
            return '$' + Number(this.totalValue).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        } catch (e) {
            return '$' + this.totalValue;
        }
    }
    
    get similarDealUrl() {
        if (!this.similarDealId) return '#';
        return `/lightning/r/${this.similarDealId}/view`;
    }
    
    /**
     * Get display name for similar deal (name or ID)
     */
    get similarDealDisplayName() {
        return this.similarDealName || this.similarDealId;
    }
    
    /**
     * Get formatted top products with names
     */
    get formattedTopProducts() {
        if (!this.topProducts || this.topProducts.length === 0) {
            return [];
        }
        return this.topProducts.map(productId => {
            const productName = this.topProductNames[productId] || productId;
            return {
                id: productId,
                name: productName,
                display: productName !== productId ? productName : productId
            };
        });
    }
    
    /**
     * Computed properties for pricing display
     */
    get hasPricingLineItems() {
        return this.pricingLineItems && this.pricingLineItems.length > 0;
    }
    
    get baseTotalLabel() {
        return this.formatCurrency(this.baseTotal);
    }
    
    get riskAdjustedTotalLabel() {
        return this.formatCurrency(this.riskAdjustedTotal);
    }
    
    get riskAdjustmentLabel() {
        const sign = this.riskAdjustmentPercent >= 0 ? '+' : '';
        return sign + this.riskAdjustmentPercent.toFixed(1) + '%';
    }
    
    get riskAdjustmentClass() {
        return this.riskAdjustmentPercent >= 0 ? 'slds-text-color_error' : 'slds-text-color_success';
    }
    
    get calculationTimeLabel() {
        if (!this.calculationMetadata || !this.calculationMetadata.cpuTimeMs) {
            return '';
        }
        return `Calculation time: ${this.calculationMetadata.cpuTimeMs.toFixed(1)}ms`;
    }
    
    get simulationIterationsLabel() {
        if (!this.calculationMetadata || !this.calculationMetadata.simulationIterations) {
            return '';
        }
        return `Monte Carlo iterations: ${this.calculationMetadata.simulationIterations.toLocaleString()}`;
    }
    
    get ensuraPricingTimeLabel() {
        if (!this.calculationMetadata || !this.calculationMetadata.ensuraPricingTimeMs) {
            return '';
        }
        return `Ensura pricing time: ${this.calculationMetadata.ensuraPricingTimeMs.toFixed(1)}ms`;
    }
    
    /**
     * Format currency value (helper method for computed properties)
     */
    formatCurrency(value) {
        if (value == null || value === undefined) return '$0.00';
        try {
            return '$' + Number(value).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        } catch (e) {
            return '$' + Number(value).toFixed(2);
        }
    }
    
    /**
     * Format pricing line items with formatted currency values
     */
    get formattedPricingLineItems() {
        if (!this.pricingLineItems || this.pricingLineItems.length === 0) {
            return [];
        }
        return this.pricingLineItems.map(item => ({
            ...item,
            basePriceFormatted: this.formatCurrency(item.basePrice),
            adjustedPriceFormatted: this.formatCurrency(item.adjustedPrice),
            adjustmentFormatted: this.formatCurrency(item.adjustment),
            adjustmentClass: item.adjustment >= 0 ? 'slds-text-color_error' : 'slds-text-color_success',
            adjustmentSign: item.adjustment >= 0 ? '+' : ''
        }));
    }
    
    /**
     * Computed properties for button disabled states
     */
    get isRefreshDisabled() {
        return this.isLoading;
    }
    
    get isCalculatePricingDisabled() {
        return this.isCalculatingPricing || this.isLoading;
    }
}