import { LightningElement, api } from 'lwc';

export default class sdo_scom_productStockIndicator extends LightningElement {
  @api stock; // receives {!Product.Inventory.details.availableToOrder}

  get indicatorClass() {
    const stockValue = Number(this.stock);

    if (stockValue === 0) {
      return 'stock-indicator red';
    } else if (stockValue < 10) {
      return 'stock-indicator orange';
    } else {
      return 'stock-indicator green';
    }
  }
}