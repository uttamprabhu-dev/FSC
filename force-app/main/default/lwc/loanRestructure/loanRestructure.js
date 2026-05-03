import { LightningElement, api, track } from 'lwc';
import sendLoanChangeNotification from '@salesforce/apex/LoanRestructureController.sendLoanChangeNotification';
import callSomeMethod from '@salesforce/apex/LoanRestructureController.callSomeMethod';

export default class LoanRestructure extends LightningElement {
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
    @track loanOptions = [];
    @track hoveredIndex = null;
    @track updatedTenureLoanDetails = null;
    @track loandChangeResult = null;

    @track loanChangeFormData = {

    }

    connectedCallback() {
        console.log('Connected Callback called with value: ' + this.chosenLoanOption);
        this.processLoanOptions();
        this.fetchSomeMethod();
    }

    async fetchSomeMethod() {
        try {
            const result = await callSomeMethod();
            if(result.success) {
                console.log('Result from callSomeMethod:', JSON.stringify(result));
            }
        } catch (error) {
            console.error('Error calling test method:', error);
        }
    }

    processLoanOptions() {
        console.log('Processing loan options with value:', JSON.stringify(this._value));
        
        if (!this._value) {
            console.warn('Value is undefined or null');
            return;
        }

        let loansList = [];

        // Handle LoanRestructureResponse with dataContainer wrapper
        if (this._value?.loanResponse) {
            loansList = this._value.loanResponse;
        }

        // Process the loans list
        this.loanOptions = loansList.map((loan, index) => ({
            id: index,
            loanCollPlanId: loan?.loanCollPlanId || null,
            loanAccount: loan?.loanAccount || '',
            totalLoanAmount: loan?.totalLoanAmount || 0,
            loanTerm: loan?.loanTerm || 0,
            currentDueAmount: loan?.currentDueAmount || 0,
            interestRate: loan?.interestRate || 0,
            interestAmount: loan?.interestAmount || 0,
            isSelected: "loan-tile"
        }));
        console.log('Processed loan options:', this.loanOptions);
    }

    handleSelectLoan(event) {
        const tileElement = event.currentTarget;
        const index = parseInt(tileElement.dataset.index, 10);
        this.chosenLoanOption = {
            ...this.loanOptions[index]
        };
        this.loanOptions = this.loanOptions.map((option, idx) => ({
            ...option,
            isSelected: idx === index ? "loan-tile loan-selected" : "loan-tile"
        }));
        console.log('Selected loan option:', JSON.stringify(this.chosenLoanOption), JSON.stringify(this.loanOptions[index]), index);
        console.log('Chosen loan option after selection:', (!this.chosenLoanOption));
    }

    handleTileHover(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.hoveredIndex = index;
    }

    handleTileHoverOut(event) {
        this.hoveredIndex = null;
    }

    handleNext() {
        this.step1 = false;
        this.step2 = true;
    }

    handleBack() {
        this.step1 = true;
        this.step2 = false;
    }

    handleTenureChange(event) {
        const termYears = event.target.value;
        if(termYears === "1" || termYears === "2" ) {
            const newTenure = parseInt(event.target.value, 10);
            this.updatedTenureLoanDetails = this.getLoanDetails(newTenure);
        } else if(termYears === "3-month") {
            const currentTenure = this.chosenLoanOption.loanTerm;
            this.updatedTenureLoanDetails = this.getLoanDetails(currentTenure, 3);
        }
        console.log('is tenure updated: ', termYears)
        console.log('is tenure updated: ', this.updatedTenureLoanDetails)
    }

    getLoanDetails(termYears, moratoriumMonths = 0) {
        const OUTSTANDING = this.chosenLoanOption.currentDueAmount;
        const ANNUAL_RATE = this.chosenLoanOption.interestRate;
        const OLD_TERM = this.chosenLoanOption.loanTerm;
        const r = ANNUAL_RATE / 100 / 12; // Monthly interest rate
        const n = termYears * 12;         // Repayment period in months
        
        // 1. Calculate "Interest during Moratorium"
        // If interest is capitalized, the principal increases:
        const principalAfterMoratorium = OUTSTANDING * Math.pow(1 + r, moratoriumMonths);
        
        // 2. Calculate EMI based on the NEW principal and the ORIGINAL repayment term
        const emi = principalAfterMoratorium * r * Math.pow(1 + r, n) / (Math.pow(1 + r, n) - 1);
        
        const totalPayable = emi * n;
        const totalInterest = totalPayable - OUTSTANDING;
        const newTenures = moratoriumMonths === 0 ? termYears + OLD_TERM : OLD_TERM;
        const tenure = `${newTenures} years repayment` + (moratoriumMonths > 0 ? ` + ${moratoriumMonths} months grace` : '');

        return {
            monthlyEmi:       Math.round(emi),
            totalInterest:    Math.round(totalInterest),
            totalPayable:     Math.round(totalPayable),
            tenure:           tenure,
            newTenureYears:   newTenures,
            tenureChoice: moratoriumMonths === 0 ? `${termYears}-year` : '3-month moratorium'
        };
    }

    async handleLoanRestructure() {
        try {
            if (!this.updatedTenureLoanDetails) {
                console.error('Please select a tenure before confirming');
                return;
            }

            const loanCollPlanId = this.chosenLoanOption.loanCollPlanId;
            const details = this.updatedTenureLoanDetails;
            const input = {
                loanCollPlanId:  loanCollPlanId,
                monthlyEmi:      details.monthlyEmi,
                totalPayable:    details.totalPayable,
                totalInterest:   details.totalInterest,
                newTenureYears:  details.newTenureYears,
                tenureChoice:    details.tenureChoice
            };
            console.log('Input for loan change notification:', JSON.stringify(input));
            // const result = await sendLoanChangeNotification({ loanDetails: input });\
            this.loandChangeResult = 'Your loan restructure request has been sent successfully. The relationship manager will contact you soon.';
            this.step1 = false;
            this.step2 = false;
        } catch (error) {
            console.error('Error during loan restructure:', error);
            this.loandChangeResult = 'An error occurred while processing your request. Please try again.';
            this.step1 = false;
            this.step2 = false;
        }
    }
}