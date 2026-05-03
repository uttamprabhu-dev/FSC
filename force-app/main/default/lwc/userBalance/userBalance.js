import { LightningElement, track, api } from 'lwc';

export default class UserBalance extends LightningElement {
    _value = {};

    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val ? { ...val } : {};
    }
    @track chosenLoanOption = null;
    @track step1 = true;
    @track step2 = false;
    @track transactions = [];
    @track hoveredIndex = null;
    @track updatedTenureLoanDetails = null;

    @track loanChangeFormData = {

    }

    connectedCallback() {
        console.log('Connected Callback called with value: ' + this.chosenLoanOption);
        this.processtransactions();
        this.fetchSomeMethod();
    }

    async fetchSomeMethod() {
        try {
            const result = await callSomeMethod();
            if (result.success) {
                console.log('Result from callSomeMethod:', JSON.stringify(result));
            }
        } catch (error) {
            console.error('Error calling test method:', error);
        }
    }

    processtransactions() {
        console.log('Processing loan options with value:', JSON.stringify(this._value));

        if (!this._value) {
            console.warn('Value is undefined or null');
            return;
        }

        let loansList = [];

        // Handle LoanRestructureResponse with dataContainer wrapper
        if (this._value?.balanceResponse) {
            loansList = this._value.balanceResponse;
        }

        // Process the loans list
        this.transactions = loansList.map((loan, index) => ({
            id: index,
            finAccBalanceId: loan?.finAccBalanceId || '',
            name: loan?.name || '',
            amount: loan?.amount || 0,
            type: loan?.type || 0,
            isSelected: "loan-tile"
        }));
        console.log('Processed loan options:', this.transactions);
    }

    handleTileHover(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.hoveredIndex = index;
    }

    handleTileHoverOut(event) {
        this.hoveredIndex = null;
    }
}