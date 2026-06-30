import { LightningElement, api, track } from 'lwc';
import getSimilarCasesForCase from '@salesforce/apex/CaseRankerUiController.getSimilarCasesForCase';

export default class CaseRankerSimilarCases extends LightningElement {
    @api recordId;

    @track rows = [];
    @track errorMessage = '';
    @track isLoading = false;
    @track degraded = false;

    columns = [
        { label: 'Rank', fieldName: 'rank', type: 'number', initialWidth: 70 },
        {
            label: 'Similar Case',
            fieldName: 'url',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'caseId' },
                target: '_blank'
            }
        },
        {
            label: 'Score',
            fieldName: 'scorePct',
            type: 'percent',
            typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 0 },
            initialWidth: 100
        }
    ];

    get hasResults() {
        return this.rows && this.rows.length > 0;
    }

    get buttonLabel() {
        return this.isLoading ? 'Finding…' : 'Find Similar Cases';
    }

    async handleRun() {
        this.errorMessage = '';
        this.isLoading = true;
        this.degraded = false;
        this.rows = [];

        try {
            const res = await getSimilarCasesForCase({ caseId: this.recordId, returnLimit: 5 });
            this.degraded = !!res?.degraded;
            const results = res?.results || [];
            this.rows = results.map((r) => ({
                ...r,
                scorePct: (r.score || 0)
            }));
        } catch (e) {
            this.errorMessage = e?.body?.message || e?.message || 'Unknown error';
        } finally {
            this.isLoading = false;
        }
    }
}