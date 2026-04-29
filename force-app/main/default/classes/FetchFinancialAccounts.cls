global class FetchFinancialAccounts {
    @InvocableMethod(label='Fetch Financial Accounts')
    global static List<FinancialAccountBalance> handleFetchFinancialAccounts(List<String> phoneNumbers) {
        // Fetch Contacts matching the phone numbers
        List<Contact> contacts = [
            SELECT Id, AccountId, Account.IsPersonAccount
            FROM Contact
            WHERE Phone IN :phoneNumbers
        ];

        // Collect Account IDs where the Account is a Person Account
        Set<Id> personAccountIds = new Set<Id>();
        for (Contact c : contacts) {
            if (c.AccountId != null && c.Account.IsPersonAccount) {
                personAccountIds.add(c.AccountId);
            }
        }

        // Fetch FinancialAccountParty records for the Person Accounts
        List<FinancialAccount> financialAccounts = [
            SELECT Id, Name
            FROM FinancialAccount
            WHERE Id IN (
                SELECT FinancialAccountId
                FROM FinancialAccountParty
                WHERE (AccountId IN :personAccountIds OR ContactId IN :contacts)
                    AND Role = 'Owner'
            ) AND Type = 'Savings'
        ];

        List<FinancialAccountBalance> financialAccountBalance = [
            SELECT Id, Name, Amount
            FROM FinancialAccountBalance
            WHERE FinancialAccountId IN :financialAccounts
        ];        

        return financialAccountBalance;
    }
}
