
#  Created a script that could merge all PDFs within each subfolder (Loops through each subfolder from the specified Root Directory)



import os                                         ## Module to control Operating System (OS)
import glob                                       ## Module to reference file paths
import PyPDF2
from PyPDF2 import PdfFileMerger                  ## PDF Merger module
from PyPDF2 import PdfFileReader                  ## PDF Reader module 
import shutil                                     ## Module to control Folder Directories


rootdir = 'C:\Brian\Charts'        ## Set Root directory of folders




for dirName, subDirList, fileList in os.walk(rootdir, topdown=False):
    for folder in subDirList:
        os.chdir(os.path.join(dirName, folder))
        pdf_files = glob.glob('*.pdf')
        merger = PdfFileMerger()          ## PDF Merger module 
        for pdf in pdf_files:
            with open(pdf, 'rb') as f:
                pdfReader = PyPDF2.PdfFileReader(f)
                merger.append(pdfReader, import_bookmarks=False)
        merger.write(os.path.join(rootdir, str(folder)+'_Merged'+'.pdf'))
        merger.close() 



## Remove junk file
os.remove(os.path.join(rootdir, 'xml_Merged'+'.pdf'))

'''
## Remove folders 
for dirName, subDirList, fileList in os.walk(rootdir, topdown=False):
    for folder in subDirList:
        os.chdir(dirName)
        shutil.rmtree(folder)
'''          
