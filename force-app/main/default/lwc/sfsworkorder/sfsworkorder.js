import { LightningElement, wire, api, track } from 'lwc';
import getProducts from '@salesforce/apex/WorkOrderController.getProductsForWorkType';

export default class Sfsworkorder extends LightningElement {
@api workTypeId;  // Receives Work Type ID from Flow
    @track productData = [];

    columns = [
        { label: 'Product Name', fieldName: 'productName', type: 'text' },
        { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency' },
        { label: 'Quantity Required', fieldName: 'quantityRequired', type: 'number' },
        { label: 'Total Price', fieldName: 'totalPrice', type: 'currency' } // New column for total price
    ];

    @wire(getProducts, { workTypeId: '$workTypeId' })
    wiredProducts({ error, data }) {
        console.log('Received Work Type ID:', this.workTypeId);  
        if (data) {
            console.log('Fetched Products:', JSON.stringify(data)); 
            this.productData = data.map(item => ({
                id: item.id,
                productName: item.productName,
                unitPrice: item.unitPrice,
                quantityRequired: item.quantityRequired,
                totalPrice: item.unitPrice * item.quantityRequired  // Calculate total price
            }));
        } else if (error) {
            console.error('Error fetching product data:', error);
            this.productData = [];
        }
    }
}