global class AnalyseDisputeCharge {

    global class DisputeChargeInput {
        @InvocableVariable(label='Messaging Session ID' description='Id of the messaging session' required=true)
        public Id messagingSessionId;
        @InvocableVariable(label='Total Amount' description='Amount of the transaction to be analyzed' required=true)
        public Decimal amount;
        @InvocableVariable(label='Disputed Amount' description='The dispute amount' required=true)
        public Decimal disputedAmount;
        @InvocableVariable(label='Phone Number' description='Phone number of the transaction to be analyzed' required=true)
        public String phoneNumber;
    }

    @InvocableMethod(label='Analyse Dispute Charge' description='Analyse the disputed charge and provide insights')
    global static List<String> analyseDisputeCharges(List<DisputeChargeInput> inputs) {
        Set<Id> sessionIds = new Set<Id>();
        Map<Id, DisputeChargeInput> map_msgIdToDisputeInput = new Map<Id, DisputeChargeInput>();
        // fetch a prompt template for each input and generate insights using the template and input data
        List<String> insightsList = new List<String>();
        for (DisputeChargeInput objDisInp : inputs) {
            Id idMessagingSessionId = objDisInp.messagingSessionId;
            Id messagingSessionId = '0Mwak00000DQGMbCAP';
            sessionIds.add(messagingSessionId);
        }

        Map<Id, Id> sessionToContentDocMap = new Map<Id, Id>();
        Map<Id, Id> contentDocToSessionDocMap = new Map<Id, Id>();

        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :sessionIds
            ORDER BY SystemModstamp DESC
        ];

        // Populate the map
        for (ContentDocumentLink cdl : cdls) {
            if(!sessionToContentDocMap.containsKey(cdl.LinkedEntityId)) {
                sessionToContentDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }
        for (Id idMsgSess : sessionIds) {
            if(sessionToContentDocMap.containsKey(idMsgSess)) {
                contentDocToSessionDocMap.put(sessionToContentDocMap.get(idMsgSess), idMsgSess);
            }
        }

        for (DisputeChargeInput objDisInp : inputs) {
            Id idMessagingSessionId = objDisInp.messagingSessionId;
            Decimal amount = objDisInp.amount;
            Decimal disputedAmount = objDisInp.disputedAmount;
            String phoneNumber = objDisInp.phoneNumber;
            Id contentDocId = sessionToContentDocMap.get(idMessagingSessionId);
            String generatedInsight = analyseUploadedDisputeProof(contentDocId, amount, disputedAmount, phoneNumber);
            insightsList.add(generatedInsight);
        }

        List<Dispute> list_disputes = new List<Dispute>();
        Map<String, Object> map_insights = new Map<String, Object>();
        Set<Id> set_transactionIds = new Set<Id>();

        for (String strInsight : insightsList) {
            try {
                // Parse JSON string into a map
                Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(strInsight);
                
                // Extract top-level values
                Boolean matchFound = (Boolean) parsedData.get('match_found');
                String contentDocumentId = (String) parsedData.get('contentDocumentId');
                String reasoning = (String) parsedData.get('reasoning');
                
                // Extract transaction details
                Map<String, Object> transactionDetails = (Map<String, Object>) parsedData.get('transaction_details');
                String transactionId = (String) transactionDetails.get('transaction_id');
                set_transactionIds.add(transactionId);
                Decimal actualAmount = (Decimal) transactionDetails.get('actual_amount');
                Decimal disputedAmount = (Decimal) transactionDetails.get('disputed_amount');
                String transactionDate = (String) transactionDetails.get('date');
                
                Map<String, Object> map_individualInsight = new Map<String, Object>();
                
                Id messagingSessionId = contentDocToSessionDocMap.get(contentDocumentId);

                
                // Create Case record if match found
                if (matchFound) {
                    map_individualInsight.put('reasoning', reasoning);
                    map_individualInsight.put('transactionId', transactionId);
                    map_individualInsight.put('actualAmount', actualAmount);
                    map_individualInsight.put('disputedAmount', disputedAmount);
                    map_individualInsight.put('transactionDate', transactionDate);
                    map_individualInsight.put('messagingSessionId', messagingSessionId);
    
                    map_insights.put(messagingSessionId, map_individualInsight);
                    
                }
            } catch (Exception e) {
                System.debug('Error parsing insight: ' + e.getMessage());
            }
        }
        Map<Id, Id> map_trscnToFinAcc = new Map<Id, Id>();
        for (FinancialAccountTransaction objFinAccTrn : [SELECT Id,FinancialAccountId FROM FinancialAccountTransaction WHERE Id IN :set_transactionIds]) {
            map_trscnToFinAcc.put(objFinAccTrn.Id, objFinAccTrn.FinancialAccountId);
        }

        for (Id msgSessId : map_insights.keySet()) {
            Dispute newDispute = new Dispute();
            newDispute.ActualAmount = (Decimal)((Map<String, Object>)map_insights.get(msgSessId)).get('actualAmount');
            newDispute.DisputedAmount = (Decimal)((Map<String, Object>)map_insights.get(msgSessId)).get('disputedAmount');
            newDispute.FinancialAccountId = map_trscnToFinAcc.get((Id)((Map<String, Object>)map_insights.get(msgSessId)).get('transactionId'));
            newDispute.Status = 'Submitted';
            newDispute.Description = (String)((Map<String, Object>)map_insights.get(msgSessId)).get('reasoning');
            list_disputes.add(newDispute);
        }
        
        // Insert cases if any were created
        if (!list_disputes.isEmpty()) {
            insert list_disputes;
            return new List<String>{'Disputes created successfully with the following insights'};
        }
        
        return new List<String> { 'There were no transactions that matched the dispute proof.' };
    }

    public static String analyseUploadedDisputeProof(String contentDocId, Decimal amount, Decimal disputedAmount, String phoneNumber) {
        // 1. Prepare the Input Map
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

        // Input: ContentDocument (Expecting a Record Input in Prompt Builder)
        Map<String, String> docRecord = new Map<String, String>();
        docRecord.put('id', contentDocId); 
        ConnectApi.WrappedValue docValue = new ConnectApi.WrappedValue();
        docValue.value = docRecord;
        inputParams.put('Input:ContentDocument', docValue);

        // Input: Amount (Decimal/Primitive)
        ConnectApi.WrappedValue amountValue = new ConnectApi.WrappedValue();
        amountValue.value = String.valueOf(amount);
        inputParams.put('Input:Amount', amountValue);

        // Input: DisputedAmount (Decimal/Primitive)
        ConnectApi.WrappedValue disputedAmountValue = new ConnectApi.WrappedValue();
        disputedAmountValue.value = String.valueOf(disputedAmount);
        inputParams.put('Input:DisputedAmount', disputedAmountValue);

        // Input: Phone Number (String/Primitive)
        ConnectApi.WrappedValue phoneValue = new ConnectApi.WrappedValue();
        phoneValue.value = phoneNumber;
        inputParams.put('Input:PhoneNumber', phoneValue);

        System.debug('Prepared input parameters for Einstein Prompt: ' + docValue.value);
        System.debug('Prepared input parameters for Einstein Prompt: ' + amountValue.value);
        System.debug('Prepared input parameters for Einstein Prompt: ' + disputedAmountValue.value);
        System.debug('Prepared input parameters for Einstein Prompt: ' + phoneValue.value);

        // 2. Configure invocation parameters
        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
            // 3. Call the Einstein Prompt Template service
            // Ensure 'MatchDisputedCharge' API Name matches your Template exactly
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    '0hfak00000PJTkfAAH',
                    executeTemplateInput
                );
            System.debug('Einstein Prompt Generations Output: ' + generationsOutput);
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            return response.text;
        } catch (Exception e) {
            System.debug('Error calling Einstein Prompt: ' + e.getMessage());
            throw e;
        }
    }
}

