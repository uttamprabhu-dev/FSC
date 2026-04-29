@IsTest
public class TestBanking {

    @IsTest(SeeAllData=true)
    static void methodName2(){
        // Query for a user by email
        User contextUser = [SELECT Id FROM User WHERE Username = 'agentforce_service_agent@00dak00000ofcsj1643862421.ext' LIMIT 1];
        
        Test.startTest();
        System.runAs(contextUser){
            String list_insights = AnalyseDisputeCharge.analyseUploadedDisputeProof('069ak00000KQQUoAAP', 100, 80, '8088969743');
            System.debug('Result from analyseDisputeCharges: ' + list_insights);
        }
        Test.stopTest();
        
    }
}   