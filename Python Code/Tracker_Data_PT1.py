
# Process to pull data from generated Tracker files (See 'VBA Code' subfolder)



import os
import sys
import glob
import win32com.client


os.chdir("C:\\Brian\\Tracker Files")   ## Set current directory of Extract Files

drop_zone = "C:\\Brian\\Tracker Files\\Chart Status"   ## Drop zone

######################################################################################################################


excel = win32com.client.Dispatch('Excel.Application')  ## Call Excel application
excel.Visible = True


## New workbook where you will paste the data from the Mem Tracker file
xlWb2 = excel.Workbooks.Add() 


## Open the Mem Tracker
file = "Mem Test - (Output).xlsx"
xlWb1 = excel.Workbooks.Open(os.path.join(os.getcwd(), file))


## Count how many sheets in Mem Tracker
sheet_count_1 = xlWb1.Worksheets.Count


## New Workbook should start with only one sheet
sheet_count_2 = xlWb2.Worksheets.Count
while sheet_count_2 != 1:
    xlWb2.Worksheets(1).Delete()
    sheet_count_2 = xlWb2.Worksheets.Count
    if sheet_count_2 == 1:
        break


###################################################################################################


## Enrollee tabs [Don't count non-enrollee tabs - If there are 4 tabs before enrollee tabs, then set range to 3]
for i in range(1, sheet_count_1 - 3):

    if i == 1:
        pass
    else:
        xlWb2.Worksheets.Add(Before = None , After = xlWb2.Worksheets(xlWb2.Worksheets.Count))   ## Add new sheet


    ## Set sheets
    xlWs2 = xlWb2.Worksheets(i)

    j = i + 4     ## [Need to skip over any non-Enrolle Tabs like Mem Directory, Dropdowns, etc.]
    xlWs1 = xlWb1.Worksheets(j)


    ## Take corresponding Name from Mem Tracker
    xlWs2.Name = xlWs1.Name



    ## Copy data over
    xlWs1.Range("M:AB").Copy()
    xlWs2.Range("A1").PasteSpecial(Paste=-4163)  ## xlPasteValues


    ## Remove blank rows [Increase range if enrollee tabs rows exceed set amount]
    for a in range(1, 201):
        if xlWs2.Cells(a, 1).Value is None:
            xlWs2.Cells(a, 1).Value = "D"
    

    for b in range(1, 201):
        if xlWs2.Cells(201 - b, 1).Value == "D":
            xlWs2.Rows(201 - b).EntireRow.Delete()



## Save and Name File
file_nm = "Mem_Val.xlsx"

xlWb2.SaveAs(os.path.join(drop_zone, file_nm))
xlWb2.Close()
xlWb1.Close(False)

excel.Application.Quit()