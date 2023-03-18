
/*    Project related to finding all sources where DX code was documented. Need to pull in all relevant information once a match is found. */




/****************************************************************************

                      -- PT1: MAPPING TO SOURCES -- 

********************************************************************************/



/***************************

STEP 1 -- ASSIGN HCC/DX CODES AND SOURCE TO SAMPLE

***************************/



DROP TABLE PROJECT_STAGE2A GO

SELECT DISTINCT 
A.ID_NO AS ID,
F.SBSB_ID AS UNQKEY,
B.PROJ_ID,
C.RSK_MODEL AS RSK_MOD,
LEFT(A.CONTROL_NO,12) AS CLAIM_ID, 
A.PROV_TYPE, 
A.FROM_DTE, 
A.THRU_DTE, 
A.DIAG_CODE AS DX_CODE
INTO PROJECT_STAGE2A
FROM MSTR_TBL A
INNER JOIN MA_RSK_ADJ_PROJ_XWALK B ON A.FILE_ID = B.RET_FILE_ID
	LEFT JOIN (SELECT DISTINCT MEME_ID, RSK_MODEL FROM ENVY_MA_RSK_MOD_MEM_MONTH WHERE RSK_PER='2015_FIN') C ON A.ID_NO = C.MEME_ID
		--LEFT JOIN (SELECT * FROM MA_RSK_DX_HCC_MOD WHERE PAY_YEAR='2015') E ON A.DIAG_CODE = E.ICD9_DX_CD AND C.RSK_MODEL = E.RSK_MODEL
			--INNER JOIN PROJECT_DX_VERTICAL D ON A.ID_NO = D.MEME_ID AND A.DIAG_CODE = D.DX
				INNER JOIN PROJECT_STAGE1 F ON A.ID_NO = F.ID COLLATE Latin1_General_BIN
				
WHERE YEAR(A.THRU_DTE) = '2014'
AND A.DELETE_IND = ''



/*** FIND MEMBERS WITH CHANGED IDS ***/

DROP TABLE PROJECT_STAGE1A

SELECT *
INTO PROJECT_STAGE1A
FROM PROJECT_STAGE1 A
WHERE A.OLD_ID <> A.ID

INSERT INTO PROJECT_STAGE2A
SELECT DISTINCT A.ID_NO AS ID, F.SBSB_ID AS UNQKEY, B.PROJ_ID, C.RSK_MODEL AS RSK_MOD,
LEFT(A.CONTROL_NO,12) AS CLAIM_ID, A.PROV_TYPE, 
A.FROM_DTE, A.THRU_DTE, A.DIAG_CODE AS DX_CODE
FROM MSTR_TBL A
INNER JOIN MA_RSK_ADJ_PROJ_XWALK B ON A.FILE_ID = B.RET_FILE_ID
	LEFT JOIN (SELECT DISTINCT MEME_ID, RSK_MODEL FROM ENVY_MA_RSK_MOD_MEM_MONTH WHERE RSK_PER='2015_FIN') C ON A.ID_NO = C.MEME_ID
		--LEFT JOIN (SELECT * FROM MA_RSK_DX_HCC_MOD WHERE PAY_YEAR='2015') E ON A.DIAG_CODE = E.ICD9_DX_CD AND C.RSK_MODEL = E.RSK_MODEL
			--INNER JOIN PROJECT_DX_VERTICAL D ON A.ID_NO = D.MEME_ID AND A.DIAG_CODE = D.DX
				INNER JOIN PROJECT_STAGE1A F ON A.ID_NO = F.OLD_ID COLLATE Latin1_General_BIN
				
WHERE YEAR(A.THRU_DTE) = '2014'
AND A.DELETE_IND = ''




/*** ATTACH SMPL GIVEN HCCS TO STAGE2 ***/

DROP TABLE PROJECT_DX_HCC_VERTICAL

SELECT DISTINCT A.*, C.HCC
INTO PROJECT_DX_HCC_VERTICAL
FROM PROJECT_DX_VERTICAL A
	INNER JOIN MA_RSK_DX_HCC_MOD B
	ON A.DX = B.ICD9_DX_CD
	AND CASE WHEN B.MOD_SUB_DIV = 'V21                      ' THEN 'V12'       /*  Added fix to switched values  */
		         WHEN B.MOD_SUB_DIV = 'V22                      ' THEN 'V22'
		         ELSE B.MOD_SUB_DIV END = A.MOD_SUB_DIV
		INNER JOIN PROJECT_HCC_VERTICAL C
		ON A.SMPL_ENROLLEE_ID = C.SMPL_ENROLLEE_ID
		AND B.HCC_CODE = C.HCC
WHERE B.PAY_YEAR = '2015'




DROP TABLE PROJECT_STAGE2B GO

SELECT DISTINCT A.*, B.HCC AS HCC_CODE,
CASE WHEN B.MOD_SUB_DIV = 'V21                      ' THEN 'V12'       /*  Added fix to switched values  */
		         WHEN B.MOD_SUB_DIV = 'V22                      ' THEN 'V22'
		         ELSE B.MOD_SUB_DIV END = A.MOD_SUB_DIV
INTO PROJECT_STAGE2B
FROM PROJECT_STAGE2A A
	LEFT JOIN PROJECT_DX_HCC_VERTICAL B
	ON A.DX_CODE = B.DX

INSERT INTO PROJECT_STAGE2B
SELECT DISTINCT A.*, E.HCC_CODE, E.MOD_SUB_DIV 
FROM PROJECT_STAGE2A A
	LEFT JOIN (SELECT * FROM MA_RSK_DX_HCC_MOD WHERE PAY_YEAR='2015') E
	ON A.DX_CODE = E.ICD9_DX_CD AND A.RSK_MOD = E.RSK_MODEL


-- DISTINCT STAGE 2 TABLE
DROP TABLE PROJECT_STAGE2 GO

SELECT DISTINCT *
INTO PROJECT_STAGE2
FROM PROJECT_STAGE2B






ALTER TABLE PROJECT_STAGE2 ADD HCC_DESCRIPTION VARCHAR (255) GO


-- HCC DESCRIPTION
UPDATE A 
SET A.HCC_DESCRIPTION = B.Disease
FROM PROJECT_STAGE2 A 
	LEFT JOIN MA_RSK_DX_HCC_MOD B 
	ON A.HCC_CODE = B.HCC_CODE
	AND A.MOD_SUB_DIV = B.MOD_SUB_DIV
WHERE B.PAY_YEAR = '2015'  
GO


UPDATE A
SET A.HCC_DESCRIPTION = B.Disease
FROM PROJECT_STAGE2 A
	INNER JOIN MA_RSK_MOD_COEF_FACT B
	ON concat(ltrim(rtrim(A.RSK_MOD)),'-',A.HCC_CODE) = B.COEF_ID
	AND A.MOD_SUB_DIV = B.MOD_SUB_DIV
WHERE B.PAY_YEAR = 2015
GO

-- ==================================================================================================================





/***************************

STEP 2 -- FILL IN PROVIDER ID & CLAIM INFO

***************************/




ALTER TABLE PROJECT_STAGE2 ADD PRPR_ID VARCHAR (12) GO
ALTER TABLE PROJECT_STAGE2 ADD GROUP_ID VARCHAR (12) GO
ALTER TABLE PROJECT_STAGE2 ADD SERVICING_PROV_NPI_NUM VARCHAR (12) GO 
ALTER TABLE PROJECT_STAGE2 ADD PLACE_OF_SERVICE_CD VARCHAR (12) GO
ALTER TABLE PROJECT_STAGE2 ADD PLACE_OF_SERVICE_DESC VARCHAR (255) GO	



/*********************
-- SOURCE: BASE CLAIMS
**********************/

DROP TABLE PROJECT_STAGE3


		-- JOIN ON CLAIM ID                                                    
SELECT DISTINCT A.ID, A.UNQKEY, A.DX_CODE, A.FROM_DTE, A.THRU_DTE,
A.CLAIM_ID, B.CLCL_ID, B.PRPR_ID, B.NPI, B.PSCD_ID, B.CLHP_DC_STAT, B.BILL_TYPE_CD, B.RCRC_ID, B.IPCD_ID, B.CLCL_PAYEE_PR_ID
INTO PROJECT_STAGE3
FROM PROJECT_STAGE2 A
	LEFT JOIN UNLINKED_DATA_SET_BaseClaims B
	ON ltrim(rtrim(A.CLAIM_ID)) = ltrim(rtrim(B.CLCL_ID))



		-- FIND ADJUSTED CLAIMS                                                                                 
UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID,
	A.CLCL_PAYEE_PR_ID = B.CLCL_PAYEE_PR_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaims B
	ON LEFT(A.CLAIM_ID,11) = LEFT(B.CLCL_ID,11)
	AND ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
WHERE A.PRPR_ID IS NULL
GO



		-- JOIN ON SBSB_ID, DX, & DOS  (5-DAY RANGE)                              
UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID,
	A.CLCL_PAYEE_PR_ID = B.CLCL_PAYEE_PR_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaims B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX))
	AND (A.THRU_DTE BETWEEN dateadd(day,-0,B.DOS_High) AND dateadd(day,0,B.DOS_High))
WHERE A.PRPR_ID IS NULL
GO

UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID,
	A.CLCL_PAYEE_PR_ID = B.CLCL_PAYEE_PR_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaims B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX))
	AND (A.THRU_DTE BETWEEN dateadd(day,-1,B.DOS_High) AND dateadd(day,1,B.DOS_High))
WHERE A.PRPR_ID IS NULL
GO

UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID,
	A.CLCL_PAYEE_PR_ID = B.CLCL_PAYEE_PR_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaims B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX))
	AND (A.THRU_DTE BETWEEN dateadd(day,-2,B.DOS_High) AND dateadd(day,2,B.DOS_High))
WHERE A.PRPR_ID IS NULL
GO



		-- JOIN ON SBSB_ID, DX, & DOS  (5-DAY RANGE)  [Additional Diags table]       
UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaimsAddlDiag B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX))
	AND (A.THRU_DTE BETWEEN dateadd(day,-0,B.DOS_High) AND dateadd(day,0,B.DOS_High))
WHERE A.PRPR_ID IS NULL
GO

UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaimsAddlDiag B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX))
	AND (A.THRU_DTE BETWEEN dateadd(day,-1,B.DOS_High) AND dateadd(day,1,B.DOS_High))
WHERE A.PRPR_ID IS NULL
GO

UPDATE A
SET A.PRPR_ID = B.PRPR_ID,
	A.NPI = B.NPI,
	A.PSCD_ID = B.PSCD_ID,
	A.CLHP_DC_STAT = B.CLHP_DC_STAT,
	A.BILL_TYPE_CD = B.BILL_TYPE_CD,
	A.RCRC_ID = B.RCRC_ID,
	A.IPCD_ID = B.IPCD_ID,
	A.CLCL_ID = B.CLCL_ID
FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaimsAddlDiag B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX))
	AND (A.THRU_DTE BETWEEN dateadd(day,-2,B.DOS_High) AND dateadd(day,2,B.DOS_High))
WHERE A.PRPR_ID IS NULL
GO


UPDATE A SET A.CLCL_PAYEE_PR_ID = B.CLCL_PAYEE_PR_ID FROM PROJECT_STAGE3 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaims B ON A.CLCL_ID = B.CLCL_ID
WHERE A.CLCL_PAYEE_PR_ID IS NULL GO









ALTER TABLE PROJECT_STAGE3 ADD PLACE_OF_SERVICE_DESC CHAR (50) GO
ALTER TABLE PROJECT_STAGE3_PROF_RA ADD PLACE_OF_SERVICE_DESC CHAR (50) GO
ALTER TABLE PROJECT_STAGE3_INST_RA ADD PLACE_OF_SERVICE_DESC CHAR (50) GO

UPDATE A
SET A.PLACE_OF_SERVICE_DESC = B.PLACE_OF_SERVICE_DESC
FROM PROJECT_STAGE3 A 
	LEFT JOIN MAIL_FILE_PSCD_ID_DESC B
	ON A.PSCD_ID = B.PSCD_ID
WHERE A.PSCD_ID IS NOT NULL
GO

UPDATE A
SET A.PLACE_OF_SERVICE_DESC = B.PLACE_OF_SERVICE_DESC
FROM PROJECT_STAGE3_PROF_RA A 
	LEFT JOIN MAIL_FILE_PSCD_ID_DESC B
	ON A.PSCD_ID = B.PSCD_ID
WHERE A.PSCD_ID IS NOT NULL
GO

UPDATE A
SET A.PLACE_OF_SERVICE_DESC = B.PLACE_OF_SERVICE_DESC
FROM PROJECT_STAGE3_INST_RA A 
	LEFT JOIN MAIL_FILE_PSCD_ID_DESC B
	ON A.PSCD_ID = B.PSCD_ID
WHERE A.PSCD_ID IS NOT NULL
GO






  /*********    ADD TO STAGE 2 TABLE    ***********/


-- FILL IN INFO FOR PROF RA CLAIMS  
UPDATE A
SET A.CLAIM_ID = CASE WHEN B.PRPR_ID IS NOT NULL THEN B.CLCL_ID
					  WHEN B.PRPR_ID IS NULL THEN B.CLAIM_ID
					  ELSE NULL END,
	A.PRPR_ID = B.PRPR_ID,
	A.GROUP_ID = B.CLCL_PAYEE_PR_ID,
	A.SERVICING_PROV_NPI_NUM = B.NPI,
	A.PLACE_OF_SERVICE_CD = B.PSCD_ID,
	A.PLACE_OF_SERVICE_DESC = B.PLACE_OF_SERVICE_DESC,
	A.RA_SOURCE = 'PROF'
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE3_PROF_RA B
	ON A.CLAIM_ID = B.CLAIM_ID
	AND A.UNQKEY = B.UNQKEY
	AND A.DX_CODE = B.DX_CODE 
	AND A.THRU_DTE = B.THRU_DTE
WHERE B.CLCL_ID IS NOT NULL
GO


-- FILL IN INFO FOR INST RA CLAIMS  
UPDATE A
SET A.CLAIM_ID = CASE WHEN B.PRPR_ID IS NOT NULL THEN B.CLCL_ID
					  WHEN B.PRPR_ID IS NULL THEN B.CLAIM_ID
					  ELSE NULL END,
	A.PRPR_ID = B.PRPR_ID,
	A.GROUP_ID = B.CLCL_PAYEE_PR_ID,
	A.SERVICING_PROV_NPI_NUM = B.NPI,
	A.PLACE_OF_SERVICE_CD = B.PSCD_ID,
	A.PLACE_OF_SERVICE_DESC = B.PLACE_OF_SERVICE_DESC,
	A.RA_SOURCE = 'INST'
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE3_INST_RA B
	ON A.CLAIM_ID = B.CLAIM_ID
	AND A.UNQKEY = B.UNQKEY
	AND A.DX_CODE = B.DX_CODE 
	AND A.THRU_DTE = B.THRU_DTE
WHERE B.CLCL_ID IS NOT NULL
AND A.RA_SOURCE IS NULL
GO

-- FILL IN NON-RA BASE CLAIMS
UPDATE A
SET A.CLAIM_ID = CASE WHEN B.PRPR_ID IS NOT NULL THEN B.CLCL_ID
					  WHEN B.PRPR_ID IS NULL THEN B.CLAIM_ID
					  ELSE NULL END,
	A.PRPR_ID = B.PRPR_ID,
	A.GROUP_ID = B.CLCL_PAYEE_PR_ID,
	A.SERVICING_PROV_NPI_NUM = B.NPI,
	A.PLACE_OF_SERVICE_CD = B.PSCD_ID,
	A.PLACE_OF_SERVICE_DESC = B.PLACE_OF_SERVICE_DESC,
	A.RA_SOURCE = 'NON-RA'
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE3 B
	ON A.CLAIM_ID = B.CLAIM_ID
	AND A.UNQKEY = B.UNQKEY
	AND A.DX_CODE = B.DX_CODE 
	AND A.THRU_DTE = B.THRU_DTE
WHERE B.CLCL_ID IS NOT NULL
AND A.RA_SOURCE IS NULL
GO




/*********************
***   19,706 rows   ***   (IN STAGE 2 TABLE) 
**********************/



-- ==================================================================================



ALTER TABLE PROJECT_STAGE2 ADD SOURCE2_CHART_ID NVARCHAR (255) GO



/*********************
-- SOURCE: SOURCE2                                              (7,345 MATCHES)
**********************/
                        
DROP TABLE PROJECT_STAGE4

SELECT DISTINCT A.ID, A.DX_CODE, A.THRU_DTE, A.PROJ_ID,
B.ProviderId, B.ReportingGroup, B.NPI, B.POS, B.ProviderType, B.ChartID
INTO PROJECT_STAGE4
FROM PROJECT_STAGE2 A 
	INNER JOIN PROJECT_SOURCE2_DATA_2014DOS B
	ON ltrim(rtrim(A.ID)) = ltrim(rtrim(B.MemberID))
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.ICD9Code))
	AND ltrim(rtrim(A.THRU_DTE)) = ltrim(rtrim(B.ServiceDate))
                 
          
          
                                                
  /*********    ADD TO STAGE 2 TABLE    ***********/     

UPDATE A                                     
SET A.PROJ_ID = 'S2_2014_01',
	A.CLAIM_ID = NULL,
	A.PRPR_ID = B.ProviderId,
	A.GROUP_ID = B.ReportingGroup,
	A.SERVICING_PROV_NPI_NUM = B.NPI,
	A.PLACE_OF_SERVICE_CD = CASE WHEN B.POS = 'OF' THEN '11' 
								 WHEN B.POS = 'HOME' THEN '12'						
								 WHEN B.POS = 'IP' THEN '21'
								 WHEN B.POS = 'OP' THEN '22'
								 WHEN B.POS = 'ER' THEN '23'
							ELSE NULL END,
	A.PLACE_OF_SERVICE_DESC = CASE WHEN B.POS = 'OF' THEN 'Office'
								   WHEN B.POS = 'HOME' THEN 'Home'								
								   WHEN B.POS = 'IP' THEN 'Inpatient Hospital'
								   WHEN B.POS = 'OP' THEN 'On Campus-Outpatient Hospital'
								   WHEN B.POS = 'ER' THEN 'Emergency Room - Hospital'
								   ELSE NULL END,
	A.RA_SOURCE = NULL,
	A.SOURCE2_CHART_ID = B.ChartID							   
FROM PROJECT_STAGE2 A 
	INNER JOIN PROJECT_STAGE4 B
	ON ltrim(rtrim(A.ID)) = ltrim(rtrim(B.ID))
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DX_CODE))
	AND ltrim(rtrim(A.THRU_DTE)) = ltrim(rtrim(B.THRU_DTE))
GO



-- ==================================================================================



/*********************
-- SOURCE: SOURCE3                                     (114 MATCHES)
**********************/

DROP TABLE PROJECT_STAGE5

SELECT DISTINCT A.UNQKEY, A.DX_CODE, A.THRU_DTE,
B.ID, B.Provider_ID, B.Group_ID, B.NPI
INTO PROJECT_STAGE5
FROM PROJECT_STAGE2 A
	INNER JOIN IHC_TABLE_MASTER_SMPL B
	ON ltrim(rtrim(A.UNQKEY)) = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
	AND ltrim(rtrim(A.DX_CODE)) = ltrim(rtrim(B.DxCode))
	AND A.THRU_DTE = B.DOS
WHERE B.Record_Type = 'Add'



  /*********    ADD TO STAGE 2 TABLE    ***********/     

UPDATE A
SET A.PRPR_ID = B.Provider_ID,
	A.GROUP_ID = B.Group_ID,
	A.SERVICING_PROV_NPI_NUM = B.NPI
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE5 B
	ON A.UNQKEY = B.UNQKEY
	AND A.DX_CODE = B.DX_CODE
	AND A.THRU_DTE = B.THRU_DTE
WHERE A.PRPR_ID IS NULL
GO


-- ==================================================================================



/*********************
-- SOURCE: SOURCE4 (LOOK IN BASE CLAIMS)                 (184 MATCHES)
**********************/

DROP TABLE PROJECT_STAGE6

SELECT DISTINCT A.UNQKEY, A.DX_CODE, A.THRU_DTE,
B.CLCL_ID, B.NPI, B.PRPR_ID, B.PSCD_ID, B.CLCL_PAYEE_PR_ID
INTO PROJECT_STAGE6
FROM PROJECT_STAGE2 A
	INNER JOIN UNLINKED_DATA_SET_BaseClaims B
	ON A.UNQKEY = B.SBSB_ID COLLATE Latin1_General_BIN
	AND A.THRU_DTE = B.DOS_High
WHERE A.PRPR_ID IS NULL




  /*********    ADD TO STAGE 2 TABLE    ***********/     

UPDATE A
SET A.CLAIM_ID = B.CLCL_ID,
	A.PRPR_ID = B.PRPR_ID,
	A.GROUP_ID = B.CLCL_PAYEE_PR_ID,
	A.SERVICING_PROV_NPI_NUM = B.NPI,
	A.PLACE_OF_SERVICE_CD = B.PSCD_ID,
	A.PLACE_OF_SERVICE_DESC = C.PLACE_OF_SERVICE_DESC
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE6 B
	ON A.UNQKEY = B.UNQKEY
	AND A.DX_CODE = B.DX_CODE
	AND A.THRU_DTE = B.THRU_DTE
		LEFT JOIN MAIL_FILE_PSCD_ID_DESC C
		ON B.PSCD_ID = C.PSCD_ID
WHERE A.PRPR_ID IS NULL
GO


-- ==================================================================================


/*********************
-- SOURCE: SOURCE5_2014_01 (S5 ASSESSMENTS)              (26 MATCHES)
**********************/

DROP TABLE PROJECT_STAGE6A

SELECT DISTINCT A.UNQKEY, A.DX_CODE, A.THRU_DTE,
B.Npi, B.NprFirstName, B.NprLastName
INTO PROJECT_STAGE6A
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_SOURCE5_DATA_2014DOS B
	ON A.UNQKEY = B.MemberID COLLATE Latin1_General_BIN
	AND A.THRU_DTE = convert(DATETIME, convert(VARCHAR(10),B.DateOfService,120))
WHERE A.PRPR_ID IS NULL





  /*********    ADD TO STAGE 2 TABLE    ***********/     

UPDATE A
SET A.PRPR_ID = 'Example',
	A.GROUP_ID = 'Example',
	A.SERVICING_PROV_NPI_NUM = B.Npi
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE6A B
	ON A.UNQKEY = B.UNQKEY
	AND A.DX_CODE = B.DX_CODE
	AND A.THRU_DTE = B.THRU_DTE
WHERE A.PRPR_ID IS NULL
GO



-- ==================================================================================


/***************************

STEP 3 -- BRING IN ALL CLAIMS

***************************/


DROP TABLE PROJECT_STAGE7

SELECT DISTINCT A.CLCL_ID, A.ID, A.SBSB_ID, A.DOS_Low, A.DOS_High, A.DX, A.NPI, A.PRPR_ID,
A.PSCD_ID, A.IPCD_ID, A.RCRC_ID, A.BILL_TYPE_CD, A.CLHP_DC_STAT, A.CLCL_PAYEE_PR_ID

INTO PROJECT_STAGE7

FROM UNLINKED_DATA_SET_BaseClaims A

WHERE A.SBSB_ID COLLATE Latin1_General_BIN IN (SELECT B.SBSB_ID FROM PROJECT_STAGE1 B) 
AND year(A.DOS_High) = '2014'


/*********************
***    10,854 rows   ***  
**********************/




-- ADDITIONAL DX CODES    

INSERT INTO PROJECT_STAGE7
SELECT DISTINCT BRIDGE.CLCL_ID, A.ID, BRIDGE.SBSB_ID, A.DOS_Low, A.DOS_High, B.DX, A.NPI, A.PRPR_ID,
BRIDGE.PSCD_ID, BRIDGE.IPCD_ID, A.RCRC_ID, A.BILL_TYPE_CD, A.CLHP_DC_STAT, A.CLCL_PAYEE_PR_ID
FROM PROJECT_STAGE7 A
INNER JOIN UNLINKED_DATA_SET_BaseClaims_Bridge BRIDGE
ON A.CLCL_ID = BRIDGE.CLCL_ID
AND A.PSCD_ID = BRIDGE.PSCD_ID
AND A.IPCD_ID = BRIDGE.IPCD_ID
INNER JOIN  UNLINKED_DATA_SET_BaseClaimsAddlDiag B
ON B.CLCL_ID = BRIDGE.CLCL_ID
AND B.CLMD_TYPE = BRIDGE.CDML_CLMD_TYPE_NORM


/*********************
***   7,495 rows   ***  
**********************/



-- ADDITIONAL DX CODES       /*****     SECOND PASS     *****/

INSERT INTO PROJECT_STAGE7
SELECT DISTINCT A.CLCL_ID, A.ID, A.SBSB_ID, A.DOS_Low, A.DOS_High, B.DX, A.NPI, A.PRPR_ID,
A.PSCD_ID, A.IPCD_ID, A.RCRC_ID, A.BILL_TYPE_CD, A.CLHP_DC_STAT, A.CLCL_PAYEE_PR_ID
FROM PROJECT_STAGE7 A
INNER JOIN  UNLINKED_DATA_SET_BaseClaimsAddlDiag B
ON A.CLCL_ID = B.CLCL_ID


/*********************
***   59,738 rows   ***    
**********************/








  /*********    ADD TO STAGE 2 TABLE    ***********/  
  
DROP TABLE PROJECT_STAGE9

SELECT DISTINCT A.SBSB_ID, A.CLCL_ID, A.DOS_Low, A.DOS_High, A.DX, A.PRPR_ID, A.CLCL_PAYEE_PR_ID, A.NPI, 
A.PSCD_ID, A.RA_SOURCE, B.HCC AS HCC_CODE, CASE WHEN B.MOD_SUB_DIV = 'V12' THEN 'V21                      '
		         WHEN B.MOD_SUB_DIV = 'V22' THEN 'V22                      '
		         ELSE B.MOD_SUB_DIV END AS MOD_SUB_DIV
INTO PROJECT_STAGE9
FROM PROJECT_STAGE8 A
	LEFT JOIN PROJECT_DX_HCC_VERTICAL B
	ON A.DX = B.DX
WHERE NOT EXISTS (
	SELECT *
	FROM PROJECT_STAGE2 B
	WHERE A.PRPR_ID = B.PRPR_ID
	AND A.SBSB_ID = B.UNQKEY COLLATE Latin1_General_BIN
	AND A.DOS_Low = B.FROM_DTE
	AND A.DOS_High = B.THRU_DTE
	AND A.DX = B.DX_CODE
	)


INSERT INTO PROJECT_STAGE9
SELECT DISTINCT A.SBSB_ID, A.CLCL_ID, A.DOS_Low, A.DOS_High, A.DX, A.PRPR_ID, A.CLCL_PAYEE_PR_ID, A.NPI, 
A.PSCD_ID, A.RA_SOURCE, E.HCC_CODE, E.MOD_SUB_DIV 
FROM PROJECT_STAGE8 A
	INNER JOIN PROJECT_STAGE2 B
	ON A.SBSB_ID = B.UNQKEY COLLATE Latin1_General_BIN
		INNER JOIN PROJECT_STAGE9 C
		ON A.SBSB_ID = C.SBSB_ID AND A.DOS_Low = C.DOS_Low AND A.DX = C.DX AND A.PRPR_ID = C.PRPR_ID 
			LEFT JOIN (SELECT * FROM MA_RSK_DX_HCC_MOD WHERE PAY_YEAR='2015') E
			ON A.DX = E.ICD9_DX_CD AND B.RSK_MOD = E.RSK_MODEL



INSERT INTO PROJECT_STAGE2 (
UNQKEY,
CLAIM_ID,
FROM_DTE,
THRU_DTE,
DX_CODE,
HCC_CODE,
MOD_SUB_DIV,
PRPR_ID,
GROUP_ID,
SERVICING_PROV_NPI_NUM,
PLACE_OF_SERVICE_CD,
RA_SOURCE)
SELECT DISTINCT A.SBSB_ID, A.CLCL_ID, A.DOS_Low, A.DOS_High, A.DX, A.HCC_CODE, A.MOD_SUB_DIV, A.PRPR_ID, A.CLCL_PAYEE_PR_ID, A.NPI, A.PSCD_ID, A.RA_SOURCE
FROM PROJECT_STAGE9 A 

-- 4,968 ROWS ADDED


UPDATE A
SET A.ID = B.ID,
	A.PROJ_ID = 'BASE_CLAIMS',
	A.PLACE_OF_SERVICE_DESC = C.PLACE_OF_SERVICE_DESC
FROM PROJECT_STAGE2 A
	LEFT JOIN PROJECT_STAGE1 B
	ON A.UNQKEY = B.SBSB_ID
		LEFT JOIN MAIL_FILE_PSCD_ID_DESC C
		ON A.PLACE_OF_SERVICE_CD = C.PSCD_ID
WHERE A.ID IS NULL	
GO
	

UPDATE A
SET A.RSK_MOD = B.RSK_MOD
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE2 B ON A.UNQKEY = B.UNQKEY
WHERE A.RSK_MOD IS NULL
GO


/*********************
***   25,565 rows   ***   (IN STAGE 2 TABLE) 
**********************/





-- EXCLUDE ANY NON-RA CLAIMS    (10,897 rows)
DROP TABLE PROJECT_STAGE2_NON_RA
SELECT *
INTO PROJECT_STAGE2_NON_RA
FROM PROJECT_STAGE2 A
WHERE A.RA_SOURCE = 'NON-RA'

DELETE A
FROM PROJECT_STAGE2 A
WHERE A.RA_SOURCE = 'NON-RA'
GO

INSERT INTO PROJECT_STAGE2_NON_RA 
SELECT DISTINCT A.ID, A.SBSB_ID, 'BASE_CLAIMS', NULL, A.CLCL_ID, NULL, A.DOS_Low, A.DOS_High,
A.DX, NULL, NULL, NULL, A.PRPR_ID, A.CLCL_PAYEE_PR_ID, A.NPI, A.PSCD_ID, NULL, 'NON-RA', NULL
FROM PROJECT_STAGE7 A
WHERE NOT EXISTS (
	SELECT * FROM PROJECT_STAGE8 C
	WHERE A.CLCL_ID = C.CLCL_ID
	)



/** ADD NON-RA CLAIMS THAT MAP TO SMPL DX **/ 
INSERT INTO PROJECT_STAGE2 
SELECT DISTINCT A.ID, A.UNQKEY, A.PROJ_ID, A.RSK_MOD, A.CLAIM_ID, A.PROV_TYPE, A.FROM_DTE, A.THRU_DTE, A.DX_CODE, C.HCC,
CASE WHEN C.MOD_SUB_DIV = 'V12' THEN 'V21                      '
		         WHEN C.MOD_SUB_DIV = 'V22' THEN 'V22                      '
		         ELSE C.MOD_SUB_DIV END AS MOD_SUB_DIV,
A.HCC_DESCRIPTION, A.PRPR_ID, A.GROUP_ID, A.SERVICING_PROV_NPI_NUM, A.PLACE_OF_SERVICE_CD, A.PLACE_OF_SERVICE_DESC, A.RA_SOURCE, A.SOURCE2_CHART_ID
FROM PROJECT_STAGE2_NON_RA A
	INNER JOIN PROJECT_ENROLLEE B
	ON A.UNQKEY = B.UNQKEY COLLATE Latin1_General_BIN
		INNER JOIN PROJECT_DX_HCC_VERTICAL C
		ON B.SMPL_ENROLLEE_ID = C.SMPL_ENROLLEE_ID
		AND A.DX_CODE = C.DX


/*********************
***   28,529 rows   ***   (IN STAGE 2 TABLE) 
**********************/



UPDATE A
SET A.RSK_MOD = B.RSK_MOD
FROM PROJECT_STAGE2 A
	INNER JOIN PROJECT_STAGE2 B ON A.UNQKEY = B.UNQKEY
WHERE A.RSK_MOD IS NULL
GO

UPDATE A
SET A.HCC_DESCRIPTION = B.Disease
FROM PROJECT_STAGE2 A
	INNER JOIN MA_RSK_MOD_COEF_FACT B
	ON concat(ltrim(rtrim(A.RSK_MOD)),'-',A.HCC_CODE) = B.COEF_ID
	AND A.MOD_SUB_DIV = B.MOD_SUB_DIV
WHERE B.PAY_YEAR = 2015
GO


-- ==================================================================================================================



ALTER TABLE PROJECT_STAGE2 ADD PRPR_MCTR_TYPE NVARCHAR (255) GO 
ALTER TABLE PROJECT_STAGE2 ADD PRPR_MCTR_TYPE_DESC NVARCHAR (255) GO 
ALTER TABLE PROJECT_STAGE2 ADD PRCF_MCTR_SPEC NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRCF_MCTR_SPEC_DESC NVARCHAR (255) GO 
ALTER TABLE PROJECT_STAGE2 ADD PRPR_NAME NVARCHAR (255) GO 
ALTER TABLE PROJECT_STAGE2 ADD GROUP_NAME NVARCHAR (255) GO 
ALTER TABLE PROJECT_STAGE2 ADD PRAD_ADDR1 NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRAD_ADDR2 NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRAD_CITY NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRAD_STATE NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRAD_ZIP NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRAD_PHONE NVARCHAR (255) GO
ALTER TABLE PROJECT_STAGE2 ADD PRAD_FAX NVARCHAR (255) GO 




/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////
/****	                                               					   	 ****/  
/****	                                               						 ****/ 
/****	                       LOOOOOK  HEREEEEEEEE!!!                       ****/  
/****	                                             						 ****/ 
/****	                          END OF PART 1                              ****/ 
/****	                                                                     ****/                            
/****	            RUN  ***PT2***   SCRIPT NEXT !!!!!!!!!!!!!               ****/
/****	                                                                     ****/ 
/****	                                               						 ****/ 
/****	                                                                     ****/ 
/****	                                                                     ****/ 
/****	                                                                     ****/ 
/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////
/////************************************************************************/////

