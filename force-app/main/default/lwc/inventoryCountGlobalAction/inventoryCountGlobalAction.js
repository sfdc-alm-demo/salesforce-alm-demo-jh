import { LightningElement, track } from 'lwc';
import getInventoryCountsForDate from '@salesforce/apex/SDO_SFS_InventoryCountController.getInventoryCountsForDate';
import updateInventoryCounts from '@salesforce/apex/SDO_SFS_InventoryCountController.updateInventoryCounts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class InventoryCountGlobalAction extends LightningElement {
    @track inputDate;
    @track data;
    @track isLoading = false;
    @track showNoResults = false;
    modifiedCounts = {};

    // Debugging variables
    @track isDebug = false;
    @track debugJson = '';
    @track debugError = '';
    @track debugUpdate = '';

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    handleDateChange(event) {
        this.inputDate = event.target.value;
    }

    handleSearch() {
        if (!this.inputDate) {
            return;
        }

        this.isLoading = true;
        this.showNoResults = false;

        getInventoryCountsForDate({ inputDate: this.inputDate })
            .then(result => {
                this.data = result;
                this.isLoading = false;
                this.showNoResults = (result.length === 0);
                this.modifiedCounts = {} // Reset changes if any
                this.debugJson = JSON.stringify(result, null, 2);
            })
            .catch(error => {
                this.isLoading = false;
                this.data = undefined;
                this.showNoResults = false;
                this.debugJson = JSON.stringify(error, null, 2);
                // TODO: display error to user
            });
    }

    // handleQuantityChange(event) {
    //     const recordId = event.target.dataset.id;
    //     const newValue = event.target.value;

    //     // Find the record and update its quantity locally
    //     this.data = this.data.map(row =>
    //         row.recordId === recordId
    //             ? { ...row, quantity: Number(newValue) }
    //             : row
    //     );

    //     // Track modified counts for save
    //     this.modifiedCounts[recordId] = Number(newValue);
    // }

    handleQuantityChange(event) {
        const recordId = event.currentTarget.dataset.id;
        const newValue = event.detail.value;

        this.data = this.data.map(row =>
            row.recordId === recordId
                ? { ...row, quantity: Number(newValue) }
                : row
        );

        this.modifiedCounts[recordId] = Number(newValue);
    }
    // handleSave(event) {
    //     this.isLoading = true;

    //     // Prepare only modified records to send back
    //     // const updates = this.data.filter(
    //     //     row => this.modifiedCounts[row.recordId] !== undefined
    //     // );
    //     const updates = this.data
    //         .filter(row => this.modifiedCounts[row.Id] !== undefined)
    //         .map(row => ({
    //             Id: row.Id,
    //             quantity: this.modifiedCounts[row.Id]
    //         }));

    //     this.debugUpdate = JSON.stringify(updates, null, 2);

    //     updateInventoryCounts({ updatedCounts: updates })
    //         .then(() => {
    //             this.isLoading = false;
    //             this.modifiedCounts = {}
    //             this.showToast('Success', 'Inventory counts updated successfully.', 'success');

    //             // Refresh the grid
    //             // this.handleSearch();
    //         })
    //         .catch(error => {
    //             this.isLoading = false;
    //             // this.showToast('Error', 'There was a problem saving the changes.', 'error');
    //             this.showToast('Error', (error.body && error.body.message) ? error.body.message : 'There was a problem saving the changes.', 'error');
    //             this.debugError = JSON.stringify(error, null, 2);
    //         });
    // }

    handleSave() {
        this.isLoading = true;
        
        // map only the records the user actually changed
        const updates = Object.entries(this.modifiedCounts).map(
            ([recordId, quantity]) => ({ recordId, quantity })
        );
        
        this.debugUpdate = JSON.stringify(updates, null, 2);
        
        updateInventoryCounts({ updatedCounts: updates })
            .then(() => {
                this.isLoading = false;
                this.modifiedCounts = {};
                this.showToast('Success', 'Inventory counts updated successfully.', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                const msg = error.body?.message || 'There was a problem saving the changes.';
                this.showToast('Error', msg, 'error');
                this.debugError = JSON.stringify(error, null, 2);
            });
    }
}