global class FetchCustomerBalance {

    global class FinAccBalance {
        @InvocableVariable public Id finAccBalanceId;
        @InvocableVariable public String name;
        @InvocableVariable public Decimal amount;
        @InvocableVariable public String type;

        public FinAccBalance(Id finAccBalanceId, String name, Decimal amount, String type) {
            this.finAccBalanceId = finAccBalanceId;
            this.name = name;
            this.amount = amount;
            this.type = type;
        }
    }
    @InvocableMethod(label='Fetch Customer Balance' description='Fetches customer balance')
    global static List<FinAccBalance> handleFetchFinancialAccountsBalance(List<String> phoneNumbers) {
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
            SELECT Id, Name, Amount, Type
            FROM FinancialAccountBalance
            WHERE FinancialAccountId IN :financialAccounts
        ];        

        List<FinAccBalance> list_finAccBalances = new List<FinAccBalance>();
        for (FinancialAccountBalance fab : financialAccountBalance) {
            list_finAccBalances.add(new FinAccBalance(fab.Id, fab.Name, fab.Amount, fab.Type));
        }
        return list_finAccBalances;
    }
}