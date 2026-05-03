global class FetchCustomerTransactions {

    global class FinAccTrnsResponse {
        @InvocableVariable(label='Action Result' description='The result of the transactions fetched' required=true)
        public FinAccTrnsWrapper dataContainer;
    }

    global class FinAccTrnsWrapper {
        @InvocableVariable(label='Transactions' description='List of loan options available for restructuring' required=true)
        public List<FinAccTransaction> transactionResponse;
        @InvocableVariable(label='Total Count' description='Total count of recent transactions found' required=true)
        public Integer totalCount;
        @InvocableVariable(label='Summary Message' description='Summary message for the transactions' required=true)
        public String summaryMessage;

        public FinAccTrnsWrapper(List<FinAccTransaction> transactionResponse, Integer totalCount, String summaryMessage) {
            this.transactionResponse = transactionResponse;
            this.totalCount = totalCount;
            this.summaryMessage = summaryMessage;
        }
    }

    global class FinAccTransaction {
        @InvocableVariable(
            label='Financial Transaction ID'
            description='Id of the transaction.'
            required=true
        ) public Id FinAccTransactionId;
        @InvocableVariable(
            label='Financial Transaction Name'
            description='Id of the transaction.'
            required=true
        ) public String name;
        @InvocableVariable(
            label='Financial Transaction Amount'
            description='Amount of the transaction.'
            required=true
        ) public Decimal amount;
        @InvocableVariable(
            label='Financial Transaction Type'
            description='Type of the transaction: Credit/Debit'
            required=true
        ) public String type;
        @InvocableVariable(
            label='Financial Transaction Date'
            description='Date of the transaction'
            required=true
        ) public Date trnsDate;

        public FinAccTransaction(Id FinAccTransactionId, String name, Decimal amount, String type, Date trnsDate) {
            this.FinAccTransactionId = FinAccTransactionId;
            this.name = name;
            this.amount = amount;
            this.type = type;
            this.trnsDate = trnsDate;
        }
    }

    global class InputWrapper {
        @InvocableVariable(
            label='Phone Number'
            description='Phone number of the customer'
            required=true
        ) public String phoneNumber;
    }

    @InvocableMethod(label='Fetch Customer Transactions' description='Fetches customer transactions')
    global static List<FinAccTrnsResponse> handleFetchFinancialAccountsBalance(List<InputWrapper> inputs) {
        List<String> list_phoneNumbers = new List<String>();
        for (InputWrapper input : inputs) {
            list_phoneNumbers.add(input.phoneNumber);
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
            ) AND Status = 'Active'
        ];

        List<FinancialAccountTransaction> list_financialAccountTransactions = [
            SELECT Id, Name, DebitCreditIndicator, Amount, TransactionDate
            FROM FinancialAccountTransaction
            WHERE FinancialAccountId IN :list_financialAccounts
            ORDER BY TransactionDate DESC
            LIMIT 10
        ];        

        List<FinAccTransaction> list_FinAccTransactions = new List<FinAccTransaction>();
        for (FinancialAccountTransaction objFinAccTran : list_financialAccountTransactions) {
            list_FinAccTransactions.add(new FinAccTransaction(objFinAccTran.Id, objFinAccTran.Name, objFinAccTran.Amount, objFinAccTran.DebitCreditIndicator,objFinAccTran.TransactionDate.date()));
        }
        // return list_FinAccTransactions;
        FinAccTrnsWrapper objFinAccWrapper = new FinAccTrnsWrapper(list_FinAccTransactions, list_FinAccTransactions.size(), 'Total of ' + list_FinAccTransactions.size() + ' recent transactions found.');

        FinAccTrnsResponse responseWrapper = new FinAccTrnsResponse();
        responseWrapper.dataContainer = objFinAccWrapper;
        return new List<FinAccTrnsResponse>{responseWrapper};
    }
}