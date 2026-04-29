global class FetchDisputeTransactions {

    @InvocableMethod(label='Fetch Dispute Transactions' description='Fetches customer transactions')
    global static List<String> handleFetchDisputeTransactions(List<String> list_phoneNumbers) {
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

        String response = '';
        for (FinancialAccountTransaction objFinAccTran : list_financialAccountTransactions) {

            response += 'Transaction ID: ' + objFinAccTran.Id + ', Name: ' + objFinAccTran.Name + ', Amount: ' + objFinAccTran.Amount + ', Type: ' + objFinAccTran.DebitCreditIndicator + '\n';
        }
        return new List<String>{response};
     }
}