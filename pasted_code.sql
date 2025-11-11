Tier_dict: ((`$("Tier 1";"Tier 2";"Tier 3";"Non-ECL";"Direct Competitor Writer";"Non-Tier Targets";"Average"))!(1 2 3 5 4 6 7));
     t:select High_impact,TERRITORY_NAME,REGION_NAME,Account_Id,Id,Presentation_ID_vod__c,Successful_Call,Call_Type_vod__c,Target_Flag,Account_Type,role,ACCT_TYP_CD_iv_GSK_CDE__c,Segment from   AIP_FULL_COMMERCIAL.AIP_G_CALLS_BASE_TBL;
     t:$[(count t)>0;t;:t];
         geo:`Region;
    t:update Geography:REGION_NAME,Parent_Geo:`NATION from t;
    role:(exec first role from t);
    if[role in `reg;  geo:`Territory; t:update Geography:TERRITORY_NAME,Parent_Geo:REGION_NAME from t];
    if[role in `ter;  geo:`Territory; t:update Geography:TERRITORY_NAME,Parent_Geo:TERRITORY_NAME from t];
    tb:t;
            t:select Impact_Calls:count distinct Id by Geography:Parent_Geo,Segment from tb where  Call_Type_vod__c like "*Detail*",Account_Type like "HCP",High_impact=1;
t:t uj select Impact_Calls:count distinct Id by Geography,Segment from tb where  Call_Type_vod__c like "*Detail*",Account_Type like "HCP",High_impact=1;
t:update new_tier:Tier_dict Segment from t;
t:`new_tier xasc select from t;
t:delete new_tier from t;
t:(geo,`$("Segment";"Calls")) xcol t;
t:![t;();0b;{x!(^;0j;)each x}(exec c from meta t where t="j")];