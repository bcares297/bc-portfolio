
# This was a process I created in order to automate the load of multiple Excel data files into our SQL SERVER environmnent.

# Each Excel file had two sets of data ("Type 1" and "Type 2" - they were on separate sheets). 
# I would consolidate all the Type 1's from all Excel files, and batch load them to a table created in SQL environment. (Repeat process for Type 2's)




import glob
import os
import win32com.client
import shutil


os.chdir('C:\Brian\Extracts (LOADING)')           ## Set current directory of Extract Files

xlsx_files = glob.glob('*.xlsx')        ## Get all xlsx files



###################################################################################
###################################################################################
'''                        CHANGE DATES OF FILE NAMES                           '''
'''                      DO FIND & REPLACE W/ ULTRAEDIT                         '''


newpath1 = 'C:\Brian\Extracts (LOADING)\Example_Extract_Type1'  
newpath2 = 'C:\Brian\Extracts (LOADING)\Example_Extract_Type2'                           

Type1sOutF = 'Consolidated_Type1_Data.csv'
Type2sOutF = 'Consolidated_Type2_Data.csv'

Type1sOutFPath = 'C:\Brian\Extracts (LOADING)\Example_201904_CSV_CRA_Type1s\Consolidated_Type1_Data.csv'
Type2sOutFPath = 'C:\Brian\Extracts (LOADING)\Example_201904_CSV_CRA_Type2s\Consolidated_Type2_Data.csv'


'''                        CHECK DATES IN SQL SCRIPTS                          '''
###################################################################################
###################################################################################




excel = win32com.client.Dispatch('Excel.Application')  ## Call Excel application
excel.Visible = True

wsh = win32com.client.Dispatch("WScript.Shell")


## 'Type1s' (1st Sheet)
for file in xlsx_files:
    xlWb = excel.Workbooks.Open(os.path.join(os.getcwd(), file))
    xlWb.Worksheets(1).Activate()
    wsh.AppActivate("Microsoft Excel")
    wsh.SendKeys("^(a)")
    wsh.SendKeys("^(c)")
    xlWb.Worksheets.Add()
    wsh.SendKeys("^(v)")
    xlWb.Worksheets(1).copy
    excel.ActiveWorkbook.SaveAs(os.path.join(os.getcwd(), file.split('.xlsx')[0] +'Type1'+'.csv'), FileFormat=6) ##  '6' is CSV
    excel.ActiveWorkbook.Close(False)
    xlWb.Close(False)
    

## 'Type2s' (2nd Sheet)
for file in xlsx_files:
    xlWb = excel.Workbooks.Open(os.path.join(os.getcwd(), file))
    try: 
        xlWb.Worksheets(2).Activate()
        wsh.AppActivate("Microsoft Excel")
        wsh.SendKeys("^(a)")
        wsh.SendKeys("^(c)")
        xlWb.Worksheets.Add()
        wsh.SendKeys("^(v)")
        xlWb.Worksheets(2).copy
        excel.ActiveWorkbook.SaveAs(os.path.join(os.getcwd(), file.split('.xlsx')[0] +'Type2'+'.csv'), FileFormat=6) ##  '6' is CSV
        excel.ActiveWorkbook.Close(False)
        xlWb.Close(False)
    except: 
        xlWb.Close(False)

excel.Quit() 





## Create Folders
if not os.path.exists(newpath1):
    os.makedirs(newpath1)

if not os.path.exists(newpath2):
    os.makedirs(newpath2)

csv_Typ1s = glob.glob('*Type1.csv')
csv_Typ2s= glob.glob('*Type2.csv')


## Sort Files into Folders
for file in csv_Typ1s: 
    shutil.move(file,newpath1)

for file in csv_Typ2s: 
    shutil.move(file,newpath2)






## Merge CSV files   
os.chdir(newpath1)  
merged_csv = glob.glob("*.csv") 

with open(Type1sOutF, 'wb') as outfile:                             
    for i, fname in enumerate(merged_csv):
        with open(fname, 'rb') as infile:
            if i != 0:
                infile.readline()  # Throw away header on all but first file
            shutil.copyfileobj(infile, outfile) 
            print(fname + " has been imported.")


os.chdir(newpath2)  
merged_csv = glob.glob("*.csv") 

with open(Type2sOutF, 'wb') as outfile:                          
    for i, fname in enumerate(merged_csv):
        with open(fname, 'rb') as infile:
            if i != 0:
                infile.readline()  # Throw away header on all but first file
            shutil.copyfileobj(infile, outfile) 
            print(fname + " has been imported.")






###############################################################################################################################################



import pandas as pd
import numpy as np


from turbodbc import connect


## Connect to SQL 
cnxn = connect(Driver="SQL Server Native Client 11.0",
               Server="SQLBC_TEST\\SQL_BCTEST",
               Database="BC_Example",
               Trusted_Connection="yes")

cursor = cnxn.cursor()





#####################
##### TYPE 1's ######
#####################


## Load Example extract      ######  (CHANGE EXTRACT)  ######
Example_extract_Typ1 = pd.read_table(Type1sOutFPath, sep=',', dtype='U255', engine='python', na_filter=False)



Example_matrix_Typ1 = [Example_extract_Typ1[col].values for col in Example_extract_Typ1.columns]
print('Data Frame is now Matrix')




## Set up Insert Queries
query1 = '''
CREATE TABLE Example_201904_CSV_Typ1s_CRA (
    [File Name] nvarchar(255),
    [Reviewed By] nvarchar(255),
    [Audited By] nvarchar(255),
    [Completed On] nvarchar(255),
    [Claim ID] nvarchar(255),
    [Member ID] nvarchar(255),
    [Member Name Last] nvarchar(255),
    [Member Name First] nvarchar(255),
    DOB nvarchar(255),
    Age nvarchar(255),
    Gender nvarchar(255),
    [Visit Type] nvarchar(255),
    [From DOS] nvarchar(255),
    [To DOS] nvarchar(255),
    [Provider ID] nvarchar(255),
    [Provider Name Last] nvarchar(255),
    [Provider Name First] nvarchar(255),
    [Comment Note] nvarchar(255),
    [DOS Comment] nvarchar(255),
    Diag nvarchar(255),
    HccValue nvarchar(255),
    [Page No] nvarchar(255),
    [Diag Comment] nvarchar(255),
    [EDS Results] nvarchar(255),
    [Is Validated By Coder] nvarchar(255)
    )

'''

query2 = '''
INSERT INTO Example_201904_CSV_Typ1s_CRA (
    [File Name],
    [Reviewed By],
    [Audited By],
    [Completed On],
    [Claim ID],
    [Member ID],
    [Member Name Last],
    [Member Name First],
    DOB,
    Age,
    Gender,
    [Visit Type],
    [From DOS],
    [To DOS],
    [Provider ID],
    [Provider Name Last],
    [Provider Name First],
    [Comment Note],
    [DOS Comment],
    Diag,
    HccValue,
    [Page No],
    [Diag Comment],
    [EDS Results],
    [Is Validated By Coder]
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)

'''


## Execute Create Table
try:
    cursor.execute(query1)
    cnxn.commit()
except:
    pass



## Grab existing row count in the database for validation later
cursor.execute('SELECT count(*) FROM Example_201904_CSV_Typ1s_CRA')
before_import = cursor.fetchone()


## Execute sql Query
cursor.executemanycolumns(query2, Example_matrix_Typ1)

## Commit the transaction
cnxn.commit()




## If you want to check if all rows are imported
cursor.execute('SELECT count(*) FROM Example_201904_CSV_Typ1s_CRA')
result = cursor.fetchone()

print((result[0] - before_import[0]) == len(Example_extract_Typ1.index))  # should be True







#####################
##### TYPE 2's ######
#####################


## Load Example extract      ######  (CHANGE EXTRACT)  ######
Example_extract_Typ2 = pd.read_table(Type2sOutFPath, sep=',', dtype='U255', engine='python', na_filter=False)



Example_matrix_Typ2 = [Example_extract_Typ2[col].values for col in Example_extract_Typ2.columns]
print('Data Frame is now Matrix')




## Set up Insert Queries
query1 = '''
CREATE TABLE Example_201904_CSV_Typ2_CRA (
    [File Name] nvarchar(255),
    [Reviewed By] nvarchar(255),
    [Audited By] nvarchar(255),
    [Completed On] nvarchar(255),
    [Claim ID] nvarchar(255),
    [Member ID] nvarchar(255),
    [Member Name Last] nvarchar(255),
    [Member Name First] nvarchar(255),
    DOB nvarchar(255),
    Age nvarchar(255),
    Gender nvarchar(255),
    [Visit Type] nvarchar(255),
    [From DOS] nvarchar(255),
    [To DOS] nvarchar(255),
    [Provider ID] nvarchar(255),
    [Provider Name Last] nvarchar(255),
    [Provider Name First] nvarchar(255),
    [Comment Note] nvarchar(255),
    [DOS Comment] nvarchar(255),
    Diag nvarchar(255),
    HccValue nvarchar(255),
    [Diag Comment] nvarchar(255),
    [EDS Results] nvarchar(255),
    [Is Validated By Coder] nvarchar(255)
    )

'''

query2 = '''
INSERT INTO Example_201904_CSV_Typ2_CRA (
    [File Name],
    [Reviewed By],
    [Audited By],
    [Completed On],
    [Claim ID],
    [Member ID],
    [Member Name Last],
    [Member Name First],
    DOB,
    Age,
    Gender,
    [Visit Type],
    [From DOS],
    [To DOS],
    [Provider ID],
    [Provider Name Last],
    [Provider Name First],
    [Comment Note],
    [DOS Comment],
    Diag,
    HccValue,
    [Diag Comment],
    [EDS Results],
    [Is Validated By Coder]
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)

'''


## Execute Create Table
try:
    cursor.execute(query1)
    cnxn.commit()
except:
    pass



## Grab existing row count in the database for validation later
cursor.execute('SELECT count(*) FROM Example_201904_CSV_Typ2_CRA')
before_import = cursor.fetchone()



## Execute sql Query
cursor.executemanycolumns(query2, Example_matrix_Typ2)

## Commit the transaction
cnxn.commit()



## If you want to check if all rows are imported
cursor.execute('SELECT count(*) FROM Example_201904_CSV_Typ2_CRA')
result = cursor.fetchone()

print((result[0] - before_import[0]) == len(Example_extract_Typ2.index))  # should be True

## Close the database connection
cnxn.close()