
/* Second part to "Data Cleansing" process. Needed to update contact information based on a Source of Truth file. */


/****************************************************************************

                      -- PT2: ATTACH GROUP CONTACT INFO -- 

********************************************************************************/



/***************************

STEP 4 -- PULL IN GROUP INFO AND ADDRESS FROM DATABASE

***************************/



-- PULL IN GROUP UNQ, ID FROM GROUP ID
DROP TABLE PROJECT_STAGE10

SELECT DISTINCT A.PRPR_ID, A.THRU_DTE, A.GROUP_ID, B.UNQ AS GROUP_UNQ, B.MCTN_ID, B.F_NAME
INTO PROJECT_STAGE10
FROM PROJECT_STAGE2 A
	LEFT JOIN TCS_PROV_FILE_TEMP_A B
	ON A.GROUP_ID = B.MED_GRP_ID




-- UPDATE TO GROUP ID IN TCS (PULL WHATEVER AVAILABLE/ASSUME ID IS FOR HOSPITAL OR SINGLE-PROVIDER)
UPDATE A 
SET A.GROUP_ID = B.MED_GRP_ID,
	A.GROUP_UNQ = B.UNQ,
	A.MCTN_ID = B.MCTN_ID,
	A.F_NAME = B.F_NAME 
FROM PROJECT_STAGE10 A 
	INNER JOIN TCS_PROV_FILE_TEMP_A B ON ltrim(rtrim(A.PRPR_ID)) = ltrim(rtrim(B.PROV_ID))
WHERE (A.THRU_DTE BETWEEN B.PRAD_EFF_DT AND B.PRAD_TERM_DT)
AND A.GROUP_ID IS NULL OR A.GROUP_ID = '' GO





	
  /***    TAKE GROUP_UNQ TO LOOK IN UNQ_DATABASE   (Separate Database)   ***/
  
   			/***    CONVERT COLUMNS TO TEXT !!!!!!!!   ***/
   			
   		   /*** 	=CHAR(39)&A2&CHAR(39)&CHAR(44)     ***/
   		   
  	
SELECT DISTINCT A.GROUP_UNQ FROM PROJECT_STAGE10 A WHERE A.GROUP_UNQ <> '' AND A.GROUP_UNQ IS NOT NULL
-- 511 GROUP UNQs


--DROP TABLE PROJECT_STAGE10_UNQ    /***   DON'T DROP IF JUST REFRESHING   ***/

-- =====================================================================================================================




UPDATE A SET A.ENTITY_CD_TYPE = CASE WHEN A.ENTITY_CD_TYPE = '1' THEN 'INDIVIDUAL'
						   WHEN A.ENTITY_CD_TYPE = '2' THEN 'ORGANIZATION'
						   ELSE A.ENTITY_CD_TYPE END 
FROM PROJECT_STAGE10_UNQ A GO
 
DELETE A
FROM PROJECT_STAGE10_UNQ A
WHERE A.ENTITY_CD_TYPE = 'UNQ DEACTIVATED'
GO
 
 
-- BRING BACK TO TIE TO ENCOUNTERS 
DROP TABLE PROJECT_STAGE11	   
	   		 
SELECT *
INTO PROJECT_STAGE11
FROM PROJECT_STAGE10 A
	LEFT JOIN PROJECT_STAGE10_UNQ B
	ON A.GROUP_UNQ = B.UNQ



-- =====================================================================================================================





/***************************

STEP 5 -- PULL SERVICING PROVIDER INFO

***************************/


DROP TABLE PROJECT_STAGE12

SELECT DISTINCT A.PRPR_ID, B.PROVIDER_UNQ_NUM, B.PROVIDER_NM, A.GROUP_ID, B.PROVIDER_GRP_ID, B.PROVIDER_GRP_NM,
B.PROVIDER_TYPE_CD, B.PROVIDER_SPECIALTY_CD, B.PROVIDER_TYPE_CD_DESC, B.PROVIDER_SPECIALTY_CD_DESC
INTO PROJECT_STAGE12
FROM PROJECT_STAGE11 A 
	LEFT JOIN PROVIDER_TBL B
	ON ltrim(rtrim(A.PRPR_ID)) = ltrim(rtrim(B.PROVIDER_ID))

DELETE FROM PROJECT_STAGE12 WHERE PRPR_ID IS NULL GO 
DELETE FROM PROJECT_STAGE12 WHERE GROUP_ID IS NULL GO 
	
/*********************
***    1,267 rows     ***     (1,244 DISTINCT PROVIDERS)   
**********************/









  /*********    ADD TO STAGE 2 TABLE    ***********/    
             
UPDATE A                                     
SET A.GROUP_ID = B.GROUP_ID,
	A.GROUP_NAME = CASE WHEN B.GROUP_NAME IS NOT NULL 
				THEN B.GROUP_NAME ELSE B.F_NAME END,
	A.PRAD_ADDR1 = B.PRAD_ADDR1,
	A.PRAD_ADDR2 = B.PRAD_ADDR2,
	A.PRAD_CITY = B.PRAD_CITY,
	A.PRAD_STATE = B.PRAD_STATE,
	A.PRAD_ZIP = LEFT(B.PRAD_ZIP,5),
	A.PRAD_PHONE = B.PRAD_PHONE,
	A.PRAD_FAX = B.PRAD_FAX
FROM PROJECT_STAGE2 A 
	INNER JOIN PROJECT_STAGE11 B
	ON ltrim(rtrim(A.PRPR_ID)) = ltrim(rtrim(B.PRPR_ID))
WHERE A.PRPR_ID IS NOT NULL
GO


UPDATE A                                     
SET A.PRCF_MCTR_SPEC = B.PROVIDER_SPECIALTY_CD,
	A.PRPR_MCTR_TYPE = B.PROVIDER_TYPE_CD,
	A.PRPR_MCTR_TYPE_DESC = B.PROVIDER_TYPE_CD_DESC,
	A.PRCF_MCTR_SPEC_DESC = B.PROVIDER_SPECIALTY_CD_DESC,
	A.PRPR_NAME = B.PROVIDER_NM
FROM PROJECT_STAGE2 A 
	INNER JOIN PROJECT_STAGE12 B
	ON ltrim(rtrim(A.PRPR_ID)) = ltrim(rtrim(B.PRPR_ID))
WHERE A.PRPR_ID IS NOT NULL
GO



-- FILL IN NAME AS PRPR_NAME IF GROUP NAME MISSING 
UPDATE A SET A.GROUP_NAME = A.PRPR_NAME FROM PROJECT_STAGE2 A 
	WHERE A.GROUP_NAME IS NULL OR A.GROUP_NAME = '' OR A.GROUP_NAME = 'NA' GO



-- FILL IN FAX NUMBERS FROM OTH SOURCE
UPDATE A
SET A.PRAD_FAX = B.PRAD_FAX
FROM PROJECT_STAGE2 A
	INNER JOIN MAIL_FILE_FAX_NUM_PULL_202001 B
	ON ltrim(rtrim(A.PRPR_ID)) = ltrim(rtrim(B.PRAD_ID)) COLLATE Latin1_General_BIN
WHERE B.PRAD_FAX NOT IN ('0000000000','') AND A.PRAD_FAX IS NULL	
GO




-- ==================================================================================================================




ALTER TABLE PROJECT_STAGE2 ADD PROV_TERM_IND NVARCHAR (5) GO 
ALTER TABLE PROJECT_STAGE2 ADD POS_EXCLU_IND NVARCHAR (1) GO 
ALTER TABLE PROJECT_STAGE2 ADD PROV_TYPE_EXCLU_IND NVARCHAR (1) GO 
ALTER TABLE PROJECT_STAGE2 ADD PROV_SPEC_EXCLU_IND NVARCHAR (1) GO 
ALTER TABLE PROJECT_STAGE2 ADD SOLE_SOURCE_V12_IND NVARCHAR (1) GO 
ALTER TABLE PROJECT_STAGE2 ADD SOLE_SOURCE_V22_IND NVARCHAR (1) GO 
ALTER TABLE PROJECT_STAGE2 ADD RET_METHOD NVARCHAR (100) GO 






/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////
/****	                                               					   	 ****/  
/****	                                               						 ****/ 
/****	                       LOOOOOK  HEREEEEEEEE!!!                       ****/  
/****	                                             						 ****/ 
/****	                          END OF PART 2                              ****/ 
/****	                                                                     ****/                            
/****	           RUN   ***PT3***   SCRIPT NEXT !!!!!!!!!!!                 ****/
/****	                                                                     ****/ 
/****	                                               						 ****/ 
/****	                                                                     ****/ 
/****	                                                                     ****/ 
/****	                                                                     ****/ 
/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////