
## Automated running 1000 samples of data through an analysis (Monte Carlo Simulation)



###################################################################################
##                       MONTE CARLO RUNS FOR MODELER                            ##
###################################################################################




## Get .sql file into readable string format

file_path = 'C:\Brian\MONTE_CARLO_MODELER.sql'

f = open(file_path, 'r')
query2 = " ".join(f.readlines())




## Connect to SQL 
from turbodbc import connect

cnxn = connect(Driver="SQL Server Native Client 11.0",
            Server="SQLBC_TEST\\SQL_BCTEST",
            Database="BC_Example",
            Trusted_Connection="Yes")

cursor = cnxn.cursor()




for i in range(2,11):
    for j in range(1,101):
        query1 = f'''
        TRUNCATE TABLE MSTR_TBL_MONTE_CARLO

        INSERT INTO MSTR_TBL_MONTE_CARLO
        SELECT * FROM MSTR_TBL_PRE_MONTE_CARLO

        INSERT INTO MSTR_TBL_MONTE_CARLO
        SELECT FILE_TYPE, FILE_ID, TRANSACTION_DATE, PROD_TEST_IND, PLAN_NO, SEQ_NO, SEQ_ERROR_CODE,
        PATIENT_CONTROL_NO, HIC_NO, HIC_ERROR_CODE, PATIENT_DOB, DOB_ERROR_CODE, DIAG_CLSTR, PROV_TYPE, FROM_DTE, THRU_DTE, DELETE_IND,
        DIAG_CODE, DC_FILLER, DIAG_CLSTR_ERROR_1, DIAG_CLSTR_ERROR_2, CORRECTED_HICN_NO, PKEY, RISK_ASSESS_CD, RISK_ASSESS_ERROR
        FROM MONTE_CARLO_LIST_OF_CODES_FULL
        WHERE BUCKET = {i} AND RUN <= {j}
        '''

        ## Execute Parameterized Query
        try:
            cursor.execute(query1)
            cnxn.commit()
        except Exception:
            print('Something went wrong...')


        ## Call second SQL Script
        try:
            cursor.execute(query2)
            cnxn.commit()
        except Exception:
            print('Something went wrong...')


        ## Execute Final Paramaterized Query
        query3 = f'''
        UPDATE A
        SET A.RISK_SUM = A.MONTH*A.RAF_NRM
        FROM Mem_RAF_AGG_FINAL A

        UPDATE Mem_RAF_AGG_FINAL
        SET TMP_3 = {i}, TMP_4 = {j}

        INSERT INTO Mem_RAF_AGG_FINAL_MONTE_CARLO
        SELECT * FROM Mem_RAF_AGG_FINAL
        '''

        try:
            cursor.execute(query3)
            cnxn.commit()
        except Exception:
            print('Something went wrong...')