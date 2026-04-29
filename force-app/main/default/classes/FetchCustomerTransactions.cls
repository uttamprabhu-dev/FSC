global class FetchCustomerTransactions {

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

        public FinAccTransaction(Id FinAccTransactionId, String name, Decimal amount, String type) {
            this.FinAccTransactionId = FinAccTransactionId;
            this.name = name;
            this.amount = amount;
            this.type = type;
        }
    }
    @InvocableMethod(label='Fetch Customer Transactions' description='Fetches customer transactions')
    global static List<FinAccTransaction> handleFetchFinancialAccountsBalance(List<String> list_phoneNumbers) {
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
            ) AND Type = 'Credit Card' AND Status = 'Active'
        ];

        List<FinancialAccountTransaction> list_financialAccountTransactions = [
            SELECT Id, Name, DebitCreditIndicator, Amount
            FROM FinancialAccountTransaction
            WHERE FinancialAccountId IN :list_financialAccounts AND DebitCreditIndicator = 'Credit'
            ORDER BY TransactionDate DESC
            LIMIT 10
        ];        

        List<FinAccTransaction> list_FinAccTransactions = new List<FinAccTransaction>();
        for (FinancialAccountTransaction objFinAccTran : list_financialAccountTransactions) {
            list_FinAccTransactions.add(new FinAccTransaction(objFinAccTran.Id, objFinAccTran.Name, objFinAccTran.Amount, objFinAccTran.DebitCreditIndicator));
        }
        return list_FinAccTransactions;
    }
}