import { LightningElement, api, wire } from 'lwc';
import getAccountBriefing from '@salesforce/apex/Data360Service.getAccountBriefing';

export default class AccountRevenueInsights extends LightningElement {
    @api recordId;
    briefing;
    error;

    @wire(getAccountBriefing, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.briefing = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || error.message || String(error);
            this.briefing = undefined;
        }
    }

    get hasData() {
        return this.briefing?.revenue;
    }

    get showEmpty() {
        return this.briefing && !this.briefing.revenue;
    }

    get formattedRevenue() {
        const n = this.briefing?.revenue?.totalRevenue;
        return n != null
            ? n.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 })
            : '—';
    }

    get formattedAvg() {
        const n = this.briefing?.revenue?.avgLineValue;
        return n != null
            ? n.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 })
            : '—';
    }

    get rfmBadgeClass() {
        const score = this.briefing?.engagement?.rfmScore;
        if (score == null) return 'slds-badge';
        if (score >= 70) return 'slds-badge slds-theme_success';
        if (score >= 40) return 'slds-badge slds-theme_warning';
        return 'slds-badge slds-theme_error';
    }

    get topFamilies() {
        const list = this.briefing?.topFamilies || [];
        return list.map((f) => ({
            ...f,
            displayFamily: f.family || '(unspecified)',
            displayRevenue: (f.revenue ?? 0).toLocaleString('en-US', {
                style: 'currency',
                currency: 'USD',
                maximumFractionDigits: 0
            })
        }));
    }

    get hasSegments() {
        return (this.briefing?.segmentMembership || []).length > 0;
    }

    get segmentList() {
        return (this.briefing?.segmentMembership || []).map((s) => ({
            name: s,
            label: s.replace(/_/g, ' ')
        }));
    }
}