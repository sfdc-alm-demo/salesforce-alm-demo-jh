import { LightningElement, api } from 'lwc';

export default class sdo_scom_B2bProductStockIndicator extends LightningElement {

    @api lowStockThreshold = 10;
    
    _stockCount; // Private variable

    /**
     * @description Public property with a setter to debug the received value.
     */
    @api
    get stockCount() {
        return this._stockCount;
    }
    set stockCount(value) {
        console.log('[B2B Stock Indicator] "stockCount" setter was called. Value received:', value);
        
        if (value !== undefined && value !== null) {
            this._stockCount = Number(value);
        } else {
            console.log('[B2B Stock Indicator] The received value is undefined or null.');
            this._stockCount = value;
        }
    }

    /**
     * @description Guard to check if data is ready for display.
     */
    get isReady() {
        return this._stockCount !== undefined && this._stockCount !== null;
    }

    get isAvailable() {
        return this._stockCount > this.lowStockThreshold;
    }

    get isLowStock() {
        return this._stockCount > 0 && this._stockCount <= this.lowStockThreshold;
    }
    
    get stockDetailsText() {
        if (!this.isReady) return ''; 

        if (this._stockCount === 1) {
            return `(1 unit in stock)`;
        }
        return `(${this._stockCount} units in stock)`;
    }
}