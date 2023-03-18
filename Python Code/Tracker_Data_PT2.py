
import os
import sys
import glob
import win32com.client


os.chdir("C:\\Brian\\Member Tracker Files\\Chart Status")   ## Set current directory of Extract Files

xlsx_files = glob.glob('*.xlsx')        ## Get all xlsx files

######################################################################################################################


excel = win32com.client.Dispatch('Excel.Application')  ## Call Excel application
excel.Visible = True
excel.DisplayAlerts = False


for file in xlsx_files:
    xlWb1 = excel.Workbooks.Open(os.path.join(os.getcwd(), file))
    xlWb1.Worksheets.Add(Before = xlWb1.Worksheets(1), After = None)


    ## Set up first page
    xlWs1 = xlWb1.Worksheets(1)
    xlWs1.Name = "Chart Level HCC"


    xlWb1.Worksheets(2).Range("A1:P1").Copy()    ## Copy headers
    xlWb1.Worksheets(2).Paste(xlWs1.Range("A1"))   


    sheet_count = xlWb1.Worksheets.Count
   

    for i in range(2, sheet_count + 1):

        sheet2 = xlWb1.Worksheets(i)
        sheet_final = xlWb1.Worksheets(1)

        last_row = sheet2.UsedRange.Rows.Count
        
        sheet2.Range("A2:P" +str(last_row)).Copy()

        if i == 2:
            sheet2.Paste(sheet_final.Cells(2,1))
        else:
            last_row_final = sheet_final.UsedRange.Rows.Count
            sheet2.Paste(sheet_final.Cells(last_row_final + 1, 1))


        ## Change columns to Text
        sheet2.Range("A:P").NumberFormat = "@" 

        
    ## Save and close file
    xlWb1.Save()
    xlWb1.Close(False)

excel.Application.Quit()   