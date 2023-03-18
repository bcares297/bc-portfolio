
-- =====================================================================
    /*     Reconciliation Reporting (Claims vs. PDR)    */ 

-- Author: Brian Caresosa
-- Create Date: 12/12/2018
-- Description: Reconcile what comes in through Claims vs Report
-- =====================================================================



-- SET MONTH/YEAR OF REPORT DATE (ONE-MONTH LAG)

DECLARE @REPORT_DATE DATETIME 

SET @REPORT_DATE = '20211231' 




/********************************

BASE CLAIMS - FIND PROCEDURE CODES  

******************************/



--SOURCE AWV

SELECT DISTINCT A.CLAIM_ID, A.SUBSCRIBER_ID, B.MEMBER_IDNO, B.MEMBER_FIRST_NM, B.MEMBER_LAST_NM, A.SERVICING_PROV_NM, A.SERVICING_PROV_ID, A.SERVICING_PROV_NPI_NUM, 
concat(A.PROCEDURE_CODE,A.MODIFIER) AS 'CPT', CAST(A.SERVICE_DT AS DATE) AS 'SERVICE_DT', A.CMP_IND, A.PAID_AMT, A.GROUP_NAME, A.SERVICING_PROV_TAX_ID,
concat(upper(ltrim(rtrim(B.MEMBER_FIRST_NM))),upper(ltrim(rtrim(B.MEMBER_LAST_NM)))) AS 'FirstLast',
CASE WHEN LEFT(B.PLAN_PACKAGE_ID,2) IN ('01','3E') THEN 'WNY' 
	 WHEN LEFT(B.PLAN_PACKAGE_ID,2) IN ('A1','DX') THEN 'NENY' 
	 ELSE 'WNY' END AS REGION

INTO SOURCE_MonthlyRecon_Stage

FROM AWV_CLAIM_EXTRACT_2021 A   -- 2021 Claims
LEFT JOIN MA_RSK_ELIGIBILITY B  -- Current-Year Eligibilty 
ON ltrim(rtrim(A.SUBSCRIBER_ID)) = ltrim(rtrim(B.SUBSCRIBER_ID))

WHERE ((PROCEDURE_CODE LIKE 'G04%' AND MODIFIER='CG')
OR (PROCEDURE_CODE LIKE '993%' AND MODIFIER='CC'))
/* WHERE ((PROCEDURE_CODE IN ('G0402','G0438','G0439') AND MODIFIER='CG')
OR (PROCEDURE_CODE IN ('99385','99386','99387','99395','99396','99397') AND MODIFIER='CC'))*/

AND A.SERVICE_DT <= @REPORT_DATE --Change to most recent PDR visit date
AND A.SERVICE_DT >= '20210101'






--SOURCE IHA

INSERT INTO SOURCE_MonthlyRecon_Stage
SELECT DISTINCT A.CLAIM_ID, A.SUBSCRIBER_ID, B.MEMBER_IDNO, B.MEMBER_FIRST_NM, B.MEMBER_LAST_NM, A.SERVICING_PROV_NM, A.SERVICING_PROV_ID, A.SERVICING_PROV_NPI_NUM, 
concat(A.PROCEDURE_CODE,A.MODIFIER) AS 'CPT', CAST(A.SERVICE_DT AS DATE) AS 'SERVICE_DT', A.CMP_IND, A.PAID_AMT, A.GROUP_NAME, A.SERVICING_PROV_TAX_ID,
concat(upper(ltrim(rtrim(B.MEMBER_FIRST_NM))),upper(ltrim(rtrim(B.MEMBER_LAST_NM)))) AS 'FirstLast', 
CASE WHEN LEFT(B.PLAN_PACKAGE_ID,2) IN ('01','3E') THEN 'WNY' 
	 WHEN LEFT(B.PLAN_PACKAGE_ID,2) IN ('A1','DX') THEN 'NENY' 
	 ELSE 'WNY' END AS REGION
	 
FROM AWV_CLAIM_EXTRACT_2021 A   --2021 Claims
LEFT JOIN MA_RSK_ELIGIBILITY B -- Current-Year Eligibility  
ON ltrim(rtrim(A.SUBSCRIBER_ID)) = ltrim(rtrim(B.SUBSCRIBER_ID))

WHERE (PROCEDURE_CODE IN ('99345','99350') AND MODIFIER='CG')

AND A.SERVICE_DT <= @REPORT_DATE --Change to most recent PDR visit date
AND A.SERVICE_DT >= '20210101'










/***************************

BRING IN REPORT

***************************/
   

SELECT DISTINCT *, 
concat(upper(ltrim(rtrim(A.FirstName))),upper(ltrim(rtrim(A.LastName)))) AS 'FirstLast'
INTO SOURCE_MonthlyRecon_Stage_2
FROM SOURCE_PDR_MASTER A
WHERE year(VisitDate) = year(@REPORT_DATE)




-- ===============================================================================================================



-- !!  REVERT NEWIDs to IDNOs for consistency (Change logic once everything is NEWID)  !!

-- Table had two versions (NEWIDs and IDNOs), the PATINDEX function allowed me to distinguish between the two so I could match using appropriate IDs
-- Running logic on both Claims and Report



/**************************************          CLAIMS          *********************************************/


-- FIND MEMBERS WHO HAVE IDNO INSTEAD OF NEWID AND REPLACE
UPDATE A 
SET A.MEMBER_IDNO = B.NEWID 
FROM SOURCE_MonthlyRecon_Stage A 
INNER JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].IDNO_NEWID_XWALK B
ON ltrim(rtrim(A.MEMBER_IDNO)) COLLATE Latin1_General_BIN = ltrim(rtrim(B.NEWID)) COLLATE Latin1_General_BIN
WHERE PATINDEX('%[a-zA-Z]%',substring(A.MEMBER_IDNO,5,1)) = 0


-- CREATE CW FOR SBSB TO NEWID TO IDNO (LEFTOVERS IN HND_IC)
SELECT DISTINCT A.SUBSCRIBER_ID, C.NEWID
INTO NEWID_SBSB_IDNO_MATCHBACK
FROM SOURCE_MonthlyRecon_Stage A 
LEFT JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].HND_IC B
ON ltrim(rtrim(A.SUBSCRIBER_ID)) COLLATE Latin1_General_BIN = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
LEFT JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].IDNO_NEWID_XWALK C
ON ltrim(rtrim(B.MEME_IDNO)) = ltrim(rtrim(C.IDNO))
WHERE A.MEMBER_IDNO IS NULL
AND PATINDEX('%[a-zA-Z]%',substring(B.MEME_IDNO,5,1)) = 0


-- UPDATE BASED ON HND_IC CW
UPDATE A
SET A.MEMBER_IDNO = B.NEWID
FROM SOURCE_MonthlyRecon_Stage A 
INNER JOIN NEWID_SBSB_IDNO_MATCHBACK B
ON ltrim(rtrim(A.SUBSCRIBER_ID)) = ltrim(rtrim(B.SUBSCRIBER_ID))
WHERE A.MEMBER_IDNO IS NULL
AND B.NEWID IS NOT NULL


-- SECOND HND_IC CW 
DROP TABLE NEWID_SBSB_IDNO_MATCHBACK
SELECT DISTINCT A.SUBSCRIBER_ID, B.MEME_IDNO
INTO NEWID_SBSB_IDNO_MATCHBACK
FROM SOURCE_MonthlyRecon_Stage A
LEFT JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].HND_IC B
ON ltrim(rtrim(A.SUBSCRIBER_ID)) COLLATE Latin1_General_BIN= ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
WHERE A.MEMBER_IDNO IS NULL
AND PATINDEX('%[a-zA-Z]%',substring(B.MEME_IDNO,5,1)) != 0


-- UPDATE BASED ON SECOND HND_IC CW
UPDATE A
SET A.MEMBER_IDNO = B.MEME_IDNO
FROM SOURCE_MonthlyRecon_Stage A 
INNER JOIN NEWID_SBSB_IDNO_MATCHBACK B
ON ltrim(rtrim(A.SUBSCRIBER_ID)) = ltrim(rtrim(B.SUBSCRIBER_ID))
WHERE A.MEMBER_IDNO IS NULL
AND B.MEME_IDNO IS NOT NULL


-- ADD BACK NEWID IF IDNO NOT FOUND
UPDATE A
SET A.MEMBER_IDNO = B.MEME_IDNO
FROM SOURCE_MonthlyRecon_Stage A 
INNER JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].HND_IC B
ON ltrim(rtrim(A.SUBSCRIBER_ID)) COLLATE Latin1_General_BIN = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
WHERE A.MEMBER_IDNO IS NULL



DROP TABLE NEWID_SBSB_IDNO_MATCHBACK



/**************************************          PDR          *********************************************/


-- FIND MEMBERS WHO HAVE IDNO INSTEAD OF NEWID AND REPLACE
UPDATE A 
SET A.IDNO = B.NEWID 
FROM SOURCE_MonthlyRecon_Stage_2 A 
INNER JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].IDNO_NEWID_XWALK B
ON ltrim(rtrim(A.IDNO)) COLLATE Latin1_General_BIN = ltrim(rtrim(B.NEWID)) COLLATE Latin1_General_BIN
WHERE PATINDEX('%[a-zA-Z]%',substring(A.IDNO,5,1)) = 0


-- CREATE CW FOR SBSB TO NEWID TO IDNO (LEFTOVERS IN HND_IC)
SELECT DISTINCT A.MemberId, C.NEWID
INTO NEWID_SBSB_IDNO_MATCHBACK
FROM SOURCE_MonthlyRecon_Stage_2 A 
LEFT JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].HND_IC B
ON ltrim(rtrim(LEFT(A.MemberId,9))) COLLATE Latin1_General_BIN = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
LEFT JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].IDNO_NEWID_XWALK C
ON ltrim(rtrim(B.MEME_IDNO)) = ltrim(rtrim(C.IDNO))
WHERE A.IDNO IS NULL
AND PATINDEX('%[a-zA-Z]%',substring(B.MEME_IDNO,5,1)) = 0


-- UPDATE BASED ON HND_IC CW
UPDATE A
SET A.IDNO = B.NEWID
FROM SOURCE_MonthlyRecon_Stage_2 A 
INNER JOIN NEWID_SBSB_IDNO_MATCHBACK B
ON ltrim(rtrim(LEFT(A.MemberId,9))) = ltrim(rtrim(LEFT(B.MemberId,9)))
WHERE A.IDNO IS NULL
AND B.NEWID IS NOT NULL


-- SECOND HND_IC CW 
DROP TABLE NEWID_SBSB_IDNO_MATCHBACK
SELECT DISTINCT A.MemberId, B.MEME_IDNO
INTO NEWID_SBSB_IDNO_MATCHBACK
FROM SOURCE_MonthlyRecon_Stage_2 A
LEFT JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].HND_IC B
ON ltrim(rtrim(LEFT(A.MemberId,9))) COLLATE Latin1_General_BIN = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
WHERE (A.IDNO IS NULL OR A.IDNO = '')
AND PATINDEX('%[a-zA-Z]%',substring(B.MEME_IDNO,5,1)) != 0



-- UPDATE BASED ON SECOND HND_IC CW
UPDATE A
SET A.IDNO = B.MEME_IDNO
FROM SOURCE_MonthlyRecon_Stage_2 A 
INNER JOIN NEWID_SBSB_IDNO_MATCHBACK B
ON ltrim(rtrim(LEFT(A.MemberId,9))) = ltrim(rtrim(LEFT(B.MemberId,9)))
WHERE A.IDNO IS NULL
AND B.MEME_IDNO IS NOT NULL


-- ADD BACK NEWID IF IDNO NOT FOUND
UPDATE A
SET A.IDNO = B.MEME_IDNO
FROM SOURCE_MonthlyRecon_Stage_2 A 
INNER JOIN [SQLBCTEST\SQL_BCTEST].[ExTest_prod].[dbo].HND_IC B
ON ltrim(rtrim(LEFT(A.MemberId,9))) COLLATE Latin1_General_BIN = ltrim(rtrim(B.SBSB_ID)) COLLATE Latin1_General_BIN
WHERE A.IDNO IS NULL



DROP TABLE NEWID_SBSB_IDNO_MATCHBACK

-- ====================================================================================================================




SELECT A.*, 
CASE WHEN EXISTS
(SELECT B.IDNO FROM SOURCE_MonthlyRecon_Stage_2 B WHERE ltrim(rtrim(A.MEMBER_IDNO))=ltrim(rtrim(B.IDNO)))
THEN 'Y' ELSE 'N' END AS 'In_PDR',
CASE WHEN EXISTS
(SELECT B.VisitDate FROM SOURCE_MonthlyRecon_Stage_2 B WHERE A.SERVICE_DT = B.VisitDate
AND ltrim(rtrim(A.MEMBER_IDNO))=ltrim(rtrim(B.IDNO)))
THEN 'Y' ELSE 'N' END AS 'DOS_Match_PDR',
CASE WHEN EXISTS 
(SELECT B.FirstLast FROM SOURCE_MonthlyRecon_Stage_2 B WHERE ltrim(rtrim(A.FirstLast)) = ltrim(rtrim(B.FirstLast)))
THEN 'Y' ELSE 'N' END AS 'SecondaryMatch'
FROM SOURCE_MonthlyRecon_Stage A




SELECT B.*, 
CASE WHEN EXISTS
(SELECT A.MEMBER_IDNO FROM SOURCE_MonthlyRecon_Stage A WHERE ltrim(rtrim(A.MEMBER_IDNO))=ltrim(rtrim(B.IDNO)))
THEN 'Y' ELSE 'N' END AS 'In_Claims',
CASE WHEN EXISTS
(SELECT A.SERVICE_DT FROM SOURCE_MonthlyRecon_Stage A WHERE A.SERVICE_DT = B.VisitDate
AND ltrim(rtrim(A.MEMBER_IDNO))=ltrim(rtrim(B.IDNO)))
THEN 'Y' ELSE 'N' END AS 'DOS_Match_Claims',
CASE WHEN EXISTS
(SELECT A.FirstLast FROM SOURCE_MonthlyRecon_Stage A WHERE ltrim(rtrim(A.FirstLast)) = ltrim(rtrim(B.FirstLast)))
THEN 'Y' ELSE 'N' END AS 'SecondaryMatch'
FROM SOURCE_MonthlyRecon_Stage_2 B




DROP TABLE SOURCE_MonthlyRecon_Stage
DROP TABLE SOURCE_MonthlyRecon_Stage_2