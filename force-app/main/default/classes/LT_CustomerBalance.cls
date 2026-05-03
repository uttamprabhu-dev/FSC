global class LT_CustomerBalance  {

    global class FinAccBalResponse {
        @InvocableVariable(label='Action Result' description='The result of the transactions fetched' required=true)
        public FinAccBalWrapper dataContainer;
    }

    global class FinAccBalWrapper {
        @InvocableVariable(label='Balances' description='List of accounts' required=true)
        public List<FinAccBalance> balanceResponse;
        @InvocableVariable(label='Total Count' description='Total count of recent transactions found' required=true)
        public Integer totalCount;
        @InvocableVariable(label='Summary Message' description='Summary message for the transactions' required=true)
        public String summaryMessage;

        public FinAccBalWrapper(List<FinAccBalance> balanceResponse, Integer totalCount, String summaryMessage) {
            this.balanceResponse = balanceResponse;
            this.totalCount = totalCount;
            this.summaryMessage = summaryMessage;
        }
    }

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

    global class InputWrapper {
        @InvocableVariable(
            label='Phone Number'
            description='Phone number of the customer'
            required=true
        ) public String phoneNumber;
    }

    @InvocableMethod(label='Fetch Users Balance' description='Fetches customer balance')
    global static List<FinAccBalResponse> handleFetchFinancialAccountsBalance(List<InputWrapper> inputs) {
        List<String> phoneNumbers = new List<String>();
        for (InputWrapper input : inputs) {
            phoneNumbers.add(input.phoneNumber);
        }

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
        // return list_finAccBalances;
        FinAccBalWrapper objFinAccWrapper = new FinAccBalWrapper(list_finAccBalances, list_finAccBalances.size(), 'Total of ' + list_finAccBalances.size() + ' recent balances found.');

        FinAccBalResponse responseWrapper = new FinAccBalResponse();
        responseWrapper.dataContainer = objFinAccWrapper;
        return new List<FinAccBalResponse>{responseWrapper};
    }
}