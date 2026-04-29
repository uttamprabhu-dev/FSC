global class BankingAgentActions {
    private static final String ORG_WIDE_EMAIL = OTPHelper.ORG_WIDE_EMAIL;
    
    @AuraEnabled
    global static Boolean sendLoanChangeNotification(LoanChangeWrapper loanDetails){
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
            String body = 'Dear Relationship Manager,\n\n' +
                        'The customer ' + c.Name + ' has requested a loan restructure for the loan account ' + fa.Name + '.\n' +
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

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {c.Email});
            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(false);

            // Set verified sender to avoid deliverability issues
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            return true;
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
    }

    @AuraEnabled
    public static Boolean callSomeMethod(){
        try {
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}