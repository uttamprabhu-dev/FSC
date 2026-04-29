global class LoanRestructureController {
    private static final String ORG_WIDE_EMAIL = OTPHelper.ORG_WIDE_EMAIL;

    global class PhoneNumberWrapper {
        @InvocableVariable(label='Phone Number' description='The phone number to be validated' required=true)
        public String phoneNumber;
    }

    global class LoanRestructureResponse {
        @InvocableVariable(label='Action Result' description='The result of the loan restructure action' required=true)
        public LoansWrapper dataContainer;
    }

    global class LoansWrapper {
        @InvocableVariable(label='Loan Options' description='List of loan options available for restructuring' required=true)
        public List<LoanOptionsItemWrapper> loanResponse;
        @InvocableVariable(label='Total Count' description='Total count of active loans found' required=true)
        public Integer totalCount;
        @InvocableVariable(label='Summary Message' description='Summary message for the loan options' required=true)
        public String summaryMessage;

        public LoansWrapper(List<LoanOptionsItemWrapper> loanResponse, Integer totalCount, String summaryMessage) {
            this.loanResponse = loanResponse;
            this.totalCount = totalCount;
            this.summaryMessage = summaryMessage;
        }
    }

    global class LoanOptionsItemWrapper {
        public Id loanCollPlanId;

        public String loanAccount;

        public Decimal totalLoanAmount;

        public Integer loanTerm;

        public Decimal currentDueAmount;

        public Decimal interestRate;

        public Decimal interestAmount;

        public LoanOptionsItemWrapper(String loanCollPlanId, String loanAccount, Decimal totalLoanAmount, Integer loanTerm, Decimal currentDueAmount, Decimal interestRate, Decimal interestAmount) {
            this.loanCollPlanId = loanCollPlanId;
            this.loanAccount = loanAccount;
            this.totalLoanAmount = totalLoanAmount;
            this.loanTerm = loanTerm;
            this.currentDueAmount = currentDueAmount;
            this.interestRate = interestRate;
            this.interestAmount = interestAmount;
        }
    }

    @InvocableMethod(label='Restructure Loans' description='Validates the format of a phone number' category='Loan Restructure')
    public static List<LoanRestructureResponse> getValidLoans(List<PhoneNumberWrapper> phoneNumbers) {

        List<String> list_phoneNumbers = new List<String>();
        for (PhoneNumberWrapper wrapper : phoneNumbers) {
            list_phoneNumbers.add(wrapper.phoneNumber);
        }
            // Fetch Contacts matching the phone numbers
        List<Contact> contacts = [
            SELECT Id, AccountId, Account.IsPersonAccount
            FROM Contact
            WHERE Phone IN :list_phoneNumbers
        ];

        // Collect Account IDs where the Account is a Person Account
        Set<Id> set_personAccountIds = new Set<Id>();
        for (Contact c : contacts) {
            if (c.AccountId != null && c.Account.IsPersonAccount) {
                set_personAccountIds.add(c.AccountId);
            }
        }

        // Fetch FinancialAccountParty records for the Person Accounts
        List<FinancialAccount> list_financialAccounts = [
            SELECT Id, Name
            FROM FinancialAccount
            WHERE Id IN (
                SELECT FinancialAccountId
                FROM FinancialAccountParty
                WHERE (AccountId IN :set_personAccountIds OR ContactId IN :contacts)
                    AND Role = 'Owner'
            ) AND Type = 'Loan' AND Status = 'Active'
        ];

        List<CollectionPlan> list_collectionPlans = [
            SELECT Id, Name, InitialDueAmount, CurrentDueAmount, TotalInterestAmount, FinancialAccount.InterestRate, FinancialAccount.Term, FinancialAccount.Name
            FROM CollectionPlan
            WHERE FinancialAccountId IN :list_financialAccounts AND IsClosed = false
            LIMIT 3
        ];        

        List<LoanOptionsItemWrapper> list_loanOptionsItems = new List<LoanOptionsItemWrapper>();
        for (CollectionPlan objCollPlan : list_collectionPlans) {
            LoanOptionsItemWrapper objLoanOptions = new LoanOptionsItemWrapper(
                objCollPlan.Id,
                objCollPlan.FinancialAccount.Name,
                objCollPlan.InitialDueAmount,
                objCollPlan.FinancialAccount.Term,
                objCollPlan.CurrentDueAmount,
                objCollPlan.FinancialAccount.InterestRate,
                objCollPlan.TotalInterestAmount
                );
            list_loanOptionsItems.add(objLoanOptions);
        }
        LoansWrapper objLoanWrapper = new LoansWrapper(list_loanOptionsItems, list_loanOptionsItems.size(), 'Total ' + list_loanOptionsItems.size() + ' active loans found for the provided phone numbers.');

        LoanRestructureResponse responseWrapper = new LoanRestructureResponse();
        responseWrapper.dataContainer = objLoanWrapper;
        return new List<LoanRestructureResponse>{responseWrapper};
    }


    @AuraEnabled
    global static LoanChangeResponse sendLoanChangeNotification(LoanChangeWrapper loanDetails){
        try {
            // send email to relationship manager with new loan details and tenure
            CollectionPlan cp = [SELECT Id, FinancialAccountId, Name FROM CollectionPlan WHERE Id = :loanDetails.loanCollPlanId LIMIT 1];

            FinancialAccount fa = [SELECT Id, Name FROM FinancialAccount WHERE Id = :cp.FinancialAccountId LIMIT 1];

            FinancialAccountParty fap = [SELECT Id, ContactId, AccountId FROM FinancialAccountParty WHERE FinancialAccountId = :fa.Id AND Role = 'Owner' LIMIT 1];

            Contact c = [SELECT Id, Name, Email FROM Contact WHERE Id = :fap.ContactId LIMIT 1];

            Account a = [SELECT Id, Name, PersonEmail FROM Account WHERE Id = :fap.AccountId AND IsPersonAccount = true LIMIT 1];

            String strCustomerEmail = c.Email != null ? c.Email : a.PersonEmail;

            // Assuming you have a method to send email, you can call it here
            String subject = 'Loan Restructure Request for ' + fa.Name;
            String emailbody = 'Dear Relationship Manager,\n\n' +
                        'The customer ' + c.Name + ' has requested a loan restructure for the loan account ' + fa.Name + '.\n' +
                        'New Tenure Choice: ' + loanDetails.tenureChoice + '\n' +
                        'New Monthly EMI: ' + loanDetails.monthlyEmi + '\n' +
                        'Total Payable: ' + loanDetails.totalPayable + '\n' +
                        'Total Interest: ' + loanDetails.totalInterest + '\n' +
                        'New Tenure (Years): ' + loanDetails.newTenureYears + '\n\n' +
                        'Please review the request and contact the customer for further details.\n\n' +
                        'Best Regards,\n' +
                        'Your Banking Team';

            List<OrgWideEmailAddress> owea = [
                SELECT Id FROM OrgWideEmailAddress 
                WHERE Address = :ORG_WIDE_EMAIL
                LIMIT 1
            ];

            Case caseRecord = new Case();
            caseRecord.Subject = 'Loan Restructure Request for ' + fa.Name;
            caseRecord.Description = 'The customer ' + c.Name + ' has requested a loan restructure for the loan account ' + fa.Name + '.\n' +
                        'New Tenure Choice: ' + loanDetails.tenureChoice + '\n' +
                        'New Monthly EMI: ' + loanDetails.monthlyEmi + '\n' +
                        'Total Payable: ' + loanDetails.totalPayable + '\n' +
                        'Total Interest: ' + loanDetails.totalInterest + '\n' +
                        'New Tenure (Years): ' + loanDetails.newTenureYears + '\n\n' +
                        'Please review the request and contact the customer for further details.';
            caseRecord.ContactId = c.Id;
            caseRecord.accountId = a.Id;
            caseRecord.Origin = 'Phone';
            insert caseRecord;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {c.Email});
            mail.setSubject(subject);
            mail.setPlainTextBody(emailbody);
            mail.setSaveAsActivity(true);
            mail.setWhatId(caseRecord.Id);
            mail.setTargetObjectId(c.Id);

            // Set verified sender to avoid deliverability issues
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            LoanChangeResponse response = new LoanChangeResponse();
            response.success = true;
            response.message = 'callSomeMethod executed successfully';
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    global class LoanChangeWrapper {
        @AuraEnabled public Id loanCollPlanId { get; set; }
        @AuraEnabled public Decimal monthlyEmi { get; set; }
        @AuraEnabled public Decimal totalPayable { get; set; }
        @AuraEnabled public Decimal totalInterest { get; set; }
        @AuraEnabled public Integer newTenureYears { get; set; }
        @AuraEnabled public String tenureChoice { get; set; }
    }

    global class LoanChangeResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    @AuraEnabled
    global static LoanChangeResponse callSomeMethod(){
        try {
            LoanChangeResponse response = new LoanChangeResponse();
            response.success = true;
            response.message = 'callSomeMethod executed successfully';
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
}